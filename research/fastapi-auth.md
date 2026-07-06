# Research: fastapi-auth

**Date:** 2026-07-06 / **Triggering use-case:** ../ideas/use-cases/self-hosted-backend.md

## Need summary

`badminton_backend/` (FastAPI + SQLite, Docker on a home server behind a
Cloudflare Tunnel) needs:

- **JWT bearer-token auth**: `/api/v1/auth/register|login`, HS256-style signed
  tokens with `sub = accountId` and **30-day expiry**; every data route checks
  `players.accountId == JWT.sub`.
- **Password hashing** for the account table.
- Python 3.11+, minimal deps, fully testable headless with pytest +
  `TestClient` (no network, temp SQLite per test).
- Single-service, symmetric-secret setup — the secret comes from an env var;
  no OAuth federation, no JWE, no key rotation infra needed.

The 2024-era plan pins `python-jose[cryptography]==3.3.0` and
`passlib[bcrypt]==1.7.4`. **Both pins are confirmed dead ends** (details
below); this research picks the 2026-current replacements and versions.

## Candidates evaluated

Scoring: functionality fit 30%, maintenance 20%, community 20%, documentation
15%, licence 10%, dependency footprint 5%. PyPI versions/dates verified live
via the PyPI JSON API on 2026-07-06; stars via GitHub page fetches where
possible. The proxy blocked `api.github.com` and `security.snyk.io`, so some
star counts are from memory/secondary sources — marked (u) = unverified.
Search coverage was adequate (10 candidates, primary sources fetched for all
version claims); not thin.

| Name | Layer | Stars or downloads | Last release | Licence | Weighted | Decision |
|---|---|---|---|---|---|---|
| PyJWT | jwt | 5.7k ★ | 2.13.0 (2026-05-21) | MIT | **5.00** | **adopt** |
| pwdlib | hashing | 161 ★ (but the FastAPI-docs + fastapi-users standard) | 0.3.0 (2025-10-25) | MIT | **4.65** | **adopt** (`[argon2]`) |
| argon2-cffi | hashing | ~700 ★ (u) | 25.1.0 (2025) | MIT | 4.45 | build-on-top (arrives as pwdlib's engine; don't call directly) |
| bcrypt (pyca) | hashing | ~1.4k ★ (u); pyca-maintained | 5.0.0 (2025) | Apache-2.0 | 4.40 | skip (fine fallback if argon2 wheels ever misbehave) |
| joserfc | jwt | 167 ★ | 1.7.2 (2026-06-29) | BSD-3-Clause | 4.25 | skip (adopt only if JWE/JWKS ever needed) |
| Authlib | jwt/framework | ~4.9k ★ (u) | 1.7.2 (2026-05-06) | BSD-3-Clause | 4.15 | skip (OAuth-server scale, overkill) |
| fastapi-users | framework | ~5.5k ★ (u) | 15.0.5 (2026, date u) | MIT | 3.65 | skip (in maintenance mode; brings its own user model) |
| AuthX | framework | ~1k ★ (u) | 1.7.1 (2026-06-27) | MIT | 3.40 | skip |
| python-jose | jwt | 1.8k ★ | 3.5.0 (2025-05-28) | MIT | 3.30 | **skip — replace; never use the 3.3.0 pin** |
| passlib | hashing | n/a (hosted on Heptapod) | 1.7.4 (2020-10-08) | BSD | 3.30 | **skip — replace** |

## Per-candidate notes (top 8)

### 1. PyJWT — 5.00 — adopt
- Exactly the needed surface: `jwt.encode(payload, secret, algorithm="HS256")`
  / `jwt.decode(token, secret, algorithms=["HS256"])` with built-in `exp`
  validation (`ExpiredSignatureError`, base `InvalidTokenError`).
- **It is what the official FastAPI tutorial now uses** — the docs' OAuth2+JWT
  chapter says `pip install pyjwt`; FastAPI dropped python-jose after
  discussion fastapi/fastapi#9587. Verified by fetching the current tutorial
  source from the fastapi repo (master, 2026-07-06).
