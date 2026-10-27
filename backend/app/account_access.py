"""Recuperação, confirmação de contato e encerramento sem apagar registros."""

from datetime import datetime, timedelta, timezone
import secrets
from typing import Annotated

from fastapi import HTTPException, Request, Response
from pydantic import EmailStr, Field, StringConstraints, field_validator
from sqlalchemy import select, update

from . import models as m
from .data_protection import email_lookup, private_digest
from .mail import configured
from .schemas import Input, Register, SessionOut, OperationAccepted
from .security import passwords
from .security_controls import authentication_limit
from .scheduling import lock_professional
from .request_events import record_event
from fastapi.responses import HTMLResponse
from urllib.parse import parse_qs

DUMMY_PASSWORD_HASH = passwords.hash(secrets.token_urlsafe(32))


class Contact(Input):
    email: EmailStr


class CodeInput(Contact):
    code: str = Field(pattern=r"^\d{8}$")


class ResetInput(CodeInput):
    new_password: Annotated[str, StringConstraints(strip_whitespace=False)] = Field(
        min_length=8, max_length=72
    )

    @field_validator("new_password")
    @classmethod
    def password_limit(cls, value):
        return Register.bcrypt_limit(value)


class PasswordConfirm(Input):
    password: Annotated[str, StringConstraints(strip_whitespace=False)] = Field(
        min_length=1, max_length=72
    )


def issue_code(db, user, purpose):
    if not configured():
        raise HTTPException(
            503, "A recuperação por email está temporariamente indisponível."
        )
    now = datetime.now(timezone.utc)
    db.execute(
        update(m.AccountChallenge)
        .where(
            m.AccountChallenge.user_id == user.id,
            m.AccountChallenge.purpose == purpose,
            m.AccountChallenge.consumed_at.is_(None),
        )
        .values(consumed_at=now)
    )
    code = f"{secrets.randbelow(100_000_000):08d}"
    digest = private_digest(f"{user.id}:{code}", purpose)
    while db.get(m.AccountChallenge, digest):
        code = f"{secrets.randbelow(100_000_000):08d}"
        digest = private_digest(f"{user.id}:{code}", purpose)
    db.add(
        m.AccountChallenge(
            digest=digest,
            user_id=user.id,
            purpose=purpose,
            expires_at=now + timedelta(minutes=15),
        )
    )
    action = "redefinir sua senha" if purpose == "reset" else "confirmar seu email"
    db.add(
        m.MailDelivery(
            user_id=user.id,
            recipient=user.email,
            subject="Zé Resolve — código de acesso",
            body=f"Use o código {code} para {action} no aplicativo Zé Resolve.\nEle vence em 15 minutos e só pode ser usado uma vez.\nSe não foi você, ignore este email.",
        )
    )


def redeem(db, body, purpose):
    user = db.scalar(
        select(m.User).where(m.User.email_lookup == email_lookup(body.email))
    )
    if not user or not user.is_active:
        raise HTTPException(400, "Código inválido ou expirado.")
    db.execute(update(m.User).where(m.User.id == user.id).values(phone=m.User.phone))
    digest = private_digest(f"{user.id}:{body.code}", purpose)
    result = db.execute(
        update(m.AccountChallenge)
        .where(
            m.AccountChallenge.digest == digest,
            m.AccountChallenge.user_id == user.id,
            m.AccountChallenge.purpose == purpose,
            m.AccountChallenge.consumed_at.is_(None),
            m.AccountChallenge.expires_at > datetime.now(timezone.utc),
        )
        .values(consumed_at=datetime.now(timezone.utc))
    )
    if result.rowcount != 1:
        raise HTTPException(400, "Código inválido ou expirado.")
    return user


def revoke_sessions(db, user_id):
    now = datetime.now(timezone.utc)
    db.execute(
        update(m.AuthToken)
        .where(m.AuthToken.user_id == user_id, m.AuthToken.revoked_at.is_(None))
        .values(revoked_at=now, expires_at=now - timedelta(seconds=1))
    )
    db.execute(
        update(m.PushDevice)
        .where(m.PushDevice.user_id == user_id)
        .values(is_active=False)
    )


