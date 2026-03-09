from fastapi import Request
from fastapi.responses import JSONResponse


class AppException(Exception):
    """
    Base class for all application-level exceptions.

    Subclasses declare status_code, detail, and optional headers as class
    attributes. A single global handler in main.py converts every AppException
    to a JSON HTTP response, so service and dependency layers never need to
    import HTTPException directly.
    """
    status_code: int = 500
    detail: str = "Internal server error"
    headers: dict | None = None


async def app_exception_handler(request: Request, exc: AppException) -> JSONResponse:
    return JSONResponse(
        status_code=exc.status_code,
        content={"detail": exc.detail},
        headers=exc.headers,
    )
