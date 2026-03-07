import os

class Settings:
    PROJECT_NAME: str = "Zero Vault API"
    
    # OTP Configuration
    # Actions that require OTP verification (comma-separated string in .env)
    # Possible values: "login", "vault_read", "vault_write", "audit_read"
    _otp_list: str = os.getenv("PERMISSIONS_OTP_LIST", "login")
    PERMISSIONS_OTP_LIST: list[str] = [x.strip() for x in _otp_list.split(",") if x.strip()]
    
    # JWT Settings
    JWT_SECRET_KEY: str = os.getenv("JWT_SECRET_KEY", "fallback_secret_key_for_development_only")
    ALGORITHM: str = os.getenv("ALGORITHM", "HS256")
    ACCESS_TOKEN_EXPIRE_MINUTES: int = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "15"))
    REFRESH_TOKEN_EXPIRE_DAYS: int = int(os.getenv("REFRESH_TOKEN_EXPIRE_DAYS", "7"))

settings = Settings()