def close_account(db, user):
    """Encerramento confirmado pelo titular; pseudonimize campos sem excluir linhas."""
    db.execute(update(m.User).where(m.User.id == user.id).values(phone=m.User.phone))
    active = (m.ServiceRequest.client_id == user.id) | (
        m.ServiceRequest.professional_id == user.id
    )
    if db.scalar(
        select(m.ServiceRequest.id)
        .where(active, m.ServiceRequest.status == "em_andamento")
        .limit(1)
    ):
        raise HTTPException(
            409, "Conclua o atendimento em andamento antes de encerrar a conta."
        )
    pending = db.scalars(
        select(m.ServiceRequest)
        .where(active, m.ServiceRequest.status.in_(("pendente", "aceita")))
        .order_by(m.ServiceRequest.professional_id, m.ServiceRequest.id)
    ).all()
    for request in pending:
        lock_professional(db, request.professional_id)
        db.refresh(request)
        if request.status == "em_andamento":
            raise HTTPException(
                409, "Conclua o atendimento em andamento antes de encerrar a conta."
            )
        if request.status not in {"pendente", "aceita"}:
            continue
        request.status, request.cancelled_by = "cancelada", user.id
        request.cancellation_reason = "Conta encerrada pelo participante."
        recipient = (
            request.professional_id
            if user.id == request.client_id
            else request.client_id
        )
        record_event(
            db,
            request,
            recipient,
            "cancelada",
            "O agendamento foi cancelado por encerramento da conta de um participante.",
        )
    now = datetime.now(timezone.utc)
    db.add(
        m.AccountAction(
            user_id=user.id,
            actor="account-owner",
            action="close",
            reason="Encerramento confirmado pelo titular com a senha atual.",
        )
    )
    revoke_sessions(db, user.id)
    user.is_active, user.closed_at = False, now
    user.name, user.phone = "Conta encerrada", ""
    user.email = f"closed-{secrets.token_hex(16)}@example.com"
    user.email_lookup = secrets.token_hex(32)
    user.password_hash = passwords.hash(secrets.token_urlsafe(48))
    user.email_verified_at = None
    pro = db.get(m.Professional, user.id)
    if pro:
        lock_professional(db, pro.id)
        pro.is_available, pro.public_name, pro.bio, pro.city = (
            False,
            "Conta encerrada",
            "",
            "",
        )
        pro.latitude = pro.longitude = pro.latitude_private = pro.longitude_private = (
            None
        )
        db.execute(
            update(m.AvailabilitySlot)
            .where(m.AvailabilitySlot.professional_id == user.id)
            .values(is_active=False)
        )
    db.execute(
        update(m.Address)
        .where(m.Address.user_id == user.id)
        .values(
            is_active=False,
            is_default=False,
            label="Endereço removido",
            postal_code="00000000",
            street="Removido",
            number="",
            complement="",
            neighborhood="",
            city="",
            state="",
        )
    )
    db.execute(
        update(m.ServiceRequest)
        .where(m.ServiceRequest.client_id == user.id)
        .values(
            title="Solicitação de conta encerrada",
            description="Dados pessoais removidos pelo titular.",
            address="Endereço removido.",
        )
    )
    db.execute(
        update(m.Message)
        .where(m.Message.sender_id == user.id)
        .values(body="Mensagem de conta encerrada.")
    )
    authored = select(m.ServiceRequest.id).where(m.ServiceRequest.client_id == user.id)
    db.execute(
        update(m.Review)
        .where(m.Review.request_id.in_(authored))
        .values(comment="Avaliação de conta encerrada.")
    )
    db.execute(
        update(m.PushDevice)
        .where(m.PushDevice.user_id == user.id)
        .values(is_active=False, token="Conta encerrada")
    )
    db.execute(
        update(m.AccountChallenge)
        .where(m.AccountChallenge.user_id == user.id)
        .values(consumed_at=now)
    )
    db.execute(
        update(m.MailDelivery)
        .where(m.MailDelivery.user_id == user.id)
        .values(
            body="Conta encerrada", recipient="closed@example.com", completed_at=now
        )
    )
    db.flush()


