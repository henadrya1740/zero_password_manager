from ..exceptions import AppException


class FolderNotFound(AppException):
    status_code = 404
    detail = "Folder not found"
