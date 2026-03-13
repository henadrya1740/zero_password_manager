import base64
import hashlib
import hmac
import secrets
import time
from datetime import datetime, timedelta, timezone
from typing import Optional, Set, List

from jose import JWTError, jwt
from passlib.context import CryptContext
from sqlalchemy.orm import Session
from cryptography.hazmat.primitives import hashes

from .config import settings
from .models import User, IPBlock, FailedAttempt, SecurityEvent
import re
import logging


# Усиленные параметры безопасности
SECURITY_PARAMS = {
    "ARGON2": {
        "argon2__time_cost": 4,
        "argon2__memory_cost": 131072,  # 128 MB
        "argon2__parallelism": 2,
        "argon2__hash_len": 32
    },
    "HKDF": {
        "algorithm": hashes.SHA512(),
        "length": 64
    },
    "BLOCK_CLEANUP_INTERVAL": timedelta(hours=settings.BLOCK_CLEANUP_INTERVAL_HOURS),
    "DEVICE_FP_COMPONENTS": [
        "X-Forwarded-For",
        "Accept-Language",
        "Sec-CH-UA",
        "Sec-CH-UA-Platform",
        "Sec-CH-UA-Mobile",
        "User-Agent"
    ],
    "SCANNER_SIGNATURES": {
        "nikto": [r"Nikto", r"X-Nikto-Scan", r"009094c3\.asp"],
        "nmap": [r"Nmap Scripting Engine", r"\.nse", r"NMAP"],
        "owasp_zap": [r"OWASP-ZAP", r"ZAP-Header", r"Mozilla/5\.0 \(compatible; OWASP ZAP\)"],
        "wazuh": [r"Wazuh", r"wazuh-agent"],
        "sqlmap": [r"sqlmap", r"UNION\s+SELECT", r"'\s+OR\s+1=1"],
        "dirbuster": [r"DirBuster", r"DirectoryScanner"]
    },
    "WHITELIST_IPS": [
        "127.0.0.1",
        "::1"
    ]
}

BRUTE_FORCE_PROTECTION = {
    "MAX_ATTEMPTS": 4,
    "LOCKOUT_DURATION": timedelta(hours=3)
}

_pwd_context = CryptContext(
    schemes=["argon2"],
    deprecated="auto",
    **SECURITY_PARAMS["ARGON2"]
)

REQUIRED_CLAIMS: Set[str] = {"sub", "jti", "iat", "exp", "type"}


