# TASK-027 - Docker Compose, nginx, and deployment docs refresh

**Use case:** [ideas/use-cases/self-hosted-backend.md](../../ideas/use-cases/self-hosted-backend.md)
**Research:** [research/fastapi-auth.md](../../research/fastapi-auth.md)
**Depends on:** TASK-023
**Effort:** S
**Risk:** low

**Status:** todo

## Goal

Make the backend deployable exactly as the plan describes: a backend
`Dockerfile`, a `docker-compose.yml` (backend + nginx serving the Flutter
web build and proxying `/api/`), the nginx config with SPA fallback, and a
refreshed `self-hosting-setup.md` that points at the monorepo layout, the
new dependency pins (PyJWT/pwdlib — the python-jose/passlib lines deleted,
not upgraded), and the current serialization note. Compose configuration is
validated headless (`docker compose config`) since the container runtime
isn't available in CI; actual home-server deployment stays an owner-run
step.

## Acceptance criteria

- `badminton_backend/Dockerfile`: python:3.12-slim, installs the package,
  `uvicorn app.main:app --host 0.0.0.0 --port 8000`, `DB_PATH=/data/...`.
- `badminton_backend/deploy/docker-compose.yml`: `backend` (build context
  `..`, volume `./data:/data`, env `JWT_SECRET`/`JWT_EXPIRE_DAYS`, expose
  8000) + `web` (nginx:alpine, port 80, mounts `./flutter-web` +
  `./nginx/nginx.conf`), matching the plan doc.
- `badminton_backend/deploy/nginx/nginx.conf`: `/api/` →
  `proxy_pass http://backend:8000` and `/` →
  `try_files $uri $uri/ /index.html`.
- `.env.example` documenting `JWT_SECRET` generation
  (`python -c "import secrets; print(secrets.token_hex(32))"`).
- `badminton_flutter/docs/self-hosting-setup.md` updated: source lives in
  the monorepo (`badminton_backend/`), rsync/deploy steps copy
  `deploy/` + built wheel or source, web build command unchanged, stale
  serialization note corrected (drills JSON array, goal/reflection fields),
  python-jose/passlib references removed.
- Automated checks that keep this task honest in pytest:
  compose file parses (`yaml.safe_load`) with the expected services,
  Dockerfile references the real package path, nginx conf contains both
  location rules, `.env.example` has no real secret. (`docker compose
  config` run manually if docker exists; not required for green.)
- `pytest` green.

## Test plan

RED first in `badminton_backend/tests/test_deploy.py`:

- `test_compose_defines_backend_and_web_services`
- `test_compose_backend_mounts_data_volume_and_env`
- `test_nginx_conf_proxies_api_and_falls_back_to_index`
- `test_dockerfile_runs_uvicorn_on_8000`
- `test_env_example_has_placeholder_secret_only`
- `test_setup_doc_mentions_monorepo_path_and_no_dead_pins`
  (greps `self-hosting-setup.md`: contains `badminton_backend/`, does not
  contain `python-jose` or `passlib`)

## Implementation plan

1. Write `Dockerfile`, `deploy/docker-compose.yml`,
   `deploy/nginx/nginx.conf`, `deploy/.env.example`.
2. `tests/test_deploy.py` assertions over the files (pure file reads —
   fast, no docker needed).
3. Rewrite the affected sections of
   `badminton_flutter/docs/self-hosting-setup.md` (directory structure,
   step ordering, requirements listing, serialization appendix) and touch
   up `self-hosting-plan.md`'s stale pins/serialization block with a
   pointer note rather than a rewrite.
4. If docker is present locally: `docker compose config` sanity run
   (documented, optional).
5. Full `pytest` run.
