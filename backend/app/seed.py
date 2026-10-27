"""Dados fictícios explícitos e idempotentes: python -m app.seed."""

from datetime import datetime, timedelta, timezone

from sqlalchemy import select

from .data_protection import email_lookup
from .database import database_url, initialize_schema, make_database
from .models import (
    AvailabilitySlot,
    Category,
    Message,
    Professional,
    Review,
    ServiceRequest,
    User,
)
from .scheduling import conflicting_request, free_slots_query, lock_professional
from .security import passwords
from .configuration import production
from .reference_data import populate_categories


def seed(url=None):
    if production():
        raise RuntimeError("Dados de demonstração não podem ser criados em produção.")
    engine, sessions = make_database(url or database_url())
    initialize_schema(engine)
    with sessions.begin() as db:
        populate_categories(db)
        users = []
        for name, email, role in [
            ("Maria Souza", "cliente@example.com", "cliente"),
            ("João Silva", "profissional@example.com", "profissional"),
            ("Marcos Lima", "encanador@example.com", "profissional"),
        ]:
            user = db.scalar(
                select(User).where(User.email_lookup == email_lookup(email))
            )
            if not user:
                user = User(
                    name=name,
                    email=email,
                    phone="84999990000",
                    role=role,
                    password_hash=passwords.hash("Demo12345!"),
                )
                db.add(user)
                db.flush()
            users.append(user)
        for user, category, price in [
            (users[1], "Eletricista", 8000),
            (users[2], "Encanador", 7500),
        ]:
            if not db.get(Professional, user.id):
                cat = db.scalar(select(Category).where(Category.name == category))
                db.add(
                    Professional(
                        id=user.id,
                        category_id=cat.id,
                        city="Natal, RN",
                        hourly_rate_cents=price,
                        visit_fee_cents=price,
                        latitude=-5.7945 if category == "Eletricista" else -5.8100,
                        longitude=-35.2110,
                        bio=f"Serviços de {category.lower()} e pequenos reparos.",
                    )
                )
        db.flush()
        if not db.scalar(
            select(ServiceRequest).where(ServiceRequest.client_id == users[0].id)
        ):
            for status, title in [
                ("pendente", "Instalação de tomadas"),
                ("concluida", "Reparo de iluminação"),
            ]:
                request = ServiceRequest(
                    client_id=users[0].id,
                    professional_id=users[1].id,
                    title=title,
                    description="Instalar e revisar pontos elétricos da sala.",
                    address="Rua das Flores, 123 — Natal, RN",
                    status=status,
                    scheduled_at=datetime.now(timezone.utc)
                    + timedelta(days=2 if status == "pendente" else -2),
                )
                pro = db.get(Professional, users[1].id)
                if status == "pendente" and pro.visit_fee_cents is not None:
                    slot = AvailabilitySlot(
                        professional_id=pro.id,
                        starts_at=request.scheduled_at,
                        ends_at=request.scheduled_at + timedelta(hours=1),
                    )
                    db.add(slot)
                    db.flush()
                    request.slot_id = slot.id
                    request.visit_fee_cents = pro.visit_fee_cents
                db.add(request)
                db.flush()
                db.add(
                    Message(
                        request_id=request.id,
                        sender_id=users[0].id,
                        body="Olá! Podemos confirmar os detalhes?",
                    )
                )
                if status == "concluida":
                    db.add(
                        Review(
                            request_id=request.id,
                            rating=5,
                            comment="Pontual e caprichoso!",
                        )
                    )
        db.flush()
        for user in users[1:]:
            pro = lock_professional(db, user.id)
            if pro.visit_fee_cents is None:
                continue
            now = datetime.now(timezone.utc)
            for urgent in (True, False):
                boundary = now + timedelta(hours=24)
                existing = free_slots_query(db, now=now).where(
                    AvailabilitySlot.professional_id == user.id
                )
                existing = existing.where(
                    AvailabilitySlot.starts_at <= boundary
                    if urgent
                    else AvailabilitySlot.starts_at > boundary
                )
                if db.scalar(existing.limit(1)):
                    continue
                start = (
                    now + (timedelta(hours=3) if urgent else timedelta(days=3))
                ).replace(second=0, microsecond=0)
                end = start + timedelta(hours=1)
                occupied = db.scalar(
                    select(AvailabilitySlot.id)
                    .where(
                        AvailabilitySlot.professional_id == user.id,
                        AvailabilitySlot.is_active.is_(True),
                        AvailabilitySlot.starts_at < end,
                        AvailabilitySlot.ends_at > start,
                    )
                    .limit(1)
                )
                if not occupied and not conflicting_request(db, user.id, start, end):
                    db.add(
                        AvailabilitySlot(
                            professional_id=user.id, starts_at=start, ends_at=end
                        )
                    )
                    db.flush()
    engine.dispose()


if __name__ == "__main__":
    seed()
    print("Dados fictícios criados. Senha das três contas: Demo12345!")
