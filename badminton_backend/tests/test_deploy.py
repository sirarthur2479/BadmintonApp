from pathlib import Path

import yaml

BACKEND = Path(__file__).parent.parent
DEPLOY = BACKEND / "deploy"


def compose() -> dict:
    return yaml.safe_load((DEPLOY / "docker-compose.yml").read_text())


def test_compose_defines_backend_and_web_services():
    services = compose()["services"]

    assert set(services) == {"backend", "web"}
    assert services["web"]["image"].startswith("nginx")
    assert services["web"]["ports"] == ["80:80"]
    assert "backend" in services["web"]["depends_on"]


def test_compose_backend_mounts_data_volume_and_env():
    backend = compose()["services"]["backend"]

    assert "./data:/data" in backend["volumes"]
    env = backend["environment"]
    env_text = " ".join(env) if isinstance(env, list) else str(env)
    assert "JWT_SECRET" in env_text
    assert "DB_PATH" in env_text
    assert backend["restart"] == "unless-stopped"


def test_nginx_conf_proxies_api_and_falls_back_to_index():
    conf = (DEPLOY / "nginx" / "nginx.conf").read_text()

    assert "location /api/" in conf
    assert "proxy_pass http://backend:8000" in conf
    assert "try_files $uri $uri/ /index.html" in conf


def test_dockerfile_runs_uvicorn_factory_on_8000():
    dockerfile = (BACKEND / "Dockerfile").read_text()

    assert "python:3.12-slim" in dockerfile
    assert "app.main:create_app" in dockerfile
    assert "--factory" in dockerfile
    assert "8000" in dockerfile


def test_env_example_has_placeholder_secret_only():
    env = (DEPLOY / ".env.example").read_text()

    assert "JWT_SECRET=" in env
    assert "secrets.token_hex" in env, "must document how to generate one"
    # No plausible real secret committed: the value must be an obvious
    # placeholder.
    secret_line = next(
        line for line in env.splitlines() if line.startswith("JWT_SECRET=")
    )
    value = secret_line.split("=", 1)[1]
    assert value in ("", "change-me") or "<" in value
