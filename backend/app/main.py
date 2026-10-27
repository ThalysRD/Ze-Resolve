"""Contrato REST e regras de acesso. Execute: uvicorn app.main:app."""

import asyncio
import hashlib
import math
import os
import secrets
from copy import deepcopy
from contextlib import asynccontextmanager
from datetime import datetime, timedelta, timezone
from typing import Annotated

from fastapi import Depends, FastAPI, HTTPException, Query, Request, Response
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.trustedhost import TrustedHostMiddleware
from fastapi.responses import JSONResponse
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import func, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, joinedload

from . import models as m
from . import schemas as s
from .data_protection import email_lookup
from .database import database_url, initialize_schema, make_database, validate_schema
from .push import enqueue_push, firebase_sender, push_worker
from .security import passwords
from .security_controls import authentication_limit
from .scheduling import (
    OCCUPIED_STATUSES,
    availability_window,
    conflicting_request,
    free_slots_query,
    lock_professional,
    next_available_by_professional,
    slot_occupied_condition,
    expire_professional_holds,
    hold_deadline,
    hold_worker,
)
from .socket_service import register_chat
from .configuration import (
    production,
    secure_transport,
    trusted_hosts,
    validate_settings,
)
from .reference_data import populate_categories
from .request_events import record_event, event_out, event_worker
from .account_access import issue_code, register_account_access
from .mail import configured as mail_configured, mail_worker
from .policies import VERSION as TERMS_VERSION, register_policies
from .http_controls import HttpControls

dummy_hash = passwords.hash("dummy-password-for-timing")
bearer = HTTPBearer(
    auto_error=False,
    description="Cadastre-se e faça login. Cole o access_token obtido em POST /auth/login. Expira em 30 dias; logout revoga no servidor.",
)


def aware(value):
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value


def token_digest(token):
    return hashlib.sha256(token.encode()).hexdigest()


def haversine(lat1, lon1, lat2, lon2):
    a1, a2 = math.radians(lat1), math.radians(lat2)
    dlat, dlon = a2 - a1, math.radians(lon2 - lon1)
    h = math.sin(dlat / 2) ** 2 + math.cos(a1) * math.cos(a2) * math.sin(dlon / 2) ** 2
    return 2 * 6371.0088 * math.asin(math.sqrt(min(1, max(0, h))))


