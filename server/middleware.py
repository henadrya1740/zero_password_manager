import logging
from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware
from sqlalchemy.orm import Session
from datetime import timedelta

from .database import SessionLocal
from .security import SecurityManager
from .utils import get_client_ip

logger = logging.getLogger("zero_vault.security")

class SecurityMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        client_ip = SecurityManager.get_client_ip(request)
        
        # 1. Whitelist check
        if SecurityManager.is_ip_whitelisted(client_ip):
            return await call_next(request)
        
        # 2. Block check (against IPBlock table)
        # We need a DB session here. Using SessionLocal directly as it's middleware.
        db: Session = SessionLocal()
        try:
            if SecurityManager.is_ip_blocked(db, client_ip):
                logger.warning(f"Access denied for blocked IP: {client_ip}")
                return Response(content="Access denied", status_code=403)
            
            # 3. Scanner detection
            scanner_type = SecurityManager.is_scanner_request(request)
            if scanner_type:
                logger.critical(f"Scanner detected! Type: {scanner_type}, IP: {client_ip}, Path: {request.url.path}")
                
                # Log the event
                SecurityManager.log_security_event(
                    db, 
                    "scanner_detected", 
                    {
                        "scanner": scanner_type,
                        "path": request.url.path,
                        "method": request.method,
                        "headers": dict(request.headers.items())
                    }, 
                    client_ip
                )
                
                # Block the IP for 24 hours
                SecurityManager.block_ip(db, client_ip, timedelta(hours=24), reason=f"Scanner Detected ({scanner_type})")
                
                return Response(content="Access denied", status_code=403)
                
        finally:
            db.close()
            
        return await call_next(request)

class ProxyHeadersMiddleware(BaseHTTPMiddleware):
    """
    Middleware to handle Trusted Proxies.
    Prevents IP spoofing by validating X-Forwarded-For headers.
    """
    async def dispatch(self, request: Request, call_next):
        # List of trusted proxies (e.g., local nginx, docker network, or Cloudflare IPs)
        # In a real production environment, this should be moved to settings.
        trusted_proxies = {"127.0.0.1", "::1", "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"}
        
        forwarded_for = request.headers.get("x-forwarded-for")
        if forwarded_for:
            # The client IP is the first entry in X-Forwarded-For
            client_ip = forwarded_for.split(",")[0].strip()
            
            # Verify if the immediate requester IP is a trusted proxy
            # If request.client is None (e.g. test client), we might skip or assume trusted in dev
            requester_ip = request.client.host if request.client else "127.0.0.1"
            
            if requester_ip in trusted_proxies:
                # Rewrite the client in scope so request.client.host returns the real client IP
                request.scope["client"] = (client_ip, request.client.port if request.client else 0)
            else:
                logger.warning(f"Untrusted proxy header detected from {requester_ip}. Header ignored.")
                
        return await call_next(request)
