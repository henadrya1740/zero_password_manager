from datetime import datetime
from typing import Any, Dict, Optional

from pydantic import BaseModel


class HistoryResponse(BaseModel):
    id: int
    action_type: str
    action_details: Dict[str, Any]
    site_url: str
    favicon_url: Optional[str] = None
    created_at: datetime

    model_config = {"from_attributes": True}


class AuditResponse(BaseModel):
    id: int
    event: str
    meta: Dict[str, Any]
    created_at: datetime

    model_config = {"from_attributes": True}
