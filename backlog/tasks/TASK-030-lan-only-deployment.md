# TASK-030 - LAN-only ingest deployment: un-tunneled upload port + docs

**Use case:** [ideas/use-cases/badmintontrack-integration.md](../../ideas/use-cases/badmintontrack-integration.md)
**Research:** [research/resumable-upload.md](../../research/resumable-upload.md)
**Depends on:** TASK-028, TASK-029
**Effort:** S
**Risk:** low

**Status:** in-progress

## Goal

Enforce the non-negotiable privacy constraint in the deployment layer:
footage of a minor must never be reachable through the public Cloudflare
Tunnel. The API container gets a second, LAN-only exposure
(`http://<lan-ip>:8001`) for the upload/jobs flow, and the nginx config
that fronts the tunnel explicitly refuses to proxy `/api/v1/uploads`, so
the only path to the ingest endpoint is the home network. Documented in the
self-hosting setup doc, verified by the same doc-lint pytest style used in
TASK-027.

## Acceptance criteria

- `deploy/docker-compose.yml`: the api service publishes host port `8001`
  (mapped to the container's uvicorn port) so the LAN can reach the full
  API — including `/api/v1/uploads` — directly, without nginx or the
  tunnel. The tunnel continues to front only nginx:80.
- `deploy/nginx.conf`: an explicit `location ^~ /api/v1/uploads { return
  403; }` (or equivalent deny) **before** the general API proxy block, so
  the tunneled hostname can never create, probe, or PATCH an upload even
  though the same app instance serves both ports.
- Upload/analysis artifacts live under a bind-mounted `data/` volume
  (`data/uploads/` per TASK-028) already covered by the deploy backup +
  gitignore posture.
- `badminton_flutter/docs/self-hosting-setup.md` gains a "Video analysis
  (LAN-only)" section: the 8001 address to enter in the app's settings
  screen, why it is not tunneled, and the optional ML extras install for
  the pipeline (`pip install -e ".[ml]"`-style, per badminton_track's
  extras) — without naming any banned library.
- Doc-lint tests green (`pytest`), asserting the invariants above from the
  actual file contents.

## Test plan

RED first in `badminton_backend/tests/test_deployment.py` (extend the
TASK-027 doc-lint suite):

- `test_compose_publishes_lan_only_upload_port_8001`
- `test_nginx_denies_uploads_path_before_api_proxy`
- `test_tunnel_still_fronts_only_nginx`
- `test_setup_doc_documents_lan_only_ingest_and_extras`

## Implementation plan

1. `deploy/docker-compose.yml`: add `"8001:8000"` to the api service's
   `ports`.
2. `deploy/nginx.conf`: add the deny `location` above the `/api/` proxy
   block; comment states the privacy invariant.
3. `badminton_flutter/docs/self-hosting-setup.md`: new section per the
   acceptance criteria.
4. Extend `tests/test_deployment.py`; full `pytest`.
