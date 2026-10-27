"""Email transacional com fila cifrada, leases e repetição limitada."""

import asyncio
from datetime import datetime, timedelta, timezone
from email.message import EmailMessage
import logging
import os
import smtplib
import ssl

from sqlalchemy import or_, select, update

from .configuration import production
from .models import MailDelivery


def configured():
    return bool(os.getenv("SMTP_HOST") and os.getenv("SMTP_FROM"))


def smtp_send(recipient, subject, body):
    message = EmailMessage()
    message["From"] = os.environ["SMTP_FROM"]
    message["To"] = recipient
    message["Subject"] = subject
    message.set_content(body)
    port = int(os.getenv("SMTP_PORT", "587"))
    host = os.environ["SMTP_HOST"]
    local = not production() and host in {"localhost", "127.0.0.1"}
    transport = smtplib.SMTP_SSL if port == 465 else smtplib.SMTP
    options = {"context": ssl.create_default_context()} if port == 465 else {}
    with transport(host, port, timeout=15, **options) as connection:
        if port != 465 and not local:
            connection.starttls(context=ssl.create_default_context())
        if os.getenv("SMTP_USERNAME"):
            connection.login(os.environ["SMTP_USERNAME"], os.environ["SMTP_PASSWORD"])
        connection.send_message(message)


def drain_mail(sessions, sender=smtp_send):
    now = datetime.now(timezone.utc)
    with sessions() as db:
        ids = db.scalars(
            select(MailDelivery.id)
            .where(
                MailDelivery.completed_at.is_(None),
                MailDelivery.retry_at <= now,
                or_(
                    MailDelivery.leased_until.is_(None),
                    MailDelivery.leased_until <= now,
                ),
            )
            .order_by(MailDelivery.id)
            .limit(20)
        ).all()
    for delivery_id in ids:
        with sessions.begin() as db:
            claimed = db.execute(
                update(MailDelivery)
                .where(
                    MailDelivery.id == delivery_id,
                    MailDelivery.completed_at.is_(None),
                    MailDelivery.retry_at <= now,
                    or_(
                        MailDelivery.leased_until.is_(None),
                        MailDelivery.leased_until <= now,
                    ),
                )
                .values(
                    attempts=MailDelivery.attempts + 1,
                    leased_until=now + timedelta(minutes=2),
                )
            )
            if claimed.rowcount != 1:
                continue
            delivery = db.get(MailDelivery, delivery_id, populate_existing=True)
            created = (
                delivery.created_at.replace(tzinfo=timezone.utc)
                if delivery.created_at.tzinfo is None
                else delivery.created_at
            )
            if now - created >= timedelta(minutes=15):
                delivery.completed_at, delivery.body = now, "Código expirado."
                continue
            payload = delivery.recipient, delivery.subject, delivery.body
        sent = False
        try:
            sender(*payload)
            sent = True
        except Exception:
            logging.getLogger(__name__).warning(
                "Falha temporária na entrega de email transacional."
            )
        with sessions.begin() as db:
            delivery = db.get(MailDelivery, delivery_id)
            if sent or delivery.attempts >= 8:
                delivery.completed_at, delivery.body = (
                    datetime.now(timezone.utc),
                    "Entrega processada.",
                )
            else:
                delivery.retry_at = datetime.now(timezone.utc) + timedelta(
                    seconds=min(300, 5 * 2**delivery.attempts)
                )
            delivery.leased_until = None


async def mail_worker(sessions, stopped):
    while not stopped.is_set():
        try:
            await asyncio.to_thread(drain_mail, sessions)
        except Exception:
            logging.getLogger(__name__).warning(
                "Fila de email temporariamente indisponível."
            )
        try:
            await asyncio.wait_for(stopped.wait(), timeout=2)
        except asyncio.TimeoutError:
            pass
