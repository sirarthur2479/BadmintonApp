"""Shared FastAPI dependencies."""

import sqlite3
from typing import Annotated

from fastapi import Depends, HTTPException, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from . import auth
from .database import get_conn

_bearer = HTTPBearer(auto_error=False)

_UNAUTHORIZED = HTTPException(
    status_code=401,
    detail="invalid or expired token",
    headers={"WWW-Authenticate": "Bearer"},
)


def current_account(
    request: Request,
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(_bearer)],
) -> sqlite3.Row:
    """The authenticated account row; 401 for any invalid/expired/orphan token."""
    if credentials is None:
        raise _UNAUTHORIZED
    settings = request.app.state.settings
    account_id = auth.decode_token(credentials.credentials, settings)
    if account_id is None:
        raise _UNAUTHORIZED
    with get_conn(settings) as conn:
        row = conn.execute(
            "SELECT id, email FROM accounts WHERE id = ?", (account_id,)
        ).fetchone()
    if row is None:  # token outlived its account
        raise _UNAUTHORIZED
    return row
