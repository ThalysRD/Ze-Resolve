"""Outbox persistente: mensagens são confirmadas sem depender da entrega do push."""

import asyncio
import logging
import os
from datetime import datetime, timedelta, timezone
from pathlib import Path

from sqlalchemy import or_, select, update

from .models import (
    AuthToken,
    Message,
    MessageReceipt,
    PushDelivery,
    PushDevice,
    ServiceRequest,
)

logger = logging.getLogger(__name__)


def aware(value):
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value


def enqueue_push(db, message):
    """Invocada na mesma transação da mensagem; rollback não deixa envio pendente."""
    request = db.get(ServiceRequest, message.request_id)
    recipient = (
        request.professional_id
        if message.sender_id == request.client_id
        else request.client_id
    )
    devices = db.scalars(
        select(PushDevice)
        .join(AuthToken, AuthToken.digest == PushDevice.session_digest)
        .where(
            PushDevice.user_id == recipient,
            PushDevice.is_active.is_(True),
            AuthToken.revoked_at.is_(None),
            AuthToken.expires_at > datetime.now(timezone.utc),
        )
    ).all()
    for device in devices:
        db.add(
            PushDelivery(
                message_id=message.id,
                device_digest=device.digest,
                session_digest=device.session_digest,
            )
        )


def firebase_sender():
    path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
    local = Path(__file__).resolve().parents[1] / "data" / "firebase-admin.json"
    if not path and local.is_file():
        path = str(local)
    if not path and os.getenv("FCM_USE_ADC") != "true":
        logger.info("Push desabilitado: configure a credencial Firebase do servidor.")
        return None
    try:
        import firebase_admin
        from firebase_admin import credentials, messaging

        credential = (
            credentials.Certificate(path) if path else credentials.ApplicationDefault()
        )
        try:
            firebase = firebase_admin.get_app("ze-resolve-push")
        except ValueError:
            firebase = firebase_admin.initialize_app(
                credential, {"httpTimeout": 15}, name="ze-resolve-push"
            )
    except Exception:
        logger.error(
            "Push indisponível: verifique a instalação do Firebase Admin e a credencial."
        )
        return None

    def send(token, message_id, request_id, recipient_id):
        try:
            messaging.send(
                messaging.Message(
                    token=token,
                    notification=messaging.Notification(
                        title="Zé Resolve",
                        body=(
                            "Seu agendamento teve uma atualização."
                            if message_id < 0
                            else "Você recebeu uma nova mensagem."
                        ),
                    ),
                    data={
                        "type": "request_event" if message_id < 0 else "chat",
                        "message_id": str(message_id),
                        "request_id": str(request_id),
                        "recipient_id": str(recipient_id),
                    },
                    android=messaging.AndroidConfig(
                        priority="high",
                        ttl=timedelta(minutes=15),
                        notification=messaging.AndroidNotification(
                            tag=f"message-{message_id}", sound="default"
                        ),
                    ),
                ),
                app=firebase,
            )
            return "sent"
        except messaging.UnregisteredError:
            return "invalid_device"

    return send


def drain_push(sessions, sender):
    now = datetime.now(timezone.utc)
    with sessions() as db:
        keys = db.execute(
            select(PushDelivery.message_id, PushDelivery.device_digest)
            .where(
                PushDelivery.completed_at.is_(None),
                PushDelivery.next_attempt_at <= now,
                or_(PushDelivery.lease_until.is_(None), PushDelivery.lease_until < now),
            )
            .order_by(PushDelivery.next_attempt_at)
            .limit(50)
        ).all()
    for message_id, digest in keys:
        now = datetime.now(timezone.utc)
        with sessions() as db:
            claimed = db.execute(
                update(PushDelivery)
                .where(
                    PushDelivery.message_id == message_id,
                    PushDelivery.device_digest == digest,
                    PushDelivery.completed_at.is_(None),
                    PushDelivery.next_attempt_at <= now,
                    or_(
                        PushDelivery.lease_until.is_(None),
                        PushDelivery.lease_until < now,
                    ),
                )
                .values(
                    lease_until=now + timedelta(minutes=2),
                    attempts=PushDelivery.attempts + 1,
                )
            )
            db.commit()
            if claimed.rowcount != 1:
                continue
            delivery = db.get(PushDelivery, (message_id, digest))
            device = db.get(PushDevice, digest)
            token = db.get(AuthToken, delivery.session_digest)
            message = db.get(Message, message_id)
            request = db.get(ServiceRequest, message.request_id)
            recipient = (
                request.professional_id
                if message.sender_id == request.client_id
                else request.client_id
            )
            valid = (
                device
                and device.is_active
                and device.session_digest == delivery.session_digest
                and device.user_id == recipient
                and token
                and token.user_id == recipient
                and token.revoked_at is None
                and aware(token.expires_at) > now
            )
            already_read = db.get(MessageReceipt, (recipient, message_id)) is not None
            if (
                not valid
                or already_read
                or aware(message.created_at) + timedelta(days=1) < now
            ):
                delivery.completed_at = now
                delivery.outcome = "cancelled"
                db.commit()
                continue
            fcm_token, request_id, session_digest, attempts = (
                device.token,
                message.request_id,
                delivery.session_digest,
                delivery.attempts,
            )
        try:
            outcome = sender(fcm_token, message_id, request_id, recipient)
        except Exception:
            outcome = "retry"
        with sessions() as db:
            delivery = db.get(PushDelivery, (message_id, digest))
            delivery.lease_until = None
            if outcome != "retry" or attempts >= 8:
                delivery.completed_at = datetime.now(timezone.utc)
                delivery.outcome = "failed" if outcome == "retry" else outcome
            else:
                delivery.next_attempt_at = datetime.now(timezone.utc) + timedelta(
                    seconds=min(300, 2**attempts * 5)
                )
            if outcome == "invalid_device":
                db.execute(
                    update(PushDevice)
                    .where(
                        PushDevice.digest == digest,
                        PushDevice.session_digest == session_digest,
                    )
                    .values(is_active=False)
                )
            db.commit()


async def push_worker(sessions, sender, stopped):
    while not stopped.is_set():
        try:
            await asyncio.to_thread(drain_push, sessions, sender)
        except Exception:
            logger.error(
                "Falha ao processar fila de notificações; nova tentativa automática."
            )
        try:
            await asyncio.wait_for(stopped.wait(), timeout=2)
        except asyncio.TimeoutError:
            pass
