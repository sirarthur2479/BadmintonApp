"""Password hashing and JWT tokens.

Stack per research/fastapi-auth.md (2026-07-06): PyJWT (HS256, str sub,
explicit algorithm allowlist on decode) + pwdlib Argon2id. python-jose and
passlib are banned (critical CVE / unmaintained).
"""

from datetime import datetime, timedelta, timezone

import jwt  # PyJWT
from pwdlib import PasswordHash

from .settings import Settings

_password_hash = PasswordHash.recommended()  # Argon2id


def hash_password(plain: str) -> str:
    return _password_hash.hash(plain)


def verify_password(plain: str, hashed: str) -> bool:
    return _password_hash.verify(plain, hashed)


def create_access_token(account_id: str, settings: Settings) -> str:
    payload = {
        "sub": str(account_id),  # PyJWT >=2.10 requires a string sub
        "exp": datetime.now(timezone.utc)
        + timedelta(days=settings.jwt_expire_days),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm="HS256")


def decode_token(token: str, settings: Settings) -> str | None:
    """The accountId in a valid token, else None (expired counts as invalid)."""
    try:
        payload = jwt.decode(
            token, settings.jwt_secret, algorithms=["HS256"]  # explicit allowlist
        )
        return payload["sub"]
    except jwt.InvalidTokenError:
        return None
