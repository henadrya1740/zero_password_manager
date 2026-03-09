from typing import List

from fastapi import APIRouter, Depends, Request
from slowapi import Limiter
from slowapi.util import get_remote_address
from sqlalchemy.orm import Session

from ..auth.dependencies import require_otp_for
from ..database import get_db
from ..models import User
from ..utils import attach_favicons
from .schemas import AuditResponse, HistoryResponse
from .service import get_audit_logs, get_history

router = APIRouter(tags=["audit"])
limiter = Limiter(key_func=get_remote_address)


@router.get("/audit", response_model=List[AuditResponse])
@limiter.limit("30/minute")
def read_audit_logs(
    request: Request,
    current_user: User = Depends(require_otp_for("audit_read")),
    db: Session = Depends(get_db),
):
    return get_audit_logs(db, user_id=current_user.id)


# Legacy route kept for Flutter client backward-compatibility.
# /passwords/history is the canonical route (registered in passwords/router.py).
@router.get("/password-history", response_model=List[HistoryResponse])
@limiter.limit("30/minute")
def read_password_history_legacy(
    request: Request,
    current_user: User = Depends(require_otp_for("history_read")),
    db: Session = Depends(get_db),
):
    history = get_history(db, user_id=current_user.id)
    attach_favicons(history)
    return history
