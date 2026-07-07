"""Runtime configuration from environment variables."""

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    db_path: str
    jwt_secret: str
    jwt_expire_days: int = 30

    @classmethod
    def from_env(cls, dev: bool = False) -> "Settings":
        """Build settings from the environment.

        Outside dev mode a missing JWT_SECRET is a hard startup error —
        silently signing tokens with a default would be worse than crashing.
        """
        secret = os.environ.get("JWT_SECRET", "")
        if not secret:
            if not dev:
                raise RuntimeError(
                    "JWT_SECRET is not set — generate one with: "
                    "python -c \"import secrets; print(secrets.token_hex(32))\""
                )
            secret = "dev-secret-do-not-use-in-production"
        return cls(
            db_path=os.environ.get("DB_PATH", "data/badminton.db"),
            jwt_secret=secret,
            jwt_expire_days=int(os.environ.get("JWT_EXPIRE_DAYS", "30")),
        )
