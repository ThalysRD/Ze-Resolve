"""Eventos de agendamento persistidos na mesma transação da alteração."""

import asyncio
import logging
from datetime import datetime, timedelta, timezone

from sqlalchemy import or_, select, update

from .models import AuthToken, EventDelivery, PushDevice, RequestEvent, User


def aware(value):
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value


def record_event(db, request, recipient, kind, body):
    event = RequestEvent(request_id=request.id, user_id=recipient, kind=kind, body=body)
    db.add(event)
    db.flush()
    for device in db.scalars(
        select(PushDevice)
        .join(AuthToken, AuthToken.digest == PushDevice.session_digest)
        .where(
            PushDevice.user_id == recipient,
            PushDevice.is_active.is_(True),
            AuthToken.revoked_at.is_(None),
            AuthToken.expires_at > datetime.now(timezone.utc),
        )
    ):
        db.add(
            EventDelivery(
                event_id=event.id,
                device_digest=device.digest,
                session_digest=device.session_digest,
            )
        )
    return event


def event_out(event):
    return {
        "id": event.id,
        "request_id": event.request_id,
        "kind": event.kind,
        "body": event.body,
        "created_at": aware(event.created_at).isoformat(),
        "is_read": event.read_at is not None,
    }


def deliver_events(sessions, sender):
    now = datetime.now(timezone.utc)
    with sessions() as db:
        keys = db.execute(
            select(EventDelivery.event_id, EventDelivery.device_digest)
            .where(
                EventDelivery.completed_at.is_(None),
                EventDelivery.retry_at <= now,
                or_(
                    EventDelivery.leased_until.is_(None),
                    EventDelivery.leased_until <= now,
                ),
            )
            .order_by(EventDelivery.event_id)
            .limit(20)
        ).all()
    for event_id, device_digest in keys:
        with sessions.begin() as db:
            claimed = db.execute(
                update(EventDelivery)
                .where(
                    EventDelivery.event_id == event_id,
                    EventDelivery.device_digest == device_digest,
                    EventDelivery.completed_at.is_(None),
                    EventDelivery.retry_at <= now,
                    or_(
                        EventDelivery.leased_until.is_(None),
                        EventDelivery.leased_until <= now,
                    ),
                )
                .values(
                    leased_until=now + timedelta(minutes=2),
                    attempts=EventDelivery.attempts + 1,
                )
            )
            if claimed.rowcount != 1:
                continue
            event = db.get(RequestEvent, event_id)
            device = db.get(PushDevice, device_digest)
            delivery = db.get(
                EventDelivery, (event_id, device_digest), populate_existing=True
            )
            token = db.get(AuthToken, delivery.session_digest)
            user = db.get(User, event.user_id)
            valid = (
                user.is_active
                and device
                and device.is_active
                and device.user_id == event.user_id
                and device.session_digest == delivery.session_digest
                and token
                and token.revoked_at is None
                and aware(token.expires_at) > now
            )
            if (
                not valid
                or event.read_at
                or aware(event.created_at) + timedelta(days=1) <= now
            ):
                delivery.completed_at = now
                continue
            payload = (device.token, -event.id, event.request_id, event.user_id)
        try:
            outcome = sender(*payload)
        except Exception:
            outcome = "retry"
        with sessions.begin() as db:
            delivery = db.get(EventDelivery, (event_id, device_digest))
            if outcome in {"sent", "invalid_device"} or delivery.attempts >= 8:
                delivery.completed_at = datetime.now(timezone.utc)
            else:
                delivery.retry_at = datetime.now(timezone.utc) + timedelta(
                    seconds=min(900, 2**delivery.attempts * 5)
                )
            delivery.leased_until = None
            if outcome == "invalid_device":
                device = db.get(PushDevice, device_digest)
                if device.session_digest == delivery.session_digest:
                    device.is_active = False


async def event_worker(sessions, sender, stopped):
    while not stopped.is_set():
        try:
            await asyncio.to_thread(deliver_events, sessions, sender)
        except Exception:
            logging.getLogger(__name__).warning(
                "Falha ao processar avisos de agendamento."
            )
        try:
            await asyncio.wait_for(stopped.wait(), timeout=2)
        except asyncio.TimeoutError:
            pass
