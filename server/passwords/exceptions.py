from ..exceptions import AppException


class PasswordNotFound(AppException):
    status_code = 404
    detail = "Password not found"


class PayloadTooLarge(AppException):
    status_code = 400
    detail = "Encrypted payload exceeds the 2 MB limit"
