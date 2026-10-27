"""I/O do banco em threads, sessões curtas e autenticação revalidada por ciclo."""

import asyncio
import hashlib
import secrets
import anyio
from datetime import datetime, timedelta, timezone

from fastapi import HTTPException, WebSocket, WebSocketDisconnect
from pydantic import ValidationError
from sqlalchemy import func, select, update
from sqlalchemy.exc import IntegrityError

from .configuration import secure_transport
from .models import (
    AuthToken,
    Message,
    MessageReceipt,
    RequestEvent,
    ServiceRequest,
    SocketLease,
    User,
)
from .push import enqueue_push
from .request_events import event_out
from .schemas import MessageOut, SocketAuth, SocketMessage
from .security_controls import resource_limit


class SocketAccessError(Exception):
    def __init__(self, code):
        self.code = code


def aware(value):
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value


def authorized(db, digest, request_id=None):
    token = db.get(AuthToken, digest)
    if (
        not token
        or token.revoked_at
        or aware(token.expires_at) <= datetime.now(timezone.utc)
    ):
        raise SocketAccessError(4401)
    user = db.get(User, token.user_id)
    if not user or not user.is_active:
        raise SocketAccessError(4401)
    if request_id is not None:
        request = db.get(ServiceRequest, request_id)
        if not request:
            raise SocketAccessError(4404)
        if user.id not in (request.client_id, request.professional_id):
            raise SocketAccessError(4403)
    return user.id


def acquire(sessions, digest, request_id, lease_id):
    with sessions.begin() as db:
        user_id = authorized(db, digest, request_id)
        db.execute(update(User).where(User.id == user_id).values(phone=User.phone))
        count = db.scalar(
            select(func.count())
            .select_from(SocketLease)
            .where(
                SocketLease.user_id == user_id,
                SocketLease.expires_at > datetime.now(timezone.utc),
            )
        )
        if count >= 6:
            raise SocketAccessError(4429)
        db.add(
            SocketLease(
                id=lease_id,
                user_id=user_id,
                expires_at=datetime.now(timezone.utc) + timedelta(seconds=90),
            )
        )


def renew(sessions, lease_id):
    with sessions.begin() as db:
        db.execute(
            update(SocketLease)
            .where(SocketLease.id == lease_id)
            .values(expires_at=datetime.now(timezone.utc) + timedelta(seconds=90))
        )


def release(sessions, lease_id):
    with sessions.begin() as db:
        db.execute(
            update(SocketLease)
            .where(SocketLease.id == lease_id)
            .values(expires_at=datetime.now(timezone.utc))
        )


def fetch(sessions, digest, request_id, cursor, event_cursor):
    with sessions() as db:
        user_id = authorized(db, digest, request_id)
        if request_id is not None:
            statement = select(Message).where(
                Message.request_id == request_id, Message.id > cursor
            )
            rows = db.scalars(
                statement.order_by(
                    Message.id.desc() if cursor == 0 else Message.id
                ).limit(50 if cursor == 0 else 100)
            ).all()
            if cursor == 0:
                rows.reverse()
            return [
                MessageOut.model_validate(row).model_dump(mode="json") for row in rows
            ], []
        rows = db.execute(
            select(Message, User.name, MessageReceipt.read_at)
            .join(ServiceRequest, ServiceRequest.id == Message.request_id)
            .join(User, User.id == Message.sender_id)
            .outerjoin(
                MessageReceipt,
                (MessageReceipt.message_id == Message.id)
                & (MessageReceipt.user_id == user_id),
            )
            .where(
                (ServiceRequest.client_id == user_id)
                | (ServiceRequest.professional_id == user_id)
            )
            .where(Message.sender_id != user_id, Message.id > cursor)
            .order_by(Message.id)
            .limit(100)
        ).all()
        frames = [
            {
                "id": msg.id,
                "request_id": msg.request_id,
                "sender_name": name,
                "body": msg.body,
                "created_at": aware(msg.created_at).isoformat(),
                "is_read": read is not None,
            }
            for msg, name, read in rows
        ]
        events = db.scalars(
            select(RequestEvent)
            .where(RequestEvent.user_id == user_id, RequestEvent.id > event_cursor)
            .order_by(RequestEvent.id)
            .limit(100)
        )
        return frames, [event_out(event) for event in events]


