import urllib.parse
from typing import Optional

from fastapi import Request


def get_client_ip(request: Request) -> str:
    """Return the real client IP, respecting X-Forwarded-For from trusted proxies."""
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


def get_favicon_url(site_url: Optional[str]) -> Optional[str]:
    """Return a Clearbit logo URL for a domain, or None if the URL is unusable."""
    if not site_url:
        return None
    try:
        if not site_url.startswith(("http://", "https://")):
            site_url = "https://" + site_url
        parsed = urllib.parse.urlparse(site_url)
        domain = parsed.netloc.lower() or parsed.path.split("/")[0].lower()
        domain = domain.removeprefix("www.")
        if not domain or "." not in domain:
            return None
        return f"https://logo.clearbit.com/{domain}?size=128"
    except Exception:
        return None


def attach_favicons(entries: list) -> None:
    """Attach a transient favicon_url to each item in a list of password-like objects."""
    for entry in entries:
        entry.favicon_url = get_favicon_url(entry.site_url)
