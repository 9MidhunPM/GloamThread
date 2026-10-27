"""Same-origin, invitation-protected authoring API. Never holds provider keys."""
from __future__ import annotations

from contextlib import asynccontextmanager
import os
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

from tools.forge.provider import ForgeError
from .service import ForgeService, MAX_BODY_BYTES, parse_json
from .store import ServiceError, Store

COOKIE = "gloamthread_forge"


def create_app(data_root: Path | str | None = None, *, public_origin: str | None = None,
               secure_cookies: bool = True) -> FastAPI:
    root = data_root if data_root is not None else os.environ.get("FORGE_DATA_ROOT", "/data/forge")
    origin = (public_origin or os.environ.get("FORGE_PUBLIC_ORIGIN", "https://gloamthread.midhunpm.in")).rstrip("/")

    @asynccontextmanager
    async def lifespan(application):
        application.state.service = ForgeService(Store(root))
        yield

    application = FastAPI(title="Gloamthread Forge", docs_url=None, redoc_url=None,
                          openapi_url=None, lifespan=lifespan)

    @application.middleware("http")
    async def boundary(request: Request, call_next):
        if request.method not in {"GET", "HEAD", "OPTIONS"}:
            supplied = request.headers.get("origin")
            if (supplied is not None and supplied.rstrip("/") != origin
                    or request.headers.get("sec-fetch-site") == "cross-site"
                    or supplied is None and request.headers.get("x-gloamthread-request") != "1"):
                return JSONResponse({"ok": False, "error": "Use the forge from this game's website."}, status_code=403)
        length = request.headers.get("content-length")
        if length is not None and (not length.isdigit() or int(length) > MAX_BODY_BYTES):
            return JSONResponse({"ok": False, "error": "Request exceeds the upload limit."}, status_code=413)
        response = await call_next(request)
        response.headers["Cache-Control"] = "no-store"
        response.headers["X-Content-Type-Options"] = "nosniff"
        return response

    @application.exception_handler(ServiceError)
    async def service_error(_request, error):
        return JSONResponse({"ok": False, "error": str(error)}, status_code=error.status)

    @application.exception_handler(ForgeError)
    async def forge_error(request, error):
        service = request.app.state.service
        return JSONResponse({"ok": False, "error": service.safe_message(str(error))}, status_code=400)

    async def body(request: Request) -> dict:
        data = bytearray()
        async for chunk in request.stream():
            data.extend(chunk)
            if len(data) > MAX_BODY_BYTES:
                raise ServiceError("Request exceeds the upload limit.", 413)
        return parse_json(bytes(data))

    def service(request: Request) -> ForgeService:
        return request.app.state.service

    def owner(request: Request) -> str:
        return service(request).store.owner_for_session(request.cookies.get(COOKIE))

    @application.get("/healthz")
    async def health(request: Request):
        with service(request).store.connect() as db:
            db.execute("SELECT 1").fetchone()
        return {"ok": True}

    @application.post("/api/forge/session")
    async def login(request: Request):
        value = await body(request)
        if set(value) != {"code"}:
            raise ServiceError("Supply only an invitation code.")
        token = service(request).store.login(value["code"], request.client.host if request.client else "unknown")
        response = JSONResponse({"ok": True, "authenticated": True})
        response.set_cookie(COOKIE, token, max_age=30 * 86400, httponly=True,
                            secure=secure_cookies, samesite="strict", path="/api/forge")
        return response

    @application.delete("/api/forge/session")
    async def logout(request: Request):
        service(request).store.logout(request.cookies.get(COOKIE))
        response = JSONResponse({"ok": True})
        response.delete_cookie(COOKIE, path="/api/forge", secure=secure_cookies,
                               httponly=True, samesite="strict")
        return response

    @application.get("/api/forge/configuration")
    async def configuration(request: Request):
        principal = None
        try:
            principal = owner(request)
        except ServiceError:
            pass
        return service(request).configuration(principal)

    @application.post("/api/forge/jobs", status_code=201)
    async def create_job(request: Request):
        principal = owner(request)
        return service(request).create_job(principal, await body(request))

    @application.get("/api/forge/jobs")
    async def list_jobs(request: Request):
        principal = owner(request)
        result = []
        for job in service(request).store.list_jobs(principal):
            status = service(request).status(principal, job["job_id"])
            result.append({**status, "created_at": job["created_at"]})
        return {"ok": True, "jobs": result}

    @application.post("/api/forge/jobs/{job_id}/operations", status_code=202)
    async def operation(job_id: str, request: Request):
        principal = owner(request)
        return service(request).enqueue(principal, job_id, await body(request))

    @application.get("/api/forge/jobs/{job_id}")
    async def status(job_id: str, request: Request):
        return service(request).status(owner(request), job_id)

    @application.get("/api/forge/jobs/{job_id}/snapshot")
    async def snapshot(job_id: str, request: Request):
        return service(request).snapshot(owner(request), job_id)

    @application.post("/api/forge/jobs/{job_id}/cancel")
    async def cancel(job_id: str, request: Request):
        principal = owner(request)
        service(request).store.cancel(principal, job_id)
        return {"ok": True, "message": "Cancellation requested. An in-flight provider request may still be billed."}

    return application


app = create_app()