def create_app(url: str | None = None, *, enable_push: bool | None = None):
    validate_settings()
    engine, sessions = make_database(url or database_url())

    @asynccontextmanager
    async def lifespan(app):
        if production():
            validate_schema(engine)
            if not mail_configured() or not os.getenv("APP_CONTACT_EMAIL"):
                raise RuntimeError(
                    "Produção exige SMTP_HOST, SMTP_FROM e APP_CONTACT_EMAIL configurados."
                )
        else:
            initialize_schema(engine)
            with sessions.begin() as session:
                populate_categories(session)
        stopped = asyncio.Event()
        sender = (
            firebase_sender()
            if (url is None if enable_push is None else enable_push)
            else None
        )
        app.state.push_available = sender is not None
        if production() and not sender:
            raise RuntimeError(
                "Configure o Firebase Admin antes de iniciar as notificações de produção."
            )
        expiry_worker = asyncio.create_task(hold_worker(sessions, stopped))
        worker = (
            asyncio.create_task(push_worker(sessions, sender, stopped))
            if sender
            else None
        )
        events_worker = (
            asyncio.create_task(event_worker(sessions, sender, stopped))
            if sender
            else None
        )
        email_worker = (
            asyncio.create_task(mail_worker(sessions, stopped))
            if mail_configured()
            else None
        )
        yield
        stopped.set()
        await expiry_worker
        if worker:
            await worker
        if events_worker:
            await events_worker
        if email_worker:
            await email_worker
        engine.dispose()

    errors = {
        code: {
            "model": s.ErrorOut,
            "description": description,
            "content": {"application/json": {"example": {"detail": description}}},
        }
        for code, description in {
            400: "Dados inválidos ou código expirado.",
            401: "Autenticação necessária ou sessão expirada.",
            403: "Permissão insuficiente.",
            404: "Recurso não encontrado.",
            409: "Conflito: registro duplicado ou transição inválida.",
            429: "Muitas tentativas. Aguarde antes de tentar novamente.",
            410: "Operação descontinuada; utilize o canal WebSocket.",
            413: "Solicitação muito grande.",
            503: "Serviço temporariamente indisponível.",
        }.items()
    }
    errors[429]["headers"] = {
        "Retry-After": {
            "description": "Tempo máximo para tentar novamente, em segundos.",
            "schema": {"type": "integer", "minimum": 1},
            "example": 900,
        }
    }
    app = FastAPI(
        title="Zé Resolve — API REST",
        version="1.0.0",
        lifespan=lifespan,
        description="API do Projeto Integrador. JSON; horários em UTC; preços em centavos. "
        "Clientes solicitam serviços e avaliam; profissionais recebem, aceitam, iniciam e concluem. "
        "Cada participante acessa somente suas solicitações e mensagens. "
        "Campos desconhecidos são rejeitados (422). Listas possuem offset e limit. "
        "O cadastro de profissional requer completar PUT /professionals/me antes de aparecer nas buscas.",
        responses=errors,
    )
    app.state.engine = engine
    app.state.sessions = sessions
    hosts = trusted_hosts()
    if hosts:
        app.add_middleware(TrustedHostMiddleware, allowed_hosts=hosts)

    @app.middleware("http")
    async def protect_private_responses(request, call_next):
        private = (
            request.url.path.startswith(
                (
                    "/auth/",
                    "/users/",
                    "/requests",
                    "/notifications",
                    "/request-events",
                    "/account/",
                )
            )
            or "authorization" in request.headers
        )
        if secure_transport() and request.url.scheme != "https":
            response = JSONResponse(
                status_code=400, content={"detail": "Acesso seguro HTTPS obrigatório."}
            )
        else:
            response = await call_next(request)
        response.headers["X-Content-Type-Options"] = "nosniff"
        if private:
            response.headers["Cache-Control"] = "no-store"
            response.headers["Pragma"] = "no-cache"
        return response

    @app.exception_handler(RequestValidationError)
    async def validation_error(request, error):
        return JSONResponse(
            status_code=422,
            content={
                "detail": [
                    {"loc": item["loc"], "msg": item["msg"], "type": item["type"]}
                    for item in error.errors()
                ]
            },
        )

    origins = os.getenv(
        "CORS_ORIGINS", "http://localhost:8080,http://127.0.0.1:8080"
    ).split(",")
    app.add_middleware(
        CORSMiddleware,
        allow_origins=[o.strip() for o in origins if o.strip()],
        allow_credentials=False,
        allow_methods=["GET", "POST", "PUT", "PATCH"],
        allow_headers=["Authorization", "Content-Type"],
    )
    app.add_middleware(HttpControls)

    def db():
        with sessions() as session:
            yield session

    DB = Annotated[Session, Depends(db)]

    def current_user(
        db: DB,
        credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)],
    ):
        token = (
            db.get(m.AuthToken, token_digest(credentials.credentials))
            if credentials
            else None
        )
        if (
            not token
            or token.revoked_at is not None
            or aware(token.expires_at) <= datetime.now(timezone.utc)
        ):
            raise HTTPException(
                401,
                "Autenticação necessária ou sessão expirada.",
                headers={"WWW-Authenticate": "Bearer"},
            )
        user = db.get(m.User, token.user_id)
        if not user or not user.is_active:
            raise HTTPException(
                401, "Sessão inválida.", headers={"WWW-Authenticate": "Bearer"}
            )
        return user

    User = Annotated[m.User, Depends(current_user)]
    Limit = Annotated[int, Query(ge=1, le=100)]
    Offset = Annotated[int, Query(ge=0)]
    register_account_access(app, engine, sessions, User, DB)
    register_policies(app)

    @app.get(
        "/request-events",
        tags=["Notificações"],
        response_model=list[s.RequestEventOut],
        summary="Listar meus avisos de agendamento",
    )
    def request_events(user: User, db: DB, limit: Limit = 50, offset: Offset = 0):
        return [
            event_out(event)
            for event in db.scalars(
                select(m.RequestEvent)
                .where(m.RequestEvent.user_id == user.id)
                .order_by(m.RequestEvent.id.desc())
                .offset(offset)
                .limit(limit)
            )
        ]

    @app.post(
        "/request-events/{event_id}/read",
        tags=["Notificações"],
        status_code=204,
        summary="Marcar meu aviso de agendamento como lido",
    )
    def read_event(event_id: int, user: User, db: DB):
        event = db.get(m.RequestEvent, event_id)
        if not event or event.user_id != user.id:
            raise HTTPException(404, "Aviso não encontrado.")
        event.read_at = event.read_at or datetime.now(timezone.utc)
        commit(db)
        return Response(status_code=204)

    def commit(db):
        try:
            db.commit()
        except IntegrityError:
            db.rollback()
            raise HTTPException(
                409, "Registro duplicado ou vínculo inválido."
            ) from None

    def flush(db):
        try:
            db.flush()
        except IntegrityError:
            db.rollback()
            raise HTTPException(
                409, "Registro duplicado ou vínculo inválido."
            ) from None

    def require_role(user, role):
        if user.role != role:
            raise HTTPException(403, "Permissão insuficiente.")

    def owned_request(db, request_id, user):
        request = db.get(m.ServiceRequest, request_id)
        if not request:
            raise HTTPException(404, "Solicitação não encontrada.")
        if user.id not in (request.client_id, request.professional_id):
            raise HTTPException(403, "Você não participa desta solicitação.")
        return request

    def request_out(request):
        return s.RequestOut(
            id=request.id,
            client_id=request.client_id,
            client_name=request.client.name,
            professional_id=request.professional_id,
            professional_name=request.professional.user.name,
            slot_id=request.slot_id,
            visit_fee_cents=request.visit_fee_cents,
            title=request.title,
            description=request.description,
            address=request.address,
            scheduled_at=aware(request.scheduled_at),
            duration_minutes=request.duration_minutes,
            status=request.status,
            hold_expires_at=(
                aware(request.hold_expires_at) if request.hold_expires_at else None
            ),
            cancellation_reason=request.cancellation_reason,
            cancelled_by=request.cancelled_by,
            created_at=aware(request.created_at),
            review_id=request.review.id if request.review else None,
        )

    def professional_out(db, pro, distance=None):
        stats = getattr(db, "professional_ratings", None)
        if stats is None:
            stats = {
                pid: (average, count)
                for pid, average, count in db.execute(
                    select(
                        m.ServiceRequest.professional_id,
                        func.avg(m.Review.rating),
                        func.count(m.Review.id),
                    )
                    .join(m.ServiceRequest)
                    .group_by(m.ServiceRequest.professional_id)
                )
            }
            db.professional_ratings = stats
        rating, count = stats.get(pro.id, (0, 0))
        return s.ProfessionalOut(
            id=pro.id,
            name=pro.public_name,
            category_id=pro.category_id,
            category_name=pro.category.name,
            bio=pro.bio,
            city=pro.city,
            visit_fee_cents=pro.visit_fee_cents,
            next_available_at=(
                aware(next_available_by_professional(db)[pro.id])
                if pro.id in next_available_by_professional(db)
                else None
            ),
            is_available=pro.is_available,
            distance_km=round(distance, 2) if distance is not None else None,
            rating=round(rating or 0, 2),
            review_count=count,
        )

    def review_out(review):
        return s.ReviewOut(
            id=review.id,
            request_id=review.request_id,
            rating=review.rating,
            comment=review.comment,
            client_name=review.request.client.name,
            created_at=aware(review.created_at),
        )

    @app.get(
        "/health",
        tags=["Sistema"],
        summary="Verificar disponibilidade",
        response_model=dict[str, str],
    )
    def health(db: DB):
        db.execute(select(1))
        return {"status": "ok"}

    @app.post(
        "/auth/register",
        tags=["Autenticação"],
        response_model=s.UserOut,
        status_code=201,
        summary="Cadastrar cliente ou profissional",
        description="Pública. Email único (normalizado para minúsculas). Dados pessoais protegidos com AES-GCM e email localizado por índice HMAC. Senha de no mínimo 8 caracteres e no máximo 72 bytes UTF-8, armazenada com bcrypt (custo 12 e salt individual). Perfil imutável. Limite de 20 tentativas por IP por hora; excesso retorna 429 com Retry-After.",
    )
    def register(body: s.Register, db: DB, request: Request):
        authentication_limit(engine, request, "register")
        if production() and (
            not body.accepted_terms or body.terms_version != TERMS_VERSION
        ):
            raise HTTPException(
                422,
                "Leia e aceite a versão atual dos termos e da política de privacidade.",
            )
        user = m.User(
            name=body.name,
            phone=body.phone,
            email=str(body.email).lower(),
            role=body.role.value,
            password_hash=passwords.hash(body.password),
            terms_version=body.terms_version if body.accepted_terms else None,
            terms_accepted_at=(
                datetime.now(timezone.utc) if body.accepted_terms else None
            ),
        )
        db.add(user)
        flush(db)
        if production():
            issue_code(db, user, "verify")
        commit(db)
        return {
            **s.UserOut.model_validate(user).model_dump(),
            "verification_required": production() and user.email_verified_at is None,
        }

    @app.post(
        "/auth/login",
        tags=["Autenticação"],
        response_model=s.TokenOut,
        summary="Autenticar com email e senha",
        description="Pública. Retorna token Bearer opaco válido por 30 dias corridos a partir do login, sem renovação automática. Somente o hash do token fica no banco. Cada login cria uma sessão independente. Limite de 10 tentativas por conta e 60 por IP a cada 15 minutos, incluindo sucessos; excesso retorna 429 com Retry-After.",
    )
    def login(body: s.Login, db: DB, request: Request):
        authentication_limit(engine, request, "login", body.email)
        user = db.scalar(
            select(m.User).where(m.User.email_lookup == email_lookup(body.email))
        )
        valid = passwords.verify(
            body.password, user.password_hash if user else dummy_hash
        )
        if not user or not user.is_active or not valid:
            raise HTTPException(
                401, "Email ou senha inválidos.", headers={"WWW-Authenticate": "Bearer"}
            )
        if production() and not user.email_verified_at:
            raise HTTPException(403, "Confirme seu email antes de entrar.")
        locked = db.execute(
            update(m.User)
            .where(m.User.id == user.id, m.User.password_hash == user.password_hash)
            .where(m.User.is_active.is_(True))
            .values(password_hash=m.User.password_hash)
        )
        if locked.rowcount != 1:
            db.rollback()
            raise HTTPException(
                401, "Email ou senha inválidos.", headers={"WWW-Authenticate": "Bearer"}
            )
        raw = secrets.token_urlsafe(32)
        expiry = datetime.now(timezone.utc) + timedelta(days=30)
        db.add(
            m.AuthToken(
                digest=token_digest(raw),
                user_id=user.id,
                expires_at=expiry,
                original_expires_at=expiry,
            )
        )
        commit(db)
        return s.TokenOut(
            access_token=raw, expires_at=expiry, user=s.UserOut.model_validate(user)
        )

    @app.post(
        "/auth/logout",
        tags=["Autenticação"],
        status_code=204,
        summary="Revogar a sessão atual",
        description="Qualquer usuário autenticado. O token revogado deixa de funcionar imediatamente.",
    )
    def logout(
        user: User,
        db: DB,
        credentials: Annotated[HTTPAuthorizationCredentials, Depends(bearer)],
    ):
        now = datetime.now(timezone.utc)
        db.execute(
            update(m.PushDevice)
            .where(m.PushDevice.session_digest == token_digest(credentials.credentials))
            .values(is_active=False)
        )
        db.execute(
            update(m.AuthToken)
            .where(m.AuthToken.digest == token_digest(credentials.credentials))
            .values(expires_at=now - timedelta(seconds=1), revoked_at=now)
        )
        commit(db)
        return Response(status_code=204)

    @app.get(
        "/users/me",
        tags=["Usuários"],
        response_model=s.UserOut,
        summary="Consultar meus dados",
        description="Autenticada. Retorna somente o usuário do token; nunca expõe senha ou hash.",
    )
    def me(user: User):
        return user

    @app.patch(
        "/users/me",
        tags=["Usuários"],
        response_model=s.UserOut,
        summary="Atualizar nome e telefone",
        description="Autenticada. Nome obrigatório; telefone opcional. Email e perfil não podem ser alterados por esta operação.",
    )
    def update_me(body: s.UserInput, user: User, db: DB):
        user.name, user.phone = body.name, body.phone
        db.execute(
            update(m.Professional)
            .where(m.Professional.id == user.id)
            .values(public_name=body.name)
        )
        commit(db)
        return user

    @app.post(
        "/users/me/password",
        tags=["Usuários"],
        status_code=204,
        summary="Alterar minha senha",
        description="Exige senha atual. Nova senha: 8 caracteres a 72 bytes UTF-8, bcrypt. Revoga todas as sessões, inclusive a atual, preservando os registros. Faça login novamente. Limite de 10 tentativas por conta e 60 por IP a cada 15 minutos; excesso retorna 429 com Retry-After.",
    )
    def change_password(body: s.PasswordChange, user: User, db: DB, request: Request):
        authentication_limit(engine, request, "password", user.id)
        previous = user.password_hash
        if not passwords.verify(body.current_password, previous):
            raise HTTPException(403, "A senha atual está incorreta.")
        if body.current_password == body.new_password:
            raise HTTPException(422, "Escolha uma senha diferente da atual.")
        changed = db.execute(
            update(m.User)
            .where(m.User.id == user.id, m.User.password_hash == previous)
            .values(password_hash=passwords.hash(body.new_password))
        )
        if changed.rowcount != 1:
            db.rollback()
            raise HTTPException(409, "Sua senha foi alterada. Entre novamente.")
        now = datetime.now(timezone.utc)
        db.execute(
            update(m.PushDevice)
            .where(m.PushDevice.user_id == user.id)
            .values(is_active=False)
        )
        db.execute(
            update(m.AuthToken)
            .where(m.AuthToken.user_id == user.id, m.AuthToken.revoked_at.is_(None))
            .values(revoked_at=now, expires_at=now - timedelta(seconds=1))
        )
        commit(db)
        return Response(status_code=204)

    def own_address(address_id, user, db):
        address = db.get(m.Address, address_id)
        if not address or address.user_id != user.id or not address.is_active:
            raise HTTPException(404, "Endereço não encontrado.")
        return address

    def lock_addresses(user, db):
        db.execute(
            update(m.User).where(m.User.id == user.id).values(phone=m.User.phone)
        )

    @app.get(
        "/users/me/addresses",
        response_model=list[s.AddressOut],
        tags=["Endereços"],
        summary="Listar meus endereços",
        description="Autenticada. Apenas endereços ativos do proprietário. Endereço padrão primeiro.",
    )
    def addresses(user: User, db: DB):
        return db.scalars(
            select(m.Address)
            .where(m.Address.user_id == user.id, m.Address.is_active.is_(True))
            .order_by(m.Address.is_default.desc(), m.Address.id)
        ).all()

    @app.put(
        "/users/me/push-device",
        status_code=204,
        tags=["Notificações"],
        summary="Cadastrar dispositivo para push",
        description="Autenticada. Token FCM privado associado à sessão atual. Inativado em logout, expiração ou troca de senha. Reenvio idempotente; nada é apagado.",
    )
    def put_push_device(
        body: s.PushDeviceInput,
        user: User,
        db: DB,
        credentials: Annotated[HTTPAuthorizationCredentials, Depends(bearer)],
    ):
        digest = token_digest(body.token)
        device = db.get(m.PushDevice, digest)
        if not device:
            device = m.PushDevice(digest=digest)
            db.add(device)
        device.user_id, device.token = user.id, body.token
        device.session_digest, device.is_active = (
            token_digest(credentials.credentials),
            True,
        )
        commit(db)
        return Response(status_code=204)

    @app.get(
        "/users/me/notification-settings",
        tags=["Notificações"],
        response_model=dict[str, bool],
        summary="Consultar disponibilidade de push",
        description="Autenticada. Informa se o servidor inicializou o envio de notificações; não expõe credenciais nem garante entrega pelo provedor.",
    )
    def notification_settings(user: User):
        return {"push_available": app.state.push_available}

    @app.post(
        "/users/me/addresses",
        response_model=s.AddressOut,
        status_code=201,
        tags=["Endereços"],
        summary="Adicionar endereço",
        description="Autenticada. Até 20 endereços ativos por usuário. Primeiro endereço torna-se padrão. CEP: 8 dígitos; UF brasileira. Não publica dados no catálogo.",
    )
    def add_address(body: s.AddressInput, user: User, db: DB):
        lock_addresses(user, db)
        count = db.scalar(
            select(func.count())
            .select_from(m.Address)
            .where(m.Address.user_id == user.id, m.Address.is_active.is_(True))
        )
        if count >= 20:
            raise HTTPException(
                409,
                "Você pode manter até 20 endereços. Arquive um antes de adicionar outro.",
            )
        data = body.model_dump()
        data["is_default"] = body.is_default or count == 0
        if data["is_default"]:
            db.execute(
                update(m.Address)
                .where(m.Address.user_id == user.id)
                .values(is_default=False)
            )
        address = m.Address(user_id=user.id, **data)
        db.add(address)
        commit(db)
        return address

    @app.put(
        "/users/me/addresses/{address_id}",
        response_model=s.AddressOut,
        tags=["Endereços"],
        summary="Editar endereço",
        description="Somente proprietário. Preserva o padrão se este já era o endereço padrão. Para trocar, marque outro como padrão.",
    )
    def edit_address(address_id: int, body: s.AddressInput, user: User, db: DB):
        lock_addresses(user, db)
        address = own_address(address_id, user, db)
        default = body.is_default or address.is_default
        if default:
            db.execute(
                update(m.Address)
                .where(m.Address.user_id == user.id)
                .values(is_default=False)
            )
        for key, value in body.model_dump().items():
            setattr(address, key, value)
        address.is_default = default
        commit(db)
        return address

    @app.post(
        "/users/me/addresses/{address_id}/archive",
        status_code=204,
        tags=["Endereços"],
        summary="Arquivar endereço",
        description="Somente proprietário. Desativa sem apagar. Se era padrão, outro endereço ativo assume. Não altera o endereço já combinado em solicitações.",
    )
    def archive_address(address_id: int, user: User, db: DB):
        lock_addresses(user, db)
        address = own_address(address_id, user, db)
        was_default = address.is_default
        address.is_active = address.is_default = False
        db.flush()
        if was_default:
            replacement = db.scalar(
                select(m.Address)
                .where(m.Address.user_id == user.id, m.Address.is_active.is_(True))
                .order_by(m.Address.id)
            )
            if replacement:
                replacement.is_default = True
        commit(db)
        return Response(status_code=204)

    @app.get(
        "/notifications",
        response_model=list[s.NotificationOut],
        tags=["Notificações"],
        summary="Consultar mensagens recebidas",
        description="Autenticada. Avisos privados de mensagens recebidas, mais recentes primeiro. Leitura sincronizada entre dispositivos; offset e limit.",
    )
    def notifications(user: User, db: DB, offset: Offset = 0, limit: Limit = 50):
        rows = db.execute(
            select(m.Message, m.User.name, m.MessageReceipt.read_at)
            .join(m.ServiceRequest, m.ServiceRequest.id == m.Message.request_id)
            .join(m.User, m.User.id == m.Message.sender_id)
            .outerjoin(
                m.MessageReceipt,
                (m.MessageReceipt.message_id == m.Message.id)
                & (m.MessageReceipt.user_id == user.id),
            )
            .where(
                (m.ServiceRequest.client_id == user.id)
                | (m.ServiceRequest.professional_id == user.id)
            )
            .where(m.Message.sender_id != user.id)
            .order_by(m.Message.id.desc())
            .offset(offset)
            .limit(limit)
        ).all()
        return [
            s.NotificationOut(
                id=msg.id,
                request_id=msg.request_id,
                sender_name=name,
                body=msg.body,
                created_at=aware(msg.created_at),
                is_read=read is not None,
            )
            for msg, name, read in rows
        ]

    @app.post(
        "/notifications/{message_id}/read",
        status_code=204,
        tags=["Notificações"],
        summary="Marcar mensagem recebida como lida",
        description="Autenticada, participante destinatário. Idempotente; mantém o histórico.",
    )
    def read_notification(message_id: int, user: User, db: DB):
        message = db.get(m.Message, message_id)
        if not message or message.sender_id == user.id:
            raise HTTPException(404, "Mensagem recebida não encontrada.")
        owned_request(db, message.request_id, user)
        if not db.get(m.MessageReceipt, (user.id, message_id)):
            db.add(m.MessageReceipt(user_id=user.id, message_id=message_id))
            try:
                db.commit()
            except IntegrityError:
                db.rollback()
                if not db.get(m.MessageReceipt, (user.id, message_id)):
                    raise
        return Response(status_code=204)

    @app.get(
        "/categories",
        tags=["Catálogo"],
        response_model=list[s.CategoryOut],
        summary="Listar categorias",
        description="Pública. Categorias são mantidas pelo servidor, sem edição pelas interfaces.",
    )
    def categories(db: DB):
        return db.scalars(select(m.Category).order_by(m.Category.id)).all()

    @app.put(
        "/professionals/me",
        tags=["Profissionais"],
        response_model=s.ProfessionalOut,
        summary="Criar ou substituir meu perfil profissional",
        description="Somente profissional. Categoria deve existir. Valor fixo da visita em centavos, de 0 a 10.000.000, obrigatório; não representa o total do serviço. Preços tabelados adicionais podem ser descritos em bio. O ID vem do token. Mudanças de preço não alteram reservas anteriores.",
    )
    def put_professional(body: s.ProfessionalInput, user: User, db: DB):
        require_role(user, "profissional")
        if not db.get(m.Category, body.category_id):
            raise HTTPException(404, "Categoria não encontrada.")
        pro = lock_professional(db, user.id)
        if not pro:
            pro = m.Professional(id=user.id)
            db.add(pro)
        values = body.model_dump()
        pro.latitude_private, pro.longitude_private = (
            values["latitude"],
            values["longitude"],
        )
        values["latitude"] = (
            round(values["latitude"], 2) if values["latitude"] is not None else None
        )
        values["longitude"] = (
            round(values["longitude"], 2) if values["longitude"] is not None else None
        )
        pro.public_name = user.name
        for key, value in values.items():
            setattr(pro, key, value)
        commit(db)
        db.refresh(pro)
        return professional_out(db, pro)

    @app.get(
        "/professionals/me",
        tags=["Profissionais"],
        response_model=s.ProfessionalOwnOut,
        summary="Consultar minha base de atendimento",
        description="Somente profissional autenticado. Inclui suas coordenadas privadas.",
    )
    def my_professional(user: User, db: DB):
        require_role(user, "profissional")
        pro = db.get(m.Professional, user.id)
        if not pro:
            raise HTTPException(404, "Complete seu perfil profissional.")
        result = s.ProfessionalOwnOut.model_validate(pro, from_attributes=True)
        result.latitude, result.longitude = pro.latitude_private, pro.longitude_private
        return result

    def slot_out(slot, *, booked=False):
        return s.AvailabilityOut(
            id=slot.id,
            professional_id=slot.professional_id,
            starts_at=aware(slot.starts_at),
            ends_at=aware(slot.ends_at),
            is_active=slot.is_active,
            is_booked=booked,
        )

    @app.get(
        "/professionals/me/availability",
        tags=["Agenda"],
        response_model=list[s.AvailabilityOut],
        summary="Consultar meus horários publicados",
        description="Somente profissional. Retorna horários ativos futuros, inclusive os reservados, sem identificar clientes. from/to ISO 8601 com fuso limitam os inícios; paginação por offset/limit.",
    )
    def my_availability(
        user: User,
        db: DB,
        from_at: Annotated[datetime | None, Query(alias="from")] = None,
        to_at: Annotated[datetime | None, Query(alias="to")] = None,
        limit: Limit = 20,
        offset: Offset = 0,
    ):
        require_role(user, "profissional")
        if not db.get(m.Professional, user.id):
            raise HTTPException(404, "Complete seu perfil profissional.")
        start, end = availability_window(from_at, to_at)
        rows = db.execute(
            select(m.AvailabilitySlot, slot_occupied_condition(db).label("is_booked"))
            .where(
                m.AvailabilitySlot.professional_id == user.id,
                m.AvailabilitySlot.is_active.is_(True),
                m.AvailabilitySlot.starts_at > datetime.now(timezone.utc),
                m.AvailabilitySlot.starts_at >= start,
                m.AvailabilitySlot.starts_at <= end,
            )
            .order_by(m.AvailabilitySlot.starts_at, m.AvailabilitySlot.id)
            .offset(offset)
            .limit(limit)
        )
        return [slot_out(slot, booked=booked) for slot, booked in rows]

    @app.post(
        "/professionals/me/availability",
        tags=["Agenda"],
        response_model=s.AvailabilityOut,
        status_code=201,
        summary="Publicar horário de atendimento",
        description="Somente profissional com valor de visita definido. Início futuro até 180 dias; duração inteira de 30 a 480 minutos. Horários contíguos são permitidos; sobreposições com horários ativos ou serviços reservados retornam 409. Até 200 horários ativos futuros por profissional. A pausa geral do perfil não apaga a agenda.",
    )
    def publish_availability(body: s.AvailabilityInput, user: User, db: DB):
        require_role(user, "profissional")
        pro = lock_professional(db, user.id)
        if not pro:
            raise HTTPException(404, "Complete seu perfil profissional.")
        if pro.visit_fee_cents is None:
            raise HTTPException(
                409,
                "Defina o valor da visita no seu perfil antes de publicar horários.",
            )
        now = datetime.now(timezone.utc)
        if body.starts_at <= now:
            raise HTTPException(
                409, "Este horário já passou. Escolha um horário futuro."
            )
        overlap = db.scalar(
            select(m.AvailabilitySlot.id)
            .where(
                m.AvailabilitySlot.professional_id == user.id,
                m.AvailabilitySlot.is_active.is_(True),
                m.AvailabilitySlot.starts_at < body.ends_at,
                m.AvailabilitySlot.ends_at > body.starts_at,
            )
            .limit(1)
        )
        if overlap or conflicting_request(db, user.id, body.starts_at, body.ends_at):
            raise HTTPException(
                409, "Este horário conflita com sua agenda. Escolha outro intervalo."
            )
        count = db.scalar(
            select(func.count())
            .select_from(m.AvailabilitySlot)
            .where(
                m.AvailabilitySlot.professional_id == user.id,
                m.AvailabilitySlot.is_active.is_(True),
                m.AvailabilitySlot.starts_at > now,
            )
        )
        if count >= 200:
            raise HTTPException(
                409,
                "Você já publicou 200 horários futuros. Remova um horário livre antes de adicionar outro.",
            )
        slot = m.AvailabilitySlot(professional_id=user.id, **body.model_dump())
        db.add(slot)
        commit(db)
        return slot_out(slot)

    @app.post(
        "/professionals/me/availability/{slot_id}/archive",
        tags=["Agenda"],
        response_model=s.AvailabilityOut,
        summary="Retirar horário livre da agenda",
        description="Somente o prestador proprietário. Invalida o horário sem apagá-lo; repetição é idempotente. Um horário ocupado retorna 409 e não cancela a solicitação. Nenhum cliente ou identificador de reserva é exposto.",
    )
    def archive_availability(slot_id: int, user: User, db: DB):
        require_role(user, "profissional")
        lock_professional(db, user.id)
        expire_professional_holds(db, user.id)
        slot = db.get(m.AvailabilitySlot, slot_id)
        if not slot or slot.professional_id != user.id:
            raise HTTPException(404, "Horário não encontrado.")
        if conflicting_request(db, user.id, slot.starts_at, slot.ends_at):
            raise HTTPException(
                409, "Este horário possui uma solicitação e não pode ser retirado."
            )
        slot.is_active = False
        commit(db)
        return slot_out(slot)

    @app.get(
        "/professionals",
        tags=["Profissionais"],
        response_model=list[s.ProfessionalOut],
        summary="Buscar profissionais por categoria e proximidade",
        description="Pública. Coordenadas devem ser fornecidas juntas. Com localização, filtra pelo raio e ordena por distância antes da paginação. Sem localização, não calcula distância. Perfis sem base cadastrada ficam fora da busca por proximidade. Distância em linha reta calculada sobre base pública arredondada a duas casas decimais (aproximadamente 1 km); a base exata fica cifrada e nunca participa da consulta pública. A aproximação pode incluir/excluir profissionais próximos ao limite do raio.",
    )
    def professionals(
        db: DB,
        category_id: Annotated[int | None, Query(gt=0)] = None,
        q: Annotated[str, Query(max_length=100)] = "",
        city: Annotated[str, Query(max_length=100)] = "",
        latitude: Annotated[
            float | None, Query(ge=-90, le=90, allow_inf_nan=False)
        ] = None,
        longitude: Annotated[
            float | None, Query(ge=-180, le=180, allow_inf_nan=False)
        ] = None,
        radius_km: Annotated[float, Query(gt=0, le=200, allow_inf_nan=False)] = 25,
        available: bool | None = None,
        available_within_hours: Annotated[
            int | None,
            Query(
                ge=1,
                le=168,
                description="Filtra horários livres que começam nas próximas N horas, inclusive 24 horas para urgências. Não garante atendimento emergencial.",
            ),
        ] = None,
        sort: Annotated[str, Query(pattern="^(distance|rating)$")] = "distance",
        limit: Limit = 20,
        offset: Offset = 0,
    ):
        if (latitude is None) != (longitude is None):
            raise HTTPException(422, "Informe latitude e longitude juntas.")
        stmt = (
            select(m.Professional)
            .options(joinedload(m.Professional.category))
            .join(m.Category)
            .join(m.User, m.User.id == m.Professional.id)
            .where(m.User.is_active.is_(True))
        )
        if category_id:
            stmt = stmt.where(m.Professional.category_id == category_id)
        if q:
            stmt = stmt.where(
                m.Professional.public_name.contains(q, autoescape=True)
                | m.Category.name.contains(q, autoescape=True)
            )
        if city:
            stmt = stmt.where(m.Professional.city.contains(city, autoescape=True))
        available_ids = select(m.AvailabilitySlot.professional_id).where(
            m.AvailabilitySlot.is_active.is_(True),
            m.AvailabilitySlot.starts_at > datetime.now(timezone.utc),
            ~slot_occupied_condition(db),
        )
        availability = (
            m.Professional.is_available.is_(True)
            & m.Professional.visit_fee_cents.is_not(None)
            & m.Professional.id.in_(available_ids)
        )
        if available is not None:
            stmt = stmt.where(availability if available else ~availability)
        if available_within_hours is not None:
            urgent_ids = available_ids.where(
                m.AvailabilitySlot.starts_at
                <= datetime.now(timezone.utc) + timedelta(hours=available_within_hours)
            )
            stmt = stmt.where(
                m.Professional.is_available.is_(True),
                m.Professional.visit_fee_cents.is_not(None),
                m.Professional.id.in_(urgent_ids),
            )
        if latitude is not None:
            delta = math.degrees(radius_km / 6371.0088)
            stmt = stmt.where(
                m.Professional.latitude.between(latitude - delta, latitude + delta),
                m.Professional.longitude.is_not(None),
            )
        rows = []
        for pro in db.scalars(stmt):
            distance = (
                haversine(latitude, longitude, pro.latitude, pro.longitude)
                if latitude is not None
                else None
            )
            if distance is not None and distance > radius_km:
                continue
            rows.append((professional_out(db, pro, distance), distance))
        rows.sort(
            key=lambda item: (
                (
                    -item[0].rating,
                    item[1] if item[1] is not None else math.inf,
                    item[0].id,
                )
                if sort == "rating"
                else (
                    item[1] if item[1] is not None else math.inf,
                    -item[0].rating,
                    item[0].id,
                )
            )
        )
        return [item[0] for item in rows[offset : offset + limit]]

    @app.get(
        "/professionals/{professional_id}/availability",
        tags=["Agenda"],
        response_model=list[s.AvailabilityOut],
        summary="Consultar horários livres de um prestador",
        description="Pública. Somente horários ativos futuros e livres de reservas, com prestador sem pausa e valor de visita definido. Pendentes já ocupam a vaga até aceitação, recusa ou cancelamento. Nenhuma informação de clientes é exposta. from/to filtram os inícios (fuso obrigatório); limite padrão 20 e máximo 100.",
    )
    def public_availability(
        professional_id: int,
        db: DB,
        from_at: Annotated[datetime | None, Query(alias="from")] = None,
        to_at: Annotated[datetime | None, Query(alias="to")] = None,
        limit: Limit = 20,
        offset: Offset = 0,
    ):
        pro = db.get(m.Professional, professional_id)
        if not pro or not pro.user.is_active:
            raise HTTPException(404, "Profissional não encontrado.")
        start, end = availability_window(from_at, to_at)
        if not pro.is_available or pro.visit_fee_cents is None:
            return []
        slots = db.scalars(
            free_slots_query(db)
            .where(
                m.AvailabilitySlot.professional_id == professional_id,
                m.AvailabilitySlot.starts_at >= start,
                m.AvailabilitySlot.starts_at <= end,
            )
            .order_by(m.AvailabilitySlot.starts_at, m.AvailabilitySlot.id)
            .offset(offset)
            .limit(limit)
        )
        return [slot_out(slot) for slot in slots]

    @app.get(
        "/professionals/{professional_id}",
        tags=["Profissionais"],
        response_model=s.ProfessionalOut,
        summary="Consultar perfil público",
        description="Pública. Média e quantidade de avaliações calculadas a partir de serviços concluídos.",
    )
    def professional(professional_id: int, db: DB):
        pro = db.get(m.Professional, professional_id)
        if not pro or not pro.user.is_active:
            raise HTTPException(404, "Profissional não encontrado.")
        return professional_out(db, pro)

    @app.post(
        "/requests",
        tags=["Solicitações"],
        response_model=s.RequestOut,
        status_code=201,
        summary="Solicitar um serviço",
        description="Somente cliente. Escolha slot_id livre publicado pelo profissional. Início e duração vêm do horário; client_id, valor fixo da visita e estado pendente vêm do servidor. expected_visit_fee_cents deve conferir com o perfil, senão retorna 409. Pendente já ocupa a vaga, mas ainda requer aceite do prestador. Repetir a mesma reserva pelo mesmo cliente e com dados idênticos recupera o registro existente; outra pessoa ou dados diferentes retornam 409.",
    )
    def create_request(body: s.RequestInput, user: User, db: DB):
        require_role(user, "cliente")
        db.execute(
            update(m.User).where(m.User.id == user.id).values(phone=m.User.phone)
        )
        pro = lock_professional(db, body.professional_id)
        if not pro:
            raise HTTPException(404, "Profissional não encontrado.")
        expire_professional_holds(db, pro.id)
        slot = db.get(m.AvailabilitySlot, body.slot_id)
        if not slot or slot.professional_id != pro.id:
            raise HTTPException(404, "Horário não encontrado para este profissional.")
        existing = db.scalar(
            select(m.ServiceRequest).where(
                m.ServiceRequest.slot_id == slot.id,
                m.ServiceRequest.status.in_(OCCUPIED_STATUSES),
            )
        )
        if existing:
            if (
                existing.client_id == user.id
                and existing.title == body.title
                and existing.description == body.description
                and existing.address == body.address
                and existing.visit_fee_cents == body.expected_visit_fee_cents
            ):
                return request_out(existing)
            raise HTTPException(
                409, "Este horário já foi reservado. Escolha outro horário."
            )
        if not pro.is_available:
            raise HTTPException(
                409, "Profissional indisponível para novas solicitações."
            )
        pending = db.scalar(
            select(func.count())
            .select_from(m.ServiceRequest)
            .where(
                m.ServiceRequest.client_id == user.id,
                m.ServiceRequest.status == "pendente",
                (m.ServiceRequest.hold_expires_at.is_(None))
                | (m.ServiceRequest.hold_expires_at > datetime.now(timezone.utc)),
            )
        )
        if pending >= 5:
            raise HTTPException(
                409,
                "Você já possui cinco solicitações aguardando resposta. Cancele uma ou aguarde o prestador.",
            )
        if pro.visit_fee_cents is None:
            raise HTTPException(
                409, "Este prestador ainda não definiu o valor da visita."
            )
        if pro.visit_fee_cents != body.expected_visit_fee_cents:
            raise HTTPException(
                409, "O valor da visita mudou. Atualize a agenda antes de confirmar."
            )
        if not slot.is_active or aware(slot.starts_at) <= datetime.now(timezone.utc):
            raise HTTPException(
                409, "Este horário não está mais disponível. Escolha outro horário."
            )
        if conflicting_request(db, pro.id, slot.starts_at, slot.ends_at):
            raise HTTPException(
                409, "Este horário conflita com outra reserva. Escolha outro horário."
            )
        values = body.model_dump(exclude={"expected_visit_fee_cents"})
        request = m.ServiceRequest(
            client_id=user.id,
            scheduled_at=aware(slot.starts_at),
            duration_minutes=int(
                (aware(slot.ends_at) - aware(slot.starts_at)).total_seconds() // 60
            ),
            visit_fee_cents=pro.visit_fee_cents,
            hold_expires_at=hold_deadline(slot.starts_at),
            **values,
        )
        db.add(request)
        flush(db)
        record_event(
            db,
            request,
            pro.id,
            "created",
            "Você recebeu uma nova solicitação de visita. Responda antes do prazo de reserva.",
        )
        commit(db)
        return request_out(request)

    @app.get(
        "/requests",
        tags=["Solicitações"],
        response_model=list[s.RequestOut],
        summary="Listar minhas solicitações",
        description="Autenticada. Cliente vê as próprias solicitações; profissional vê somente as atribuídas a ele. Filtro por status opcional.",
    )
    def requests(
        user: User,
        db: DB,
        status: s.RequestStatus | None = None,
        agenda: bool = False,
        limit: Limit = 20,
        offset: Offset = 0,
    ):
        owner = (
            m.ServiceRequest.client_id
            if user.role == "cliente"
            else m.ServiceRequest.professional_id
        )
        stmt = select(m.ServiceRequest).where(owner == user.id)
        if status:
            stmt = stmt.where(m.ServiceRequest.status == status.value)
        if agenda:
            stmt = stmt.where(m.ServiceRequest.status.in_(("aceita", "em_andamento")))
            stmt = stmt.order_by(m.ServiceRequest.scheduled_at, m.ServiceRequest.id)
        return [
            request_out(r)
            for r in db.scalars(
                stmt.order_by(m.ServiceRequest.id.desc()).offset(offset).limit(limit)
            )
        ]

    @app.get(
        "/requests/summary",
        tags=["Solicitações"],
        response_model=s.RequestSummaryOut,
        summary="Resumo dos meus atendimentos",
    )
    def requests_summary(user: User, db: DB):
        owner = (
            m.ServiceRequest.client_id
            if user.role == "cliente"
            else m.ServiceRequest.professional_id
        )
        counts = dict(
            db.execute(
                select(m.ServiceRequest.status, func.count())
                .where(owner == user.id)
                .group_by(m.ServiceRequest.status)
            ).all()
        )
        preview = db.scalars(
            select(m.ServiceRequest)
            .where(
                owner == user.id,
                m.ServiceRequest.status.in_(("pendente", "aceita", "em_andamento")),
            )
            .order_by(m.ServiceRequest.scheduled_at, m.ServiceRequest.id)
            .limit(20)
        )
        return {"counts": counts, "requests": [request_out(row) for row in preview]}

    @app.get(
        "/requests/{request_id}",
        tags=["Solicitações"],
        response_model=s.RequestOut,
        summary="Consultar detalhes de uma solicitação",
        description="Somente cliente criador ou profissional atribuído. Outros usuários recebem 403.",
    )
    def request(request_id: int, user: User, db: DB):
        return request_out(owned_request(db, request_id, user))

    @app.patch(
        "/requests/{request_id}/status",
        tags=["Solicitações"],
        response_model=s.RequestOut,
        summary="Alterar etapa do serviço",
        description="Profissional: pendente→aceita/recusada; aceita→em_andamento; em_andamento→concluida. Cliente: pendente/aceita→cancelada. Estados finais não permitem transições. Operação concorrente retorna 409.",
    )
    def transition(request_id: int, body: s.StatusInput, user: User, db: DB):
        request = owned_request(db, request_id, user)
        lock_professional(db, request.professional_id)
        expire_professional_holds(db, request.professional_id)
        db.refresh(request)
        if (
            request.status == "cancelada"
            and request.cancellation_reason == "Prazo de resposta encerrado."
        ):
            commit(db)
            raise HTTPException(
                409,
                "O prazo de resposta terminou. Consulte a agenda para solicitar outro horário.",
            )
        target = body.status.value
        client_targets = {"cancelada"}
        pro_targets = {"aceita", "recusada", "em_andamento", "concluida", "cancelada"}
        if target not in (client_targets if user.role == "cliente" else pro_targets):
            raise HTTPException(403, "Seu perfil não pode executar esta etapa.")
        allowed = (
            {"pendente": {"cancelada"}, "aceita": {"cancelada"}}
            if user.role == "cliente"
            else {
                "pendente": {"aceita", "recusada"},
                "aceita": {"em_andamento", "cancelada"},
                "em_andamento": {"concluida"},
            }
        )
        if target not in allowed.get(request.status, set()):
            raise HTTPException(409, "Transição de estado não permitida.")
        if target == "cancelada" and user.role == "profissional" and not body.reason:
            raise HTTPException(422, "Informe o motivo do cancelamento.")
        if target in {"aceita", "em_andamento"}:
            if target == "aceita" and aware(request.scheduled_at) <= datetime.now(
                timezone.utc
            ):
                raise HTTPException(
                    409,
                    "O horário solicitado já passou. Peça ao cliente uma nova solicitação.",
                )
            start = aware(request.scheduled_at)
            end = start + timedelta(minutes=request.duration_minutes)
            if conflicting_request(
                db, request.professional_id, start, end, excluding=request.id
            ):
                raise HTTPException(
                    409, "Este horário conflita com outra reserva da sua agenda."
                )
            if target == "em_andamento" and db.scalar(
                select(m.ServiceRequest.id)
                .where(
                    m.ServiceRequest.professional_id == request.professional_id,
                    m.ServiceRequest.id != request.id,
                    m.ServiceRequest.status == "em_andamento",
                )
                .limit(1)
            ):
                raise HTTPException(
                    409, "Conclua o serviço em andamento antes de iniciar outro."
                )
        result = db.execute(
            update(m.ServiceRequest)
            .where(
                m.ServiceRequest.id == request_id,
                m.ServiceRequest.status == request.status,
            )
            .values(
                status=target,
                cancelled_by=user.id if target == "cancelada" else None,
                cancellation_reason=body.reason if target == "cancelada" else None,
            )
        )
        if result.rowcount != 1:
            db.rollback()
            raise HTTPException(
                409, "Solicitação alterada por outra operação. Atualize a tela."
            )
        recipient = (
            request.professional_id
            if user.id == request.client_id
            else request.client_id
        )
        labels = {
            "aceita": "Seu agendamento foi aceito.",
            "recusada": "Sua solicitação foi recusada.",
            "cancelada": "O agendamento foi cancelado.",
            "em_andamento": "O atendimento foi iniciado.",
            "concluida": "O atendimento foi concluído. Você já pode avaliar.",
        }
        record_event(db, request, recipient, target, labels[target])
        commit(db)
        db.refresh(request)
        return request_out(request)

    @app.post(
        "/requests/{request_id}/review",
        tags=["Avaliações"],
        response_model=s.ReviewOut,
        status_code=201,
        summary="Avaliar serviço concluído",
        description="Somente cliente criador. Nota inteira de 1 a 5. Uma avaliação por solicitação, somente após conclusão; duplicatas retornam 409.",
    )
    def create_review(request_id: int, body: s.ReviewInput, user: User, db: DB):
        require_role(user, "cliente")
        request = owned_request(db, request_id, user)
        if request.status != "concluida":
            raise HTTPException(409, "Somente serviços concluídos podem ser avaliados.")
        review = m.Review(request_id=request_id, **body.model_dump())
        db.add(review)
        commit(db)
        return review_out(review)

    @app.get(
        "/professionals/{professional_id}/reviews",
        tags=["Avaliações"],
        response_model=list[s.PublicReviewOut],
        summary="Listar avaliações públicas",
        description="Pública. Exibe somente primeiro nome do avaliador, nota e comentário; não expõe a solicitação, endereço ou dados de contato.",
    )
    def reviews(professional_id: int, db: DB, limit: Limit = 20, offset: Offset = 0):
        if not db.get(m.Professional, professional_id):
            raise HTTPException(404, "Profissional não encontrado.")
        stmt = (
            select(m.Review)
            .join(m.ServiceRequest)
            .where(m.ServiceRequest.professional_id == professional_id)
        )
        return [
            s.PublicReviewOut(
                id=r.id,
                client_name=r.request.client.name.split()[0],
                rating=r.rating,
                comment=r.comment,
                created_at=aware(r.created_at),
            )
            for r in db.scalars(
                stmt.order_by(m.Review.id.desc()).offset(offset).limit(limit)
            )
        ]

    @app.get(
        "/requests/{request_id}/messages",
        tags=["Mensagens"],
        response_model=list[s.MessageOut],
        summary="Consultar conversa do serviço",
        description="Somente os dois participantes. Ordem cronológica; use offset e limit para ler todo o histórico.",
    )
    def messages(
        request_id: int,
        user: User,
        db: DB,
        limit: Limit = 50,
        offset: Offset = 0,
        before_id: Annotated[int | None, Query(gt=0)] = None,
    ):
        owned_request(db, request_id, user)
        statement = select(m.Message).where(m.Message.request_id == request_id)
        if before_id is not None:
            statement = statement.where(m.Message.id < before_id)
        rows = db.scalars(
            statement.order_by(m.Message.id.desc() if before_id else m.Message.id)
            .offset(offset)
            .limit(limit)
        ).all()
        return list(reversed(rows)) if before_id else rows

    @app.post(
        "/requests/{request_id}/messages",
        tags=["Mensagens"],
        response_model=s.MessageOut,
        status_code=201,
        deprecated=True,
        summary="Enviar mensagem",
        description="Somente participantes. sender_id vem do token; corpo de 1 a 2.000 caracteres. Conversas permanecem disponíveis após encerramento.",
    )
    def send_message(request_id: int, body: s.MessageInput, user: User, db: DB):
        if production():
            raise HTTPException(
                410, "Envie mensagens pelo canal WebSocket autenticado."
            )
        owned_request(db, request_id, user)
        message = m.Message(
            request_id=request_id, sender_id=user.id, **body.model_dump()
        )
        db.add(message)
        db.flush()
        enqueue_push(db, message)
        commit(db)
        return message

    register_chat(app, sessions, [o.strip() for o in origins if o.strip()])
    original_openapi = app.openapi

    def documented_openapi():
        spec = deepcopy(original_openapi())
        example_date = (datetime.now(timezone.utc) + timedelta(days=1)).replace(
            minute=0, second=0, microsecond=0
        )
        example_start = example_date.isoformat()
        example_end = (example_date + timedelta(hours=1)).isoformat()
        availability = spec["components"]["schemas"]["AvailabilityInput"]["properties"]
        availability["starts_at"]["examples"] = [example_start]
        availability["ends_at"]["examples"] = [example_end]
        user_example = {
            "id": 1,
            "name": "Maria Souza",
            "email": "cliente@example.com",
            "phone": "84999990000",
            "role": "cliente",
        }
        request_example = {
            "id": 3,
            "client_id": 1,
            "client_name": "Maria Souza",
            "professional_id": 2,
            "professional_name": "João Silva",
            "slot_id": 5,
            "visit_fee_cents": 8000,
            "title": "Instalação de tomadas",
            "description": "Preciso instalar três tomadas na sala.",
            "address": "Rua das Flores, 123 — Natal, RN",
            "scheduled_at": example_start,
            "duration_minutes": 60,
            "status": "pendente",
            "created_at": "2026-10-07T15:00:00Z",
            "review_id": None,
        }
        pro_example = {
            "id": 2,
            "name": "João Silva",
            "category_id": 1,
            "category_name": "Eletricista",
            "bio": "Instalações e reparos elétricos.",
            "city": "Natal, RN",
            "visit_fee_cents": 8000,
            "next_available_at": example_start,
            "rating": 5.0,
            "review_count": 1,
            "is_available": True,
            "distance_km": None,
        }
        message_example = {
            "id": 3,
            "request_id": 1,
            "sender_id": 1,
            "body": "Podemos confirmar o horário?",
            "created_at": "2026-10-07T15:00:00Z",
        }
        review_example = {
            "id": 1,
            "request_id": 2,
            "client_name": "Maria Souza",
            "rating": 5,
            "comment": "Serviço realizado com capricho.",
            "created_at": "2026-10-07T15:00:00Z",
        }
        address_example = {
            "id": 1,
            "label": "Casa",
            "postal_code": "59000000",
            "street": "Rua das Flores",
            "number": "123",
            "complement": "Apto 10",
            "neighborhood": "Centro",
            "city": "Natal",
            "state": "RN",
            "is_default": True,
            "is_active": True,
        }
        notification_example = {
            "id": 3,
            "request_id": 1,
            "sender_name": "Maria Souza",
            "body": "Olá!",
            "created_at": "2026-10-07T15:00:00Z",
            "is_read": False,
        }
        slot_example = {
            "id": 5,
            "professional_id": 2,
            "starts_at": example_start,
            "ends_at": example_end,
            "is_active": True,
            "is_booked": False,
        }
        examples = {
            "/health": {"status": "ok"},
            "/auth/register": user_example,
            "/users/me": user_example,
            "/auth/login": {
                "access_token": "TOKEN_ALEATORIO",
                "token_type": "bearer",
                "expires_at": "2026-11-06T15:00:00Z",
                "user": user_example,
            },
            "/categories": [{"id": 1, "name": "Eletricista"}],
            "/professionals": [pro_example],
            "/professionals/me": pro_example,
            "/professionals/{professional_id}": pro_example,
            "/requests/{request_id}": request_example,
            "/requests/{request_id}/status": {**request_example, "status": "aceita"},
            "/requests/{request_id}/review": review_example,
            "/professionals/{professional_id}/reviews": [
                {
                    k: ("Maria" if k == "client_name" else v)
                    for k, v in review_example.items()
                    if k != "request_id"
                }
            ],
            "/users/me/addresses/{address_id}": address_example,
            "/notifications": [notification_example],
            "/users/me/notification-settings": {"push_available": True},
            "/professionals/{professional_id}/availability": [slot_example],
            "/professionals/me/availability/{slot_id}/archive": {
                **slot_example,
                "is_active": False,
            },
        }
        for path, methods in spec["paths"].items():
            for method, operation in methods.items():
                if not isinstance(operation, dict) or "responses" not in operation:
                    continue
                example = examples.get(path)
                if path == "/users/me/addresses":
                    example = [address_example] if method == "get" else address_example
                if path == "/professionals/me" and method == "get":
                    example = {
                        "category_id": 1,
                        "bio": "Instalações e reparos.",
                        "city": "Natal, RN",
                        "visit_fee_cents": 8000,
                        "is_available": True,
                        "latitude": -5.7945,
                        "longitude": -35.2110,
                    }
                if path == "/professionals/me/availability":
                    example = [slot_example] if method == "get" else slot_example
                if path == "/requests":
                    example = [request_example] if method == "get" else request_example
                if path.endswith("/messages"):
                    example = [message_example] if method == "get" else message_example
                for code, response in operation["responses"].items():
                    content = response.get("content", {}).get("application/json")
                    if (
                        content is not None
                        and code in ("200", "201")
                        and example is not None
                    ):
                        content["example"] = example
                    if content is not None and code == "422":
                        if "oneOf" not in content.get("schema", {}):
                            content["schema"] = {
                                "oneOf": [
                                    content.get("schema", {}),
                                    {"$ref": "#/components/schemas/ErrorOut"},
                                ]
                            }
                        content["example"] = {
                            "detail": [
                                {
                                    "type": "value_error",
                                    "loc": ["body", "slot_id"],
                                    "msg": "Informe um horário livre da agenda.",
                                }
                            ]
                        }
                        if path == "/users/me/password":
                            content["example"] = {
                                "detail": "Escolha uma senha diferente da atual."
                            }
                        elif path.startswith("/auth/"):
                            content["example"] = {
                                "detail": [
                                    {
                                        "type": "value_error",
                                        "loc": ["body", "email"],
                                        "msg": "Informe um email válido.",
                                    }
                                ]
                            }
                        elif "/addresses" in path:
                            content["example"] = {
                                "detail": [
                                    {
                                        "type": "string_pattern_mismatch",
                                        "loc": ["body", "postal_code"],
                                        "msg": "Informe os oito dígitos do CEP.",
                                    }
                                ]
                            }
                        elif "/availability" in path:
                            content["example"] = {
                                "detail": [
                                    {
                                        "type": "value_error",
                                        "loc": ["body", "starts_at"],
                                        "msg": "Informe data e horário futuros com fuso horário.",
                                    }
                                ]
                            }
        spec["x-websocket"] = {
            "path": "/ws/requests/{request_id}",
            "documentation": "docs/websocket.md",
            "authentication": "Primeiro frame JSON auth em até 10 segundos. Sessão de 30 dias; somente participantes.",
            "authSchema": s.SocketAuth.model_json_schema(),
            "sendSchema": s.SocketMessage.model_json_schema(),
            "events": {
                "ready": {"type": "ready", "request_id": 1},
                "message": {"type": "message", "message": message_example},
                "ack": {
                    "type": "ack",
                    "client_message_id": "a6a52b3418484d02ad9c28ff8a010601",
                    "message": message_example,
                },
                "error": {"type": "error", "status": 422, "detail": "Dados inválidos."},
            },
            "closeCodes": {
                "4401": "Sessão inválida, expirada ou revogada",
                "4403": "Sem permissão ou Origin inválido",
                "4404": "Solicitação inexistente",
            },
        }
        spec["x-websocket-notifications"] = {
            "path": "/ws/notifications",
            "documentation": "docs/perfil_notificacoes.md",
            "authentication": "Primeiro frame auth em até 10 segundos. Somente mensagens recebidas pelo usuário do token.",
            "authSchema": s.SocketAuth.model_json_schema(),
            "events": {
                "ready": {"type": "ready"},
                "notification": {
                    "type": "notification",
                    "notification": {
                        "id": 3,
                        "request_id": 1,
                        "sender_name": "Maria Souza",
                        "body": "Olá!",
                        "created_at": "2026-10-07T15:00:00Z",
                        "is_read": False,
                    },
                },
            },
            "closeCodes": {
                "4401": "Sessão inválida, expirada ou revogada",
                "4403": "Origin inválido",
            },
        }
        return spec

    app.openapi = documented_openapi
    return app


app = create_app()
