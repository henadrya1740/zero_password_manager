from typing import Optional

from sqlalchemy.orm import Session

from ..models import Audit, PasswordHistory


def record(
    db: Session,
    user_id: int,
    event: str,
    meta: Optional[dict] = None,
    ip: Optional[str] = None,
) -> None:
    """Append an immutable audit record. Called by every domain that mutates state."""
    db.add(Audit(user_id=user_id, event=event, meta=meta or {}, ip_address=ip))
    db.commit()


def get_audit_logs(db: Session, user_id: int) -> list[Audit]:
    return (
        db.query(Audit)
        .filter(Audit.user_id == user_id)
        .order_by(Audit.created_at.desc())
        .limit(100)
        .all()
    )


def get_history(db: Session, user_id: int) -> list[PasswordHistory]:
    record(db, user_id, "history_read")
    return (
        db.query(PasswordHistory)
        .filter(PasswordHistory.user_id == user_id)
        .order_by(PasswordHistory.created_at.desc())
        .all()
    )
