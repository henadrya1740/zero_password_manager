from fastapi import Depends
from sqlalchemy.orm import Session

from ..auth.dependencies import get_current_user
from ..database import get_db
from ..models import Password, User
from .exceptions import PasswordNotFound
from .service import get_password_by_id


def valid_password(
    password_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Password:
    """
    Resolve a password_id path parameter to a Password row, verifying ownership.

    Used by PUT /passwords/{password_id} and DELETE /passwords/{password_id}
    so the routes themselves never need to repeat the fetch + 404 check.
    """
    pw = get_password_by_id(db, password_id, current_user.id)
    if not pw:
        raise PasswordNotFound()
    return pw