def persist(sessions, digest, request_id, body):
    with sessions() as db:
        user_id = authorized(db, digest, request_id)
    resource_limit(sessions.kw["bind"], "chat:messages", user_id, 30, 60)
    with sessions() as db:
        user_id = authorized(db, digest, request_id)
        statement = select(Message).where(
            Message.sender_id == user_id,
            Message.client_message_id == body.client_message_id,
        )
        existing = db.scalar(statement)
        if not existing:
            existing = Message(
                request_id=request_id,
                sender_id=user_id,
                body=body.body,
                client_message_id=body.client_message_id,
            )
            db.add(existing)
            try:
                db.flush()
                enqueue_push(db, existing)
                db.commit()
            except IntegrityError:
                db.rollback()
                existing = db.scalar(statement)
        if (
            not existing
            or existing.request_id != request_id
            or existing.body != body.body
        ):
            raise HTTPException(409, "Identificador já usado para outra mensagem.")
        return MessageOut.model_validate(existing).model_dump(mode="json")


def register_chat(app, sessions, origins):
    async def handle(socket, request_id=None):
        if secure_transport() and socket.url.scheme != "wss":
            await socket.close(code=4403, reason="Conexão segura WSS obrigatória.")
            return
        origin = socket.headers.get("origin")
        if origin and origin not in origins:
            await socket.close(code=4403)
            return
        lease_id = None
        try:
            address = socket.client.host if socket.client else "unknown"
            await asyncio.to_thread(
                resource_limit, sessions.kw["bind"], "socket:connect", address, 600, 60
            )
            await socket.accept()
            raw = await asyncio.wait_for(socket.receive_text(), timeout=10)
            if len(raw) > 4000:
                raise SocketAccessError(4401)
            auth = SocketAuth.model_validate_json(raw)
            digest = hashlib.sha256(auth.token.encode()).hexdigest()
            lease_id = secrets.token_hex(16)
            await asyncio.to_thread(acquire, sessions, digest, request_id, lease_id)
            cursor, event_cursor, ready = auth.after, auth.events_after, False
            renewed = asyncio.get_running_loop().time()
            while True:
                frames, events = await asyncio.to_thread(
                    fetch, sessions, digest, request_id, cursor, event_cursor
                )
                for frame in frames:
                    await socket.send_json(
                        {
                            "type": (
                                "message" if request_id is not None else "notification"
                            ),
                            (
                                "message" if request_id is not None else "notification"
                            ): frame,
                        }
                    )
                    cursor = frame["id"]
                for event in events:
                    await socket.send_json({"type": "request_event", "event": event})
                    event_cursor = event["id"]
                if asyncio.get_running_loop().time() - renewed >= 30:
                    await asyncio.to_thread(renew, sessions, lease_id)
                    renewed = asyncio.get_running_loop().time()
                if len(frames) == 100 or len(events) == 100:
                    continue
                if not ready:
                    await socket.send_json(
                        {
                            "type": "ready",
                            **(
                                {"has_older": len(frames) == 50}
                                if request_id is not None and auth.after == 0
                                else {}
                            ),
                            **({"request_id": request_id} if request_id else {}),
                        }
                    )
                    ready = True
                try:
                    raw = await asyncio.wait_for(socket.receive_text(), timeout=1)
                except asyncio.TimeoutError:
                    continue
                except (KeyError, TypeError):
                    await socket.send_json(
                        {
                            "type": "error",
                            "status": 422,
                            "detail": "Use frames de texto JSON.",
                        }
                    )
                    continue
                if request_id is None:
                    await socket.close(code=4400)
                    return
                if len(raw) > 16000:
                    await socket.send_json(
                        {
                            "type": "error",
                            "status": 422,
                            "detail": "Mensagem muito grande.",
                        }
                    )
                    continue
                try:
                    body = SocketMessage.model_validate_json(raw)
                    message = await asyncio.to_thread(
                        persist, sessions, digest, request_id, body
                    )
                    await socket.send_json(
                        {
                            "type": "ack",
                            "client_message_id": body.client_message_id,
                            "message": message,
                        }
                    )
                except ValidationError:
                    await socket.send_json(
                        {
                            "type": "error",
                            "status": 422,
                            "detail": "Informe body (1 a 2.000 caracteres) e client_message_id (16 a 64 caracteres).",
                        }
                    )
                except HTTPException as error:
                    await socket.send_json(
                        {
                            "type": "error",
                            "status": error.status_code,
                            "detail": error.detail,
                        }
                    )
        except SocketAccessError as error:
            await socket.close(code=error.code)
        except HTTPException:
            await socket.close(code=4429)
        except (ValidationError, asyncio.TimeoutError, KeyError, TypeError):
            await socket.close(code=4401)
        except WebSocketDisconnect:
            pass
        finally:
            if lease_id:
                with anyio.CancelScope(shield=True):
                    await anyio.to_thread.run_sync(release, sessions, lease_id)

    @app.websocket("/ws/requests/{request_id}")
    async def chat(socket: WebSocket, request_id: int):
        await handle(socket, request_id)

    @app.websocket("/ws/notifications")
    async def notifications(socket: WebSocket):
        await handle(socket)
