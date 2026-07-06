import sqlite3
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException, Request

from .. import auth
from ..database import get_conn
from ..models import AccountOut, Credentials, TokenOut

router = APIRouter(prefix="/auth", tags=["auth"])

# Identical body for wrong-password and unknown-email: no account enumeration.
_BAD_LOGIN = HTTPException(status_code=401, detail="invalid email or password")


@router.post("/register", status_code=201, response_model=AccountOut)
def register(creds: Credentials, request: Request) -> AccountOut:
    settings = request.app.state.settings
    account_id = str(uuid.uuid4())
    try:
        with get_conn(settings) as conn:
            conn.execute(
                "INSERT INTO accounts (id, email, password_hash, created_at) "
                "VALUES (?, ?, ?, ?)",
                (
                    account_id,
                    creds.email,
                    auth.hash_password(creds.password),
                    datetime.now(timezone.utc).isoformat(),
                ),
            )
    except sqlite3.IntegrityError:
        raise HTTPException(status_code=409, detail="email already registered")
    return AccountOut(id=account_id, email=creds.email)


@router.post("/login", response_model=TokenOut)
def login(creds: Credentials, request: Request) -> TokenOut:
    settings = request.app.state.settings
    with get_conn(settings) as conn:
        row = conn.execute(
            "SELECT id, password_hash FROM accounts WHERE email = ?",
            (creds.email,),
        ).fetchone()
    if row is None or not auth.verify_password(creds.password, row["password_hash"]):
        raise _BAD_LOGIN
    return TokenOut(access_token=auth.create_access_token(row["id"], settings))