- Actively maintained: 2.13.0 released 2026-05-21 (PyPI verified), MIT,
  Python >=3.9. **Zero runtime deps for HS256** (`cryptography` only via the
  `[crypto]` extra, which we don't need for symmetric signing).
- Gotcha worth encoding in the plan: since 2.10, PyJWT validates that `sub`
  is a string when present — serialize `accountId` as `str(uuid)`, which the
  plan already implies (client-generated UUID strings).

### 2. pwdlib — 4.65 — adopt (`pwdlib[argon2]`)
- The deliberate passlib successor by the fastapi-users author; README states
  it exists because passlib "has not been very active" and breaks on
  Python 3.13+ (GitHub fetch verified). Small on stars (161) but it is the
  library **both** the official FastAPI tutorial (`pip install "pwdlib[argon2]"`)
  and fastapi-users 15.x (`pwdlib[argon2,bcrypt]==0.3.0`) use — community
  scored on that adoption, not raw stars.
- API is three lines: `PasswordHash.recommended()` → Argon2id; `.hash()`,
  `.verify()`, and `.verify_and_update()` for future algorithm migration.
- 0.3.0 (2025-10-25, PyPI verified), MIT, Python >=3.10; extras pin
  `argon2-cffi >=23.1.0,<26` and `bcrypt >=4.1.2,<6`.

### 3. argon2-cffi — 4.45 — build-on-top
- Hynek Schlawack's binding to the reference Argon2 implementation; 25.1.0
  (2025, PyPI verified), MIT, excellent docs. This is what actually hashes
  when pwdlib is installed with `[argon2]`. Using it directly
  (`PasswordHasher().hash/verify`) would be one dependency fewer, but pwdlib's
  `verify_and_update` + FastAPI-docs alignment is worth the thin wrapper.

### 4. bcrypt (pyca) — 4.40 — skip
- Rock-solid pyca project, Apache-2.0, 5.0.0 current. Direct use
  (`bcrypt.hashpw/checkpw`) is viable and dependency-free, but: 5.0.0 now
  **raises `ValueError` on passwords >72 bytes** (previously silent
  truncation) so you'd have to handle length yourself, and docs are a bare
  README. Argon2id via pwdlib is the better 2026 default. Note for anyone
  tempted to keep passlib: bcrypt >=4.1 is exactly what broke passlib.

### 5. joserfc — 4.25 — skip
- Authlib org's modern standalone JOSE implementation (JWS/JWE/JWK/JWT,
  RFC 7515–7519 + EdDSA), 1.7.2 released 2026-06-29, BSD-3, very active.
  It is the strongest python-jose *feature-for-feature* replacement, but this
  app needs none of the JWE/JWKS surface and it hard-requires `cryptography`.
  Re-evaluate if the BadmintonTrack service ever needs asymmetric keys.

### 6. Authlib — 4.15 — skip
- Full OAuth/OIDC client+server framework (now depends on joserfc >=1.6 for
  its JOSE layer). Healthy and well-documented, but an order of magnitude
  more machinery than a two-endpoint register/login API needs.

