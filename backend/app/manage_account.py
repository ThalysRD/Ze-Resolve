"""Suspensão operacional privada; não cria uma rota administrativa pública."""

import argparse

from sqlalchemy import select

from .account_access import revoke_sessions
from .data_protection import email_lookup
from .database import database_url, make_database, validate_schema
from .models import AccountAction, Professional, User


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=("suspend", "resume"))
    parser.add_argument("--actor", required=True)
    args = parser.parse_args()
    email = input("Email da conta: ").strip()
    reason = input("Motivo registrado na auditoria: ").strip()
    if len(reason) < 10 or len(args.actor) > 100:
        parser.error("Informe motivo com pelo menos 10 caracteres e operador válido.")
    engine, sessions = make_database(database_url())
    validate_schema(engine)
    with sessions.begin() as db:
        user = db.scalar(
            select(User)
            .where(User.email_lookup == email_lookup(email))
            .with_for_update()
        )
        if not user or user.closed_at:
            raise SystemExit("Conta indisponível para esta operação.")
        user.is_active = args.action == "resume"
        revoke_sessions(db, user.id)
        pro = db.get(Professional, user.id)
        if pro:
            pro.is_available = False
        db.add(
            AccountAction(
                user_id=user.id, actor=args.actor, action=args.action, reason=reason
            )
        )
    engine.dispose()
    print("Ação registrada; sessões revogadas. Nenhum histórico foi apagado.")


if __name__ == "__main__":
    main()
