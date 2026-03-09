import logging

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address

from .audit.router import router as audit_router
from .auth.router import router as auth_router
from .config import settings
from .database import engine
from .exceptions import AppException, app_exception_handler
from .folders.router import router as folders_router
from .models import Base
from .passwords.router import router as passwords_router

logger = logging.getLogger(__name__)

# ── Database ──────────────────────────────────────────────────────────────────

Base.metadata.create_all(bind=engine)

# ── Application ───────────────────────────────────────────────────────────────

app = FastAPI(title="Zero Vault API")

# ── Rate limiter ──────────────────────────────────────────────────────────────

limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# ── Global exception handler ──────────────────────────────────────────────────
# Converts every AppException subclass to a JSON HTTP response.
# Service and dependency layers raise domain exceptions; they never import HTTPException.

app.add_exception_handler(AppException, app_exception_handler)

# ── CORS ──────────────────────────────────────────────────────────────────────
# Wildcard origins are intentionally forbidden.
# Configure ALLOWED_ORIGINS=http://your-host in .env.

if not settings.ALLOWED_ORIGINS:
    logger.warning(
        "[SECURITY] ALLOWED_ORIGINS is not set — cross-origin requests will be blocked. "
        "Set ALLOWED_ORIGINS=http://your-host in .env."
    )

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["Authorization", "Content-Type", "X-OTP"],
)

# ── Security headers ──────────────────────────────────────────────────────────

@app.middleware("http")
async def add_security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Frame-Options"]           = "DENY"
    response.headers["X-Content-Type-Options"]    = "nosniff"
    response.headers["Strict-Transport-Security"] = "max-age=63072000; includeSubDomains"
    response.headers["Referrer-Policy"]           = "no-referrer"
    response.headers["Permissions-Policy"]        = "camera=(), microphone=(), geolocation=()"
    response.headers["Content-Security-Policy"]   = (
        "default-src 'none'; script-src 'none'; object-src 'none';"
    )
    return response

# ── Routers ───────────────────────────────────────────────────────────────────

app.include_router(auth_router)
app.include_router(passwords_router)
app.include_router(folders_router)
app.include_router(audit_router)

# ── Health ────────────────────────────────────────────────────────────────────

@app.get("/health", tags=["system"])
def health():
    return {"status": "ok", "architecture": "zero-knowledge", "2fa": "enabled"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("server.main:app", host="0.0.0.0", port=3000, reload=False)
