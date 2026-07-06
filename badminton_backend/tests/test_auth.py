import sqlite3

from tests.conftest import register_and_login


def test_register_creates_account_and_returns_no_hash(client):
    resp = client.post(
        "/api/v1/auth/register",
        json={"email": "parent@example.com", "password": "hunter22"},
    )

    assert resp.status_code == 201
    body = resp.json()
    assert body["email"] == "parent@example.com"
    assert "id" in body
    assert "password" not in str(body) and "hash" not in str(body)


def test_register_duplicate_email_409(client):
    payload = {"email": "parent@example.com", "password": "hunter22"}
    client.post("/api/v1/auth/register", json=payload)

    resp = client.post("/api/v1/auth/register", json=payload)

    assert resp.status_code == 409


def test_register_rejects_blank_fields(client):
    assert (
        client.post(
            "/api/v1/auth/register", json={"email": "", "password": "hunter22"}
        ).status_code
        == 422
    )
    assert (
        client.post(
            "/api/v1/auth/register",
            json={"email": "a@b.c", "password": ""},
        ).status_code
        == 422
    )


def test_login_returns_bearer_token(client):
    client.post(
        "/api/v1/auth/register",
        json={"email": "parent@example.com", "password": "hunter22"},
    )

    resp = client.post(
        "/api/v1/auth/login",
        json={"email": "parent@example.com", "password": "hunter22"},
    )

    assert resp.status_code == 200
    body = resp.json()
    assert body["token_type"] == "bearer"
    assert body["access_token"].count(".") == 2  # JWT shape


def test_login_wrong_password_and_unknown_email_same_401(client):
    client.post(
        "/api/v1/auth/register",
        json={"email": "parent@example.com", "password": "hunter22"},
    )

    wrong_pw = client.post(
        "/api/v1/auth/login",
        json={"email": "parent@example.com", "password": "nope"},
    )
    unknown = client.post(
        "/api/v1/auth/login",
        json={"email": "ghost@example.com", "password": "nope"},
    )

    assert wrong_pw.status_code == unknown.status_code == 401
    assert wrong_pw.json() == unknown.json(), "no account enumeration"


def test_password_stored_as_argon2_hash_not_plaintext(client, settings):
    client.post(
        "/api/v1/auth/register",
        json={"email": "parent@example.com", "password": "hunter22"},
    )

    conn = sqlite3.connect(settings.db_path)
    stored = conn.execute("SELECT password_hash FROM accounts").fetchone()[0]
    conn.close()

    assert "hunter22" not in stored
    assert stored.startswith("$argon2")


def test_register_and_login_flow_helper(client):
    headers = register_and_login(client)

    assert headers["Authorization"].startswith("Bearer ")


def test_me_with_valid_token_returns_account_id(client, auth_headers):
    resp = client.get("/api/v1/me", headers=auth_headers)

    assert resp.status_code == 200
    assert resp.json()["email"] == "parent@example.com"
    assert resp.json()["id"]


def test_me_rejects_missing_garbage_and_expired_tokens(client, settings):
    from datetime import datetime, timedelta, timezone

    import jwt

    assert client.get("/api/v1/me").status_code == 401
    assert (
        client.get(
            "/api/v1/me", headers={"Authorization": "Bearer not.a.jwt"}
        ).status_code
        == 401
    )
    expired = jwt.encode(
        {
            "sub": "someone",
            "exp": datetime.now(timezone.utc) - timedelta(hours=1),
        },
        settings.jwt_secret,
        algorithm="HS256",
    )
    assert (
        client.get(
            "/api/v1/me", headers={"Authorization": f"Bearer {expired}"}
        ).status_code
        == 401
    )


def test_me_rejects_token_signed_with_wrong_secret(client):
    import jwt

    forged = jwt.encode({"sub": "x"}, "wrong-secret", algorithm="HS256")

    assert (
        client.get(
            "/api/v1/me", headers={"Authorization": f"Bearer {forged}"}
        ).status_code
        == 401
    )


def test_me_rejects_token_for_deleted_account(client, settings, auth_headers):
    import sqlite3

    conn = sqlite3.connect(settings.db_path)
    conn.execute("DELETE FROM accounts")
    conn.commit()
    conn.close()

    assert client.get("/api/v1/me", headers=auth_headers).status_code == 401