class SecurityManager:
    @staticmethod
    def hash_password(plain: str) -> str:
        return _pwd_context.hash(plain)

    @staticmethod
    def verify_password(plain: str, hashed: str) -> bool:
        return _pwd_context.verify(plain, hashed)

    @staticmethod
    def decode_token(token: str, expected_type: str | None = "access") -> dict:
        try:
            payload = jwt.decode(
                token,
                settings.JWT_SECRET_KEY,
                algorithms=[settings.ALGORITHM],
                options={"require": ["exp", "iat"]}
            )
            
            if not REQUIRED_CLAIMS.issubset(payload.keys()):
                raise ValueError("Missing required claims")
            
            if expected_type and payload.get("type") != expected_type:
                raise ValueError("Invalid token type")
            
            current_time = datetime.now(timezone.utc).timestamp()
            if payload["exp"] < current_time:
                raise ValueError("Token expired")
            
            return payload
        except (JWTError, ValueError):
            from .auth.exceptions import InvalidCredentials
            raise InvalidCredentials()

    @staticmethod
    def generate_device_id(request) -> str:
        """Robust device fingerprinting using multiple headers."""
        components = []
        for header in SECURITY_PARAMS["DEVICE_FP_COMPONENTS"]:
            value = request.headers.get(header, "")
            if isinstance(value, str):
                components.append(value.strip())
        
        raw = "|".join(components).encode()
        return hmac.new(
            settings.DEVICE_SECRET.encode(),
            raw,
            hashlib.sha256
        ).hexdigest()

    @staticmethod
    def get_client_ip(request) -> str:
        forwarded = request.headers.get("X-Forwarded-For")
        if forwarded:
            return forwarded.split(",")[0].strip()
        return request.client.host if request.client else "127.0.0.1"

    @staticmethod
    def is_scanner_request(request) -> Optional[str]:
        """Detect if the request comes from a known scanning tool."""
        try:
            # Check User-Agent
            user_agent = request.headers.get("User-Agent", "").lower()
            for scanner, patterns in SECURITY_PARAMS["SCANNER_SIGNATURES"].items():
                for pattern in patterns:
                    if re.search(pattern, user_agent, re.IGNORECASE):
                        return scanner
            
            # Check other headers
            for header, value in request.headers.items():
                for scanner, patterns in SECURITY_PARAMS["SCANNER_SIGNATURES"].items():
                    for pattern in patterns:
                        if re.search(pattern, f"{header}:{value}", re.IGNORECASE):
                            return scanner
            
            # Check query parameters
            query_params = str(request.query_params).lower()
            for scanner, patterns in SECURITY_PARAMS["SCANNER_SIGNATURES"].items():
                for pattern in patterns:
                    if re.search(pattern, query_params, re.IGNORECASE):
                        return scanner
            
            # Request body check is too heavy for middleware, skip for now unless specifically needed for POST.
            # Usually scanners identify themselves via headers first.
                        
        except Exception as e:
            logging.warning(f"Error during scanner detection: {e}")
        
        return None

    @staticmethod
    def is_ip_whitelisted(ip: str) -> bool:
        return ip in SECURITY_PARAMS["WHITELIST_IPS"]

    @staticmethod
    def is_ip_blocked(db: Session, ip: str) -> bool:
        block = db.query(IPBlock).filter(
            IPBlock.ip == ip,
            IPBlock.until > datetime.now(timezone.utc)
        ).first()
        return bool(block)

    @staticmethod
    def record_failed_attempt(db: Session, ip: str):
        attempt = db.query(FailedAttempt).filter_by(ip=ip).first()
        if not attempt:
            attempt = FailedAttempt(ip=ip, count=0)
            db.add(attempt)
        
        attempt.count += 1
        attempt.last_attempt = datetime.now(timezone.utc)
        db.commit()

    @staticmethod
    def block_ip(db: Session, ip: str, duration: timedelta, reason: str = "Unknown"):
        block = IPBlock(
            ip=ip,
            until=datetime.now(timezone.utc) + duration,
            reason=reason
        )
        db.add(block)
        db.commit()
        SecurityManager.notify_security_team("ip_blocked", {"ip": ip, "reason": reason})

    @staticmethod
    def cleanup_old_blocks(db: Session):
        """Cleanup old IP blocks and failed attempts periodically."""
        cutoff = datetime.now(timezone.utc) - BRUTE_FORCE_PROTECTION["LOCKOUT_DURATION"]
        db.query(IPBlock).filter(IPBlock.until < cutoff).delete()
        db.query(FailedAttempt).filter(FailedAttempt.last_attempt < cutoff).delete()
        db.commit()

    @staticmethod
    def verify_captcha(solution: str) -> bool:
        """Verify CAPTCHA solution (placeholder logic)."""
        # В реальной системе здесь будет проверка ключа в Redis или вызов внешнего API
        return solution == "validated_captcha_mock"

    @staticmethod
    def require_captcha(ip: str, db: Session) -> bool:
        """Determine if CAPTCHA is required based on failed attempts."""
        attempt = db.query(FailedAttempt).filter_by(ip=ip).first()
        return bool(attempt and attempt.count >= BRUTE_FORCE_PROTECTION["MAX_ATTEMPTS"] - 1)

    @staticmethod
    def notify_security_team(event_type: str, details: dict):
        """Notify security team about critical events."""
        # Реализация оповещения (лог, Telegram и т.д.)
        print(f"SECURITY NOTIFICATION [{event_type}]: {details}")

    @staticmethod
    def log_security_event(db: Session, event_type: str, details: dict, ip_address: str, user_id: Optional[int] = None):
        event = SecurityEvent(
            type=event_type,
            user_id=user_id,
            details=details,
            ip=ip_address,
            created_at=datetime.now(timezone.utc)
        )
        db.add(event)
        db.commit()

        CRITICAL_EVENTS = {"ip_blocked", "suspicious_login", "token_hijacking"}
        if event_type in CRITICAL_EVENTS:
            SecurityManager.notify_security_team(event_type, details)

    @staticmethod
    def constant_time_delay(start_time: float, min_duration: float = 0.5):
        elapsed = time.time() - start_time
        if elapsed < min_duration:
            time.sleep(min_duration - elapsed)
