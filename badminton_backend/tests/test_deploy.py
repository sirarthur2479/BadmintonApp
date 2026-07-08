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


def test_setup_doc_mentions_monorepo_path_and_no_dead_pins():
    doc = (
        BACKEND.parent
        / "badminton_flutter"
        / "docs"
        / "self-hosting-setup.md"
    ).read_text()

    assert "badminton_backend/" in doc, "doc must point at the monorepo source"
    assert "python-jose" not in doc, "CVE'd pin must be gone, not upgraded"
    assert "passlib" not in doc, "unmaintained pin must be gone"
    assert "pyjwt" in doc.lower()
    assert "pwdlib" in doc
    # The stale serialization claim must be corrected.
    assert "comma-delimited" not in doc
    assert "JSON array" in doc


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


# --- LAN-only video ingest (TASK-030): uploads must never transit the
# --- Cloudflare Tunnel; the LAN reaches the API directly on 8001.


def test_compose_publishes_lan_only_upload_port_8001():
    services = compose()["services"]

    # Host port 8001 -> uvicorn, so the phone reaches the tus/jobs routes at
    # http://<lan-ip>:8001 without nginx or the tunnel in the path.
    assert "8001:8000" in services["backend"].get("ports", [])
    # The tunnel-facing entry point stays nginx:80 and nothing else.
    assert services["web"]["ports"] == ["80:80"]


def test_compose_backend_mounts_upload_dir():
    backend = compose()["services"]["backend"]

    env_text = " ".join(backend["environment"])
    assert "UPLOAD_DIR=/data/uploads" in env_text, (
        "uploads must live under the backed-up, gitignored data volume"
    )


def test_nginx_denies_uploads_path_before_api_proxy():
    conf = (DEPLOY / "nginx" / "nginx.conf").read_text()

    deny = conf.find("location ^~ /api/v1/uploads")
    proxy = conf.find("location /api/")
    assert deny != -1, "nginx must explicitly refuse to proxy the ingest path"
    assert deny < proxy, "deny block must take precedence over the API proxy"
    deny_block = conf[deny:conf.find("}", deny)]
    assert "return 403" in deny_block
    assert "proxy_pass" not in deny_block