### 7. fastapi-users — 3.65 — skip
- Batteries-included registration/login/reset/verify routers. Two reasons to
  pass: (a) the project is explicitly in **maintenance mode** ("no new
  features", security updates only — PyPI page verified); (b) it imposes its
  own user model/manager abstractions, while our Account→Players schema and
  routes are already fully specced and trivially hand-rollable. Its dependency
  choices (`pyjwt[crypto]>=2.12`, `pwdlib[argon2,bcrypt]==0.3.0`) do, however,
  independently confirm the recommended stack.

### 8. AuthX — 3.40 — skip
- Active (1.7.1, 2026-06-27) FastAPI auth toolkit on PyJWT; adds
  cookie/CSRF/refresh-token plumbing we don't need and a smaller
  community/doc base. Same conclusion as fastapi-users: for ~60 lines of
  auth code, a framework dependency is negative value.

### Why hand-rolled-per-the-tutorial is right here

Two endpoints, one token type, one consumer app, secret in an env var,
pytest-driven. The FastAPI tutorial pattern (OAuth2PasswordBearer dependency +
PyJWT + pwdlib) is ~60 lines, has no framework lock-in, and is exactly
testable with `TestClient`. Batteries-included libs earn their keep with email
verification/reset/OAuth flows — all out of scope for a family app behind a
Cloudflare Tunnel.

### Legacy pins (why they must go)

- **python-jose 3.3.0 (2021) is affirmatively vulnerable**: CVE-2024-33663
  (critical — algorithm confusion with OpenSSH ECDSA keys) and CVE-2024-33664
  (JWE DoS), both fixed only in 3.4.0 (2025). A further advisory,
  CVE-2025-61152 (`alg=none` tokens accepted; GHSA-28pv-f4g7-364j, published
  2025-10-10), sits **unreviewed** against current versions (GitHub Advisory
  DB, fetched 2026-07-06). The project had a 4-year release gap (3.3.0
  2021 → 3.4.0 2025) and FastAPI removed it from its docs. Do not pin any
  version of it for new code.
- **passlib 1.7.4 (2020-10-08) is unmaintained**: incompatible with
  `bcrypt>=4.1` (the famous `(trapped) error reading bcrypt version` crash),
  affected by the `crypt` module removal in Python 3.13, and per
  fastapi/fastapi#11773 the FastAPI docs dropped it. `passlib[bcrypt]==1.7.4`
  only works if bcrypt is additionally pinned `<4.1` — a fresh install today
  breaks.

## Recommendation

**JWT: PyJWT 2.13.0 (plain, no `[crypto]` extra) with HS256.**

```python
import jwt  # PyJWT
from datetime import datetime, timedelta, timezone

def create_access_token(account_id: str) -> str:
    payload = {
        "sub": str(account_id),                                   # PyJWT >=2.10 requires str sub
        "exp": datetime.now(timezone.utc) + timedelta(days=30),   # 30-day expiry per plan
    }
    return jwt.encode(payload, SECRET_KEY, algorithm="HS256")

def decode_token(token: str) -> str:
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])  # validates exp
        return payload["sub"]
    except jwt.InvalidTokenError:                                  # covers ExpiredSignatureError
        raise HTTPException(status_code=401, ...)
```

`SECRET_KEY` from env (`secrets.token_hex(32)` generated once on the server),
never committed — matches the privacy constraint. Always pass an explicit
`algorithms=["HS256"]` allowlist on decode.

**Hashing: pwdlib 0.3.0 with the Argon2 extra (Argon2id via argon2-cffi).**

```python
from pwdlib import PasswordHash

password_hash = PasswordHash.recommended()   # Argon2id
hashed = password_hash.hash(plain)
ok = password_hash.verify(plain, hashed)     # or verify_and_update() for future migration
```

**Pins for `badminton_backend/requirements.txt` (current as of 2026-07-06,
PyPI-verified):**

```
fastapi==0.139.0
uvicorn==0.50.0
pyjwt==2.13.0
pwdlib[argon2]==0.3.0        # pulls argon2-cffi 25.1.0
```

(Plus `httpx` for `TestClient` in dev/test deps.) All Python >=3.10-compatible;
target 3.11+ per the constraint.

**Must NOT be used:** `python-jose[cryptography]==3.3.0` (critical
CVE-2024-33663, 4-year-stale pin, library dropped by FastAPI docs) and
`passlib[bcrypt]==1.7.4` (unmaintained since 2020, breaks with bcrypt>=4.1
and Python 3.13+). Delete these lines from the old plan doc wholesale — do not
"upgrade" them in place.

## Search log

Searches (WebSearch, 2026-07-06):
- `python-jose unmaintained 2026 CVE alternative PyJWT` → fastapi/fastapi#9587
  (docs moved to PyJWT), Snyk listing, pyjwt#942 migration guide.
- `passlib unmaintained bcrypt 4 error pwdlib successor 2026` →
  fastapi/fastapi#11773 (docs moved off passlib), pypi/warehouse#15454,
  pwdlib-as-successor confirmations.

Primary fetches (WebFetch):
- `raw.githubusercontent.com/fastapi/fastapi/master/docs/en/docs/tutorial/security/oauth2-jwt.md`
  — current tutorial installs `pyjwt` + `pwdlib[argon2]`, recommends Argon2.
  (Direct `fastapi.tiangolo.com` fetch was 403 via proxy.)
- PyPI JSON API: PyJWT 2.13.0 (2026-05-21), pwdlib 0.3.0 (2025-10-25),
  python-jose 3.5.0 (2025-05-28; 3.3.0 was 2021-06-05), joserfc 1.7.2
  (2026-06-29), Authlib 1.7.2 (2026-05-06), bcrypt 5.0.0, argon2-cffi 25.1.0,
  passlib 1.7.4 (2020-10-08), fastapi-users 15.0.5 (maintenance-mode notice),
  authx 1.7.1 (2026-06-27), fastapi 0.139.0, uvicorn 0.50.0.
- GitHub pages: mpdavis/python-jose (1.8k ★, 94 open issues), jpadilla/pyjwt
  (5.7k ★), frankie567/pwdlib (161 ★, passlib-successor rationale),
  authlib/joserfc (167 ★, RFC list).
- `github.com/advisories?query=python-jose` — CVE-2024-33663 (critical),
  CVE-2024-33664, CVE-2025-61152 (unreviewed), CVE-2016-7036.

Blocked/unavailable: `api.github.com` (proxy 403 — star counts for
bcrypt/argon2-cffi/Authlib/fastapi-users/AuthX are unverified estimates),
`security.snyk.io` (403), `fastapi.tiangolo.com` (403; worked around via
GitHub raw).
