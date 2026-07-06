# TASK-021 - badminton_backend scaffold: FastAPI app, schema, JWT auth

**Use case:** [ideas/use-cases/self-hosted-backend.md](../../ideas/use-cases/self-hosted-backend.md)
**Research:** [research/fastapi-auth.md](../../research/fastapi-auth.md)
**Depends on:** -
**Effort:** M
**Risk:** medium

**Status:** todo

## Goal

Stand up `badminton_backend/` as a new top-level monorepo project: a FastAPI
app factory, SQLite schema whose sessions/tournaments/matches columns match
the **current** Flutter `toMap()` output (drills as a JSON array string,
goal/reflection columns, nullable intensity — NOT the stale comma format in
the old plan doc), and the auth layer per `research/fastapi-auth.md`:
`POST /api/v1/auth/register` and `/login` with **PyJWT 2.13 (HS256, str sub,
30-day exp)** and **pwdlib[argon2] Argon2id** hashing. The old
`python-jose`/`passlib` pins are forbidden (critical CVE / unmaintained).
Everything testable headless: pytest + `TestClient`, one temp SQLite file
per test.

## Acceptance criteria

- `badminton_backend/` with `pyproject.toml` (or requirements.txt +
  pytest.ini): `fastapi==0.139.0`, `uvicorn==0.50.0`, `pyjwt==2.13.0`,
  `pwdlib[argon2]==0.3.0`; dev: `pytest`, `httpx`. `python-jose` and
  `passlib` appear nowhere.
- `app/settings.py`: `DB_PATH`, `JWT_SECRET`, `JWT_EXPIRE_DAYS=30` from env
  (defaults suitable for dev; missing `JWT_SECRET` outside dev mode fails
  loudly at startup).
- `app/database.py`: `init_db(path)` creates tables `accounts(id TEXT PK,
  email TEXT UNIQUE NOT NULL, password_hash TEXT NOT NULL, created_at TEXT)`,
  `players(id TEXT PK, accountId FK, name, age, club, playingStyle,
  preferredGrip, shortTermGoal, longTermGoal, photoPath)`,
  `sessions(id TEXT PK, playerId FK, date, durationMinutes, drills,
  intensity NULLABLE, notes, photoPath, sessionGoal, goalAchievementScore,
  playerRemarks, coachRemarks, reflectionAnswersJson)`,
  `tournaments(id TEXT PK, playerId FK, name, date, location, format)`,
  `matches(id TEXT PK, tournamentId FK ON DELETE CASCADE, opponent, scores,
  isWin, notes)`, `custom_tags(playerId FK, name, PK(playerId, name))`;
  `PRAGMA foreign_keys=ON` on every connection.
- `app/auth.py`: `hash_password`/`verify_password` (pwdlib
  `PasswordHash.recommended()`); `create_access_token(account_id) -> str`
  (`sub=str(id)`, `exp=now+30d`, HS256); `get_current_account` FastAPI
  dependency (`OAuth2PasswordBearer`-style header parse, explicit
  `algorithms=["HS256"]`, 401 on any `InvalidTokenError`).
- `POST /api/v1/auth/register {email, password}` → 201 `{id, email}`;
  duplicate email → 409; blank email/password → 422.
- `POST /api/v1/auth/login {email, password}` → 200
  `{access_token, token_type: "bearer"}`; wrong password/unknown email →
  401 (identical error — no account enumeration).
- A protected probe route (e.g. `GET /api/v1/me`) returns the accountId with
  a valid token, 401 with a missing/garbage/expired token.
- Root `CLAUDE.md` gains the `badminton_backend/` row (python-api, pytest).
- `pytest` green in this container.

## Test plan

RED first in `badminton_backend/tests/` (fixtures: temp DB path per test,
`TestClient` against `create_app(settings)`):

- `test_auth.py::test_register_creates_account_and_returns_no_hash`
- `test_auth.py::test_register_duplicate_email_409`
- `test_auth.py::test_register_rejects_blank_fields`
- `test_auth.py::test_login_returns_bearer_token`
- `test_auth.py::test_login_wrong_password_and_unknown_email_same_401`
- `test_auth.py::test_me_with_valid_token_returns_account_id`
- `test_auth.py::test_me_rejects_missing_garbage_and_expired_tokens`
- `test_auth.py::test_password_stored_as_argon2_hash_not_plaintext`
- `test_database.py::test_init_db_creates_all_tables_with_fk_pragma`

## Implementation plan

1. `badminton_backend/pyproject.toml` + `.gitignore` (`data/`, `*.db`,
   `.venv/`, `__pycache__/`).
2. `app/settings.py`: pydantic-settings-free simple dataclass reading
   `os.environ` (fewer deps), `Settings.for_tests(tmp)` helper.
3. `app/database.py`: `get_conn(settings)` (sqlite3, row_factory, FK pragma),
   `init_db`.
4. `app/auth.py` exactly per the research doc's code sketch.
5. `app/models.py`: pydantic request/response models for auth.
6. `app/routers/auth.py` + `app/main.py::create_app(settings) -> FastAPI`
   (CORS for the web app origin, router mounting, startup `init_db`).
7. `tests/conftest.py`: `client` fixture with tmp DB; `auth_headers` helper.
8. venv + `pip install -e .[dev]`, full `pytest` run; update CLAUDE.md.
