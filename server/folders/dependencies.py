from fastapi import Depends
from sqlalchemy.orm import Session

from ..auth.dependencies import get_current_user
from ..database import get_db
from ..models import Folder, User
from .exceptions import FolderNotFound
from .service import get_folder_by_id


def valid_folder(
    folder_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Folder:
    """
    Resolve a folder_id path parameter to a Folder row, verifying ownership.

    Used by PUT /folders/{folder_id} and DELETE /folders/{folder_id}.
    """
    folder = get_folder_by_id(db, folder_id, current_user.id)
    if not folder:
        raise FolderNotFound()
    return folder
