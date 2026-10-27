"""Limite de corpo e log estruturado sem query strings, tokens ou conteúdo."""

import asyncio
import json
import logging
import time
import uuid

from starlette.responses import JSONResponse

logger = logging.getLogger("ze_resolve.http")
if not logger.handlers:
    handler = logging.StreamHandler()
    handler.setFormatter(logging.Formatter("%(message)s"))
    logger.addHandler(handler)
logger.setLevel(logging.INFO)
logger.propagate = False


class HttpControls:
    def __init__(self, app, max_bytes=65536):
        self.app, self.max_bytes = app, max_bytes

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return
        body = bytearray()
        try:
            while True:
                message = await asyncio.wait_for(receive(), timeout=15)
                if message["type"] == "http.disconnect":
                    return
                body.extend(message.get("body", b""))
                if len(body) > self.max_bytes:
                    await JSONResponse(
                        {"detail": "Solicitação muito grande."}, status_code=413
                    )(scope, receive, send)
                    return
                if not message.get("more_body", False):
                    break
        except asyncio.TimeoutError:
            await JSONResponse({"detail": "Tempo de envio excedido."}, status_code=408)(
                scope, receive, send
            )
            return
        consumed = False

        async def buffered_receive():
            nonlocal consumed
            if not consumed:
                consumed = True
                return {"type": "http.request", "body": bytes(body), "more_body": False}
            return await receive()

        request_id, started, status = uuid.uuid4().hex, time.monotonic(), 500

        async def response_send(message):
            nonlocal status
            if message["type"] == "http.response.start":
                status = message["status"]
                message.setdefault("headers", []).append(
                    (b"x-request-id", request_id.encode("ascii"))
                )
            await send(message)

        try:
            await self.app(scope, buffered_receive, response_send)
        finally:
            logger.info(
                json.dumps(
                    {
                        "request_id": request_id,
                        "method": scope["method"],
                        "path": scope["path"],
                        "status": status,
                        "duration_ms": round((time.monotonic() - started) * 1000, 2),
                    }
                )
            )
