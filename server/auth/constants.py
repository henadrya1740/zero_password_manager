# Argon2id parameters — OWASP recommended minimums (2024)
ARGON2_TIME_COST   = 3
ARGON2_MEMORY_COST = 65_536  # 64 MB
ARGON2_PARALLELISM = 1
ARGON2_HASH_LEN    = 32

# AES-256-GCM
AES_NONCE_LEN = 12  # 96-bit nonce

# ── Security Constants ────────────────────────────────────────────────────────

MAX_EXECUTION_TIME = 2.0  # seconds
MAX_FAILED_OTP_ATTEMPTS = 5
LOCKOUT_TIME_MINUTES = 15
