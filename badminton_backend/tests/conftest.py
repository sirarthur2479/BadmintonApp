import pytest
from fastapi.testclient import TestClient

from app.main import create_app
from app.settings import Settings


@pytest.fixture()
def settings(tmp_path) -> Settings:
    return Settings(
        db_path=str(tmp_path / "test.db"),
        jwt_secret="test-secret",
        upload_dir=str(tmp_path / "uploads"),
    )


@pytest.fixture()
def client(settings) -> TestClient:
    # Context-managed so every request shares one event loop (as in
    # production) — asyncio primitives in handlers deadlock across the
    # per-request loops TestClient otherwise creates — and so lifespan
    # startup/shutdown hooks run.
    with TestClient(create_app(settings)) as c:
        yield c


def register_and_login(
    client: TestClient, email: str = "parent@example.com", password: str = "hunter22"
) -> dict:
    """Returns Authorization headers for a fresh account."""
    client.post("/api/v1/auth/register", json={"email": email, "password": password})
    resp = client.post(
        "/api/v1/auth/login", json={"email": email, "password": password}
    )
    token = resp.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture()
def auth_headers(client) -> dict:
    return register_and_login(client)
