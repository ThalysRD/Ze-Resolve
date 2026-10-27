"""Persistent authentication throttles, with private identifiers and atomic increments."""

from datetime import datetime, timedelta, timezone

from fastapi import HTTPException
from sqlalchemy import case
from sqlalchemy.dialects.sqlite import insert

from .data_protection import private_digest
from .models import SecurityAttempt


def authentication_limit(engine, request, operation, account=None):
    address = request.client.host if request.client else "unknown"
    rules = [
        (
            f"{operation}:ip",
            address,
            20 if operation == "register" else 60,
            3600 if operation == "register" else 900,
        )
    ]
    if account is not None:
        rules.append((f"{operation}:account", str(account).strip().lower(), 10, 900))
    enforce_limits(engine, rules)


def resource_limit(engine, operation, identifier, limit=30, seconds=60):
    enforce_limits(engine, [(operation, str(identifier), limit, seconds)])


def enforce_limits(engine, rules):
    now = datetime.now(timezone.utc)
    blocked = False
    retry = 0
    table = SecurityAttempt.__table__
    with engine.begin() as connection:
        for purpose, identifier, limit, seconds in rules:
            key = private_digest(identifier, purpose)
            cutoff = now - timedelta(seconds=seconds)
            statement = insert(table).values(key=key, window_started_at=now, count=1)
            statement = statement.on_conflict_do_update(
                index_elements=[table.c.key],
                set_={
                    "window_started_at": case(
                        (table.c.window_started_at <= cutoff, now),
                        else_=table.c.window_started_at,
                    ),
                    "count": case(
                        (table.c.window_started_at <= cutoff, 1),
                        else_=table.c.count + 1,
                    ),
                },
            ).returning(table.c.count)
            count = connection.execute(statement).scalar_one()
            if count > limit:
                blocked, retry = True, max(retry, seconds)
    if blocked:
        raise HTTPException(
            429,
            "Muitas tentativas. Aguarde antes de tentar novamente.",
            headers={"Retry-After": str(retry)},
        )