def register_account_access(app, engine, sessions, UserDependency, DBDependency):
    @app.post(
        "/auth/password/reset-request",
        tags=["Autenticação"],
        status_code=202,
        response_model=OperationAccepted,
        summary="Solicitar código de recuperação",
        description="Resposta genérica; código de uso único enviado por email, válido por 15 minutos. Limites por IP/conta. Nenhum código é devolvido pela API.",
    )
    def reset_request(body: Contact, request: Request):
        authentication_limit(engine, request, "reset-request", body.email)
        if not configured():
            raise HTTPException(
                503, "A recuperação por email está temporariamente indisponível."
            )
        with sessions.begin() as db:
            user = db.scalar(
                select(m.User).where(m.User.email_lookup == email_lookup(body.email))
            )
            if user and user.is_active:
                db.execute(
                    update(m.User)
                    .where(m.User.id == user.id)
                    .values(phone=m.User.phone)
                )
                issue_code(db, user, "reset")
        return {
            "message": "Se a conta estiver disponível, você receberá um código por email."
        }

    @app.post(
        "/auth/password/reset",
        tags=["Autenticação"],
        status_code=204,
        summary="Redefinir senha com código de uso único",
    )
    def reset_password(body: ResetInput, request: Request):
        authentication_limit(engine, request, "reset", body.email)
        with sessions.begin() as db:
            user = redeem(db, body, "reset")
            user.password_hash = passwords.hash(body.new_password)
            revoke_sessions(db, user.id)
        return Response(status_code=204)

    @app.post(
        "/auth/email/verification-request",
        tags=["Autenticação"],
        status_code=202,
        response_model=OperationAccepted,
        summary="Solicitar confirmação de email",
    )
    def verification_request(body: Contact, request: Request):
        authentication_limit(engine, request, "verify-request", body.email)
        if not configured():
            raise HTTPException(
                503, "A confirmação por email está temporariamente indisponível."
            )
        with sessions.begin() as db:
            user = db.scalar(
                select(m.User).where(m.User.email_lookup == email_lookup(body.email))
            )
            if user and user.is_active and not user.email_verified_at:
                db.execute(
                    update(m.User)
                    .where(m.User.id == user.id)
                    .values(phone=m.User.phone)
                )
                issue_code(db, user, "verify")
        return {
            "message": "Se a conta precisar de confirmação, você receberá um código por email."
        }

    @app.post(
        "/auth/email/verify",
        tags=["Autenticação"],
        status_code=204,
        summary="Confirmar email com código de uso único",
    )
    def verify_email(body: CodeInput, request: Request):
        authentication_limit(engine, request, "verify", body.email)
        with sessions.begin() as db:
            user = redeem(db, body, "verify")
            user.email_verified_at = datetime.now(timezone.utc)
        return Response(status_code=204)

    @app.get(
        "/users/me/sessions",
        response_model=list[SessionOut],
        tags=["Conta"],
        summary="Consultar minhas sessões sem expor tokens",
    )
    def sessions_list(user: UserDependency, db: DBDependency):
        rows = db.scalars(
            select(m.AuthToken)
            .where(m.AuthToken.user_id == user.id)
            .order_by(m.AuthToken.issued_at.desc())
            .limit(100)
        )
        return [
            {
                "issued_at": token.issued_at,
                "expires_at": token.expires_at,
                "revoked": token.revoked_at is not None,
            }
            for token in rows
        ]

    @app.post(
        "/users/me/sessions/revoke-all",
        tags=["Conta"],
        status_code=204,
        summary="Encerrar todas as minhas sessões",
    )
    def revoke_all(body: PasswordConfirm, user: UserDependency, db: DBDependency):
        if not passwords.verify(body.password, user.password_hash):
            raise HTTPException(403, "Senha atual inválida.")
        revoke_sessions(db, user.id)
        db.commit()
        return Response(status_code=204)

    @app.post(
        "/users/me/closure",
        tags=["Conta"],
        status_code=204,
        summary="Encerrar minha conta e remover dados pessoais dos campos próprios",
        description="Exige senha atual. Revoga sessões, pausa o perfil, cancela reservas e pseudonimiza campos próprios sem excluir linhas. Atendimento em andamento impede encerramento. Dados de terceiros e backups são tratados pelo canal de atendimento e política de retenção.",
    )
    def closure(
        body: PasswordConfirm, user: UserDependency, db: DBDependency, request: Request
    ):
        authentication_limit(engine, request, "closure", user.id)
        if not passwords.verify(body.password, user.password_hash):
            raise HTTPException(403, "Senha atual inválida.")
        close_account(db, user)
        db.commit()
        return Response(status_code=204)

    @app.get("/account/closure", response_class=HTMLResponse, include_in_schema=False)
    def closure_page():
        return HTMLResponse(
            """<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Encerrar conta — Zé Resolve</title><main style="max-width:40rem;margin:2rem auto;padding:1rem;font:1rem/1.6 sans-serif"><h1>Encerrar minha conta</h1><p>As sessões serão revogadas, o perfil desativado e os dados pessoais dos campos próprios removidos. O histórico operacional conserva identificadores, datas, valores e estados. Reservas serão canceladas; conclua atendimentos em andamento antes de continuar. Esta ação não pode ser desfeita.</p><p>Consulte a <a href="/legal/privacy">Política de Privacidade</a> para dados de terceiros, backups e contato.</p><form method="post"><p><label>Email <input type="email" name="email" required maxlength="254" autocomplete="username"></label></p><p><label>Senha atual <input type="password" name="password" required maxlength="72" autocomplete="current-password"></label></p><p><label><input type="checkbox" name="confirmed" value="yes" required>Compreendo e quero encerrar a conta.</label></p><button type="submit">Encerrar conta definitivamente</button></form></main></html>"""
        )

    @app.post("/account/closure", response_class=HTMLResponse, include_in_schema=False)
    async def web_closure(request: Request):
        origin = request.headers.get("origin")
        expected_origin = f"{request.url.scheme}://{request.url.netloc}"
        if origin and origin != expected_origin:
            raise HTTPException(403, "Origem não permitida.")
        data = await request.body()
        if len(data) > 4096:
            raise HTTPException(413, "Formulário muito grande.")
        fields = parse_qs(data.decode("utf-8", errors="replace"))
        body = {key: values[-1] for key, values in fields.items()}
        if body.get("confirmed") != "yes":
            raise HTTPException(422, "Confirme o encerramento.")
        import asyncio

        def perform():
            authentication_limit(engine, request, "closure", body.get("email", ""))
            with sessions.begin() as db:
                user = db.scalar(
                    select(m.User).where(
                        m.User.email_lookup == email_lookup(body.get("email", ""))
                    )
                )
                password = body.get("password", "")
                if not 1 <= len(password.encode("utf-8")) <= 72:
                    raise HTTPException(403, "Email ou senha inválidos.")
                valid = passwords.verify(
                    password, user.password_hash if user else DUMMY_PASSWORD_HASH
                )
                if not user or not user.is_active or not valid:
                    raise HTTPException(403, "Email ou senha inválidos.")
                close_account(db, user)

        await asyncio.to_thread(perform)
        return HTMLResponse(
            "<!doctype html><html lang='pt-BR'><meta charset='utf-8'><title>Conta encerrada</title><h1>Conta encerrada</h1><p>As sessões foram revogadas e os campos pessoais próprios foram removidos.</p></html>"
        )
