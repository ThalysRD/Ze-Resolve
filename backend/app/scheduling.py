"""Agenda publicada e reservas serializadas por prestador, sem exclusões."""

from datetime import datetime, timedelta, timezone
import asyncio
import os

from fastapi import HTTPException
from sqlalchemy import exists, func, select, update

from . import models as m

OCCUPIED_STATUSES = ("pendente", "aceita", "em_andamento", "concluida")


def occupied_request_condition():
    return m.ServiceRequest.status.in_(("aceita", "em_andamento", "concluida")) | (
        (m.ServiceRequest.status == "pendente")
        & m.ServiceRequest.slot_id.is_not(None)
        & (
            (m.ServiceRequest.hold_expires_at.is_(None))
            | (m.ServiceRequest.hold_expires_at > datetime.now(timezone.utc))
        )
    )


def aware(value):
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value


def lock_professional(db, professional_id):
    """Use o mesmo bloqueio em todas as escritas da agenda e perfil."""
    db.execute(
        update(m.Professional)
        .where(m.Professional.id == professional_id)
        .values(is_available=m.Professional.is_available)
    )
    return db.get(m.Professional, professional_id, populate_existing=True)


def conflicting_request(db, professional_id, start, end, *, excluding=None):
    ends_after = func.julianday(
        m.ServiceRequest.scheduled_at
    ) + m.ServiceRequest.duration_minutes / 1440.0 > func.julianday(start)
    statement = select(m.ServiceRequest.id).where(
        m.ServiceRequest.professional_id == professional_id,
        occupied_request_condition(),
        m.ServiceRequest.scheduled_at < end,
        ends_after,
    )
    if excluding is not None:
        statement = statement.where(m.ServiceRequest.id != excluding)
    return db.scalar(statement.limit(1))


def expire_professional_holds(db, professional_id):
    """O chamador já detém o bloqueio do profissional; preserve todo o histórico."""
    expired = db.scalars(
        select(m.ServiceRequest).where(
            m.ServiceRequest.professional_id == professional_id,
            m.ServiceRequest.status == "pendente",
            m.ServiceRequest.hold_expires_at <= datetime.now(timezone.utc),
        )
    ).all()
    from .request_events import record_event

    for request in expired:
        request.status = "cancelada"
        request.cancellation_reason = "Prazo de resposta encerrado."
        for recipient in (request.client_id, request.professional_id):
            record_event(
                db,
                request,
                recipient,
                "expired",
                "O prazo de resposta terminou. Consulte a agenda para escolher outro horário.",
            )
    db.flush()
    return len(expired)


def expire_holds(sessions):
    with sessions() as db:
        ids = db.scalars(
            select(m.ServiceRequest.professional_id)
            .where(
                m.ServiceRequest.status == "pendente",
                m.ServiceRequest.hold_expires_at <= datetime.now(timezone.utc),
            )
            .distinct()
            .limit(100)
        ).all()
    for professional_id in ids:
        with sessions.begin() as db:
            lock_professional(db, professional_id)
            expire_professional_holds(db, professional_id)


async def hold_worker(sessions, stopped):
    while not stopped.is_set():
        try:
            await asyncio.to_thread(expire_holds, sessions)
        except Exception:
            import logging

            logging.getLogger(__name__).warning(
                "Falha ao processar vencimentos da agenda."
            )
        try:
            await asyncio.wait_for(stopped.wait(), timeout=15)
        except asyncio.TimeoutError:
            pass


def hold_deadline(starts_at):
    minutes = int(os.getenv("BOOKING_HOLD_MINUTES", "30"))
    if not 5 <= minutes <= 1440:
        raise RuntimeError("BOOKING_HOLD_MINUTES deve estar entre 5 e 1440.")
    return min(
        aware(starts_at), datetime.now(timezone.utc) + timedelta(minutes=minutes)
    )


def slot_occupied_condition(db):
    """Inclua também solicitações antigas que ainda não possuem slot_id."""
    if db.bind.dialect.name == "sqlite":
        ends_after_start = func.julianday(
            m.ServiceRequest.scheduled_at
        ) + m.ServiceRequest.duration_minutes / 1440.0 > func.julianday(
            m.AvailabilitySlot.starts_at
        )
    else:
        ends_after_start = (
            m.ServiceRequest.scheduled_at
            + m.ServiceRequest.duration_minutes * text("INTERVAL '1 minute'")
            > m.AvailabilitySlot.starts_at
        )
    return exists(
        select(m.ServiceRequest.id)
        .where(
            m.ServiceRequest.professional_id == m.AvailabilitySlot.professional_id,
            occupied_request_condition(),
            m.ServiceRequest.scheduled_at < m.AvailabilitySlot.ends_at,
            ends_after_start,
        )
        .correlate(m.AvailabilitySlot)
    )


def free_slots_query(db, *, now=None):
    return select(m.AvailabilitySlot).where(
        m.AvailabilitySlot.is_active.is_(True),
        m.AvailabilitySlot.starts_at > (now or datetime.now(timezone.utc)),
        ~slot_occupied_condition(db),
    )


def next_available_by_professional(db):
    if not hasattr(db, "professional_next_available"):
        db.professional_next_available = dict(
            db.execute(
                select(
                    m.AvailabilitySlot.professional_id,
                    func.min(m.AvailabilitySlot.starts_at),
                )
                .join(m.Professional)
                .where(
                    m.AvailabilitySlot.is_active.is_(True),
                    m.AvailabilitySlot.starts_at > datetime.now(timezone.utc),
                    m.Professional.is_available.is_(True),
                    m.Professional.visit_fee_cents.is_not(None),
                    ~slot_occupied_condition(db),
                )
                .group_by(m.AvailabilitySlot.professional_id)
            ).all()
        )
    return db.professional_next_available


def availability_window(from_at, to_at):
    for value in (from_at, to_at):
        if value is not None and value.tzinfo is None:
            raise HTTPException(422, "Informe datas com fuso horário.")
    now = datetime.now(timezone.utc)
    start = max(now, from_at.astimezone(timezone.utc)) if from_at else now
    end = to_at.astimezone(timezone.utc) if to_at else now + timedelta(days=180)
    if end <= start:
        raise HTTPException(422, "O fim da consulta deve ser posterior ao início.")
    return start, end
