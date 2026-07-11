# Research: background-jobs

**Date:** 2026-07-06 / **Triggering use-case:** ../ideas/use-cases/badmintontrack-integration.md

## Need summary

`badminton_backend/` (FastAPI + SQLite, single Docker Compose host, no
Redis/Celery/broker infra today) needs to run occasional long-running
(minutes), CPU/GPU-heavy background jobs: invoking the already-built
`badminton_track` CV/local-LLM pipeline (`footwork.run_footwork` /
`biomech.run_biomech` + `coach.produce_report`) after a video finishes
uploading.

Hard requirements from the use-case and CLAUDE.md:

- **Job states persisted** (`queued` → `analyzing` → `done` | `failed`) in
  the same SQLite DB the rest of the backend already uses
  (`badminton_backend/app/database.py`), so state survives a container
  restart.
- **Crash/restart recovery is correctness-critical**: a job that was
  `analyzing` when the container died must come back as `failed`, never
  stuck `analyzing` forever and never silently vanish.
- **Single-user/family app** — one video being analyzed at a time is fine;
  heavy concurrency is explicitly not a goal. Simplicity beats throughput.
- **No new infrastructure dependency** — the constraint in the use-case doc
  is explicit: "the server is a single Docker Compose host with no
  Redis/Celery infrastructure today — job orchestration must fit that... not
  a new infra dependency."
- **Python 3.11+, FastAPI**, and the job runner must be **pytest-testable
  without the heavy ML extras installed** — `badminton_track`'s own
  `pyproject.toml` keeps `ultralytics`/`mediapipe`/`ollama` behind optional
  extras (`footwork`, `biomech`, `coach`, `full`) specifically so its own
  unit tests run headless; the backend must preserve that property and
  import `badminton_track` lazily, turning a missing-extras error into a
  `failed` job row rather than a crash.

## Candidates evaluated

Scoring: functionality fit 30%, maintenance 20%, community 20%, documentation
15%, licence 10%, dependency footprint 5%. Versions/dates verified live via
the PyPI JSON API and GitHub repo pages fetched 2026-07-06. Search coverage
was adequate (7 candidates, primary sources fetched for all version/licence
claims); not thin. Star counts from GitHub page fetches are point-in-time
reads, not the GitHub API, and are noted as such.

| Name | Stars | Last release | Licence | Weighted | Decision |
|---|---|---|---|---|---|
| Plain SQLite `jobs` table + in-process asyncio worker (roll-your-own) | n/a (pattern, not a package) | n/a | n/a | **4.70** | **adopt** |
| FastAPI `BackgroundTasks` (stdlib feature) | n/a (ships with FastAPI) | tracks FastAPI (0.139.0, 2026) | MIT | 3.15 | **build-on-top** (use only as the in-process trigger, not as the durability layer) |
| Huey (`SqliteHuey`) | 6.0k ★ | 3.1.1 (2026-07-02) | MIT | 3.85 | skip (good fit, but adds a second worker process/lifecycle for no real gain here) |
| APScheduler | 7.6k ★ | 3.11.3 (2026-06-28) | MIT | 3.35 | skip (scheduler semantics, not a job-state/queue model; wrong tool shape) |
| arq | 3.0k ★ | 0.28.0 (2026-04-16) | MIT | 2.35 | **skip — adds infra** (hard Redis dependency; maintenance-only mode per maintainer) |
| Dramatiq | 5.3k ★ | 2.2.0 (2026-06-17) | LGPL-3.0/GPL-3.0 | 2.20 | **skip — adds infra** (Redis/RabbitMQ broker required; copyleft licence needs review) |
| Celery | 28.7k ★ | 5.6.3 (2026) | BSD-3-Clause | 1.75 | **skip — overkill** (broker-mandatory, heavyweight for a single occasional job) |

## Per-candidate notes

### 1. Roll-your-own: SQLite `jobs` table + asyncio background worker — 4.70 — adopt
- Exactly matches the stated constraint ("job orchestration must fit that...
  not a new infra dependency"). The backend already treats SQLite as its
  only persistence layer (`app/database.py`); a `jobs` table is one more
  `CREATE TABLE` in the same `_SCHEMA` string, no new service in
  `docker-compose.yml`, no new Python dependency at all.
- Functionality fit is a perfect match for the *shape* of this problem —
  one job at a time, minutes-long, needs durable states, needs
  restart-safe recovery — precisely the profile many small self-hosted apps
  solve this way (confirmed as a recognized, if under-documented, pattern in
  web search: general FastAPI+job-queue writeups default to Redis-backed
  advice, but the "single SQLite table + polling task" shape is exactly what
  frameworks like Huey's SQLite backend and APScheduler's SQLAlchemy job
  store formalize — see below — evidence this is a well-trodden shape, not
  a hack).
- Maintenance/community/docs axes don't really apply (it's not a package),
  scored as neutral-to-good since it's ~80 lines of code the team fully
  owns and already knows how to test (same `TestClient` + temp-SQLite
  pattern as every other router in `badminton_backend/`).
- Main risk, and why it's not a 5.0: it is bespoke code that must get the
  restart-recovery and lazy-import-failure paths right by hand (no library
  to lean on for those). Mitigated by keeping the state machine tiny (4
  states, one worker) and testing it directly — see Recommendation below.

### 2. FastAPI `BackgroundTasks` — 3.15 — build-on-top
- Confirmed via the FastAPI docs (fetched via GitHub raw, since
  `fastapi.tiangolo.com` 403s through the proxy — same block noted in
  `research/fastapi-auth.md`): tasks run **in the same process**, added with
  `.add_task()`, executed after the response is returned. FastAPI's own
  docs point to Celery for "heavy background computation."
- Independently confirmed by web search (oneuptime.com, dev.to writeups,
  2026): "If your application restarts... every pending task that had not
  started yet is gone. There is no way to recover it" and "no retry
  mechanism, no backoff." Exactly the two failure modes the use-case's
  restart-safety requirement rules out as the sole mechanism.
- Still useful as the **trigger**, not the **durability layer**: the upload
  endpoint can call `background_tasks.add_task(runner.kick, job_id)` to wake
  the in-process worker immediately after inserting the `queued` row,
  avoiding a poll-interval delay for the common case — the SQLite row (not
  the in-memory task) remains the source of truth, and a periodic
  poll/resume-on-startup path covers the case where the process died before
  or during that task.

### 3. Huey (`SqliteHuey`) — 3.85 — skip (good fit, still adds a process)
- **Verified current and well-maintained in 2026**, directly answering the
  brief's question: PyPI shows 3.1.1 released 2026-07-02 (days before this
  research), GitHub shows 6.0k ★, 0 open issues, 1,152 commits, 60 releases.
  huey's own docs state "Huey comes with builtin support for Redis,
  Postgres, Sqlite and in-memory storage" and a 2026-04 MarkTechPost
  tutorial confirms `SqliteHuey` supports scheduling, retries, pipelines,
  and locking using only the stdlib `sqlite3` module (no Redis needed).
- This is the strongest *library* fit found — it would satisfy every
  constraint (no new infra service, SQLite-native, small dependency
  footprint, Python 3.11-compatible, MIT). Scored down from adopt because it
  still requires running a **separate long-lived huey consumer process**
  (`huey_consumer.py`) alongside uvicorn — a second process to supervise in
  `docker-compose.yml`, with its own restart/crash semantics to reason
  about — for a workload that is "occasional" and single-job-at-a-time.
  For this app's exact scale, a plain table + in-process asyncio worker
  gets the same durability with strictly less moving infrastructure. Worth
  revisiting if job volume/concurrency ever grows enough to want huey's
  retry/scheduling/priority machinery for free.

### 4. APScheduler — 3.35 — skip (wrong tool shape)
- Verified: 3.11.3 (2026-06-28), MIT, 7.6k ★, 39 open issues — healthy
  project. Supports `SQLAlchemyJobStore` against SQLite for persisted jobs
  and both sync and async (asyncio/Trio) schedulers.
- Functionality fit is the weak axis: APScheduler models *scheduled/cron*
  jobs (run at a time, or on an interval), not a `queued → analyzing →
  done|failed` **state machine for one-off jobs enqueued by an HTTP
  request**. It can be bent into an on-demand job runner (`add_job` with an
  immediate trigger), but recovering "was this job mid-run when we crashed"
  is not its native concept — that's still something you'd bolt on. Right
  tool if this app later needs "re-run analysis nightly" style recurring
  jobs; not the primary need here.

### 5. arq — 2.35 — skip, adds infra
- Verified: 0.28.0 (2026-04-16), MIT, 3.0k ★, 85 open issues. GitHub issue
  #510 states the project is now in **maintenance-only mode**.
- Hard-requires Redis by design ("Job queues in python with asyncio and
  redis" — it's in the one-line description). That is precisely the
  external-broker dependency the use-case rules out ("no Redis/Celery
  infrastructure today... not a new infra dependency"). Maintenance-only
  status is a second, independent reason to pass even ignoring the infra
  cost.

### 6. Dramatiq — 2.20 — skip, adds infra
- Verified: 2.2.0 (2026-06-17), 5.3k ★, 43 open issues. Broker support is
  RabbitMQ or Redis only — no SQLite/file broker exists (confirmed via the
  GitHub repo page and PyPI extras: `dramatiq[rabbitmq]` / `dramatiq[redis]`,
  no sqlite extra). Same infra-dependency disqualifier as arq.
- Licence is also a mark against it here: PyPI/GitHub list **LGPL-3.0 /
  GPL-3.0**, a copyleft licence, versus the permissive MIT/BSD used
  everywhere else in this stack (FastAPI, PyJWT, pwdlib — see
  `research/fastapi-auth.md`) — one more reason it doesn't clear the bar
  even before the broker question.

### 7. Celery — 1.75 — skip, overkill
- Verified: 28.7k ★ (by far the largest community of any candidate here),
  5.6.3 current, BSD-3-Clause, 657 open issues (scale of a very large,
  general-purpose project). Requires a broker (Redis/RabbitMQ/etc.) and
  typically a separate result backend; operationally it is a distributed
  system in a box.
- Wrong instrument for "run one CV/LLM job occasionally on a family's home
  server." Every axis that matters for *this* app (dependency footprint,
  operational simplicity) is actively worse than the roll-your-own option,
  and the huge community/maintenance strength Celery has is aimed at
  problems (multi-worker fleets, complex routing, distributed retries) this
  app doesn't have.

## Recommendation

**Adopt the roll-your-own pattern: a `jobs` SQLite table + a single
in-process asyncio worker task, kicked eagerly by `BackgroundTasks` and
recovered on FastAPI startup.** No new dependency, no new
`docker-compose.yml` service. This is the only candidate that satisfies the
explicit "no new infra dependency" constraint while still fully solving the
persisted-state and restart-recovery requirements; Huey's `SqliteHuey` is
the best fallback if this app ever needs retries/scheduling/priority queues
that justify a second supervised process.

### Schema (matches existing `badminton_backend/app/database.py` conventions)

Existing tables use `TEXT PRIMARY KEY` client-generated UUID ids, camelCase
columns mirroring the Flutter/JSON payload, and `REFERENCES ... ON DELETE
CASCADE` for ownership. The `jobs` table follows the same style:

```sql
CREATE TABLE IF NOT EXISTS jobs (
    id TEXT PRIMARY KEY,
    playerId TEXT NOT NULL REFERENCES players (id) ON DELETE CASCADE,
    sessionId TEXT NOT NULL REFERENCES sessions (id) ON DELETE CASCADE,
    videoPath TEXT NOT NULL,
    mode TEXT NOT NULL,                 -- 'footwork' | 'biomech' | 'full', per owner-selected pipeline mode
    status TEXT NOT NULL DEFAULT 'queued',   -- 'queued' | 'analyzing' | 'done' | 'failed'
    reportPath TEXT,                    -- Markdown coach report, set on 'done'
    courtMapPath TEXT,                  -- court-map image, set on 'done'
    errorMessage TEXT,                  -- set on 'failed' (incl. "extras missing: pip install ...")
    createdAt TEXT NOT NULL,            -- ISO-8601, set at enqueue
    startedAt TEXT,                     -- ISO-8601, set when a worker claims the job
    finishedAt TEXT                     -- ISO-8601, set on 'done' or 'failed'
);
```

`status` deliberately stays a plain `TEXT` (matching how `intensity`,
`isWin` etc. are stored elsewhere in this schema) rather than a SQLite
`CHECK` constraint with an enum, keeping it consistent with the rest of the
file; validate the four-value enum in the Pydantic model / router layer
instead, same division of responsibility the existing `Session`/`Match`
models already use.

### Startup-time recovery (the crash-safety requirement)

Register a FastAPI startup hook (same place `init_db(settings)` already
runs in `app/main.py`) that sweeps orphaned jobs *before* the app starts
accepting traffic:

```python
def resume_or_fail_orphaned_jobs(settings: Settings) -> None:
    """Runs once at startup. Any job still 'analyzing' means the previous
    process died mid-job (uvicorn doesn't checkpoint work) — there is no
    safe way to resume mid-pipeline, so these are marked failed, never
    silently dropped and never left to hang. 'queued' jobs are legitimately
    resumable (no partial side effects yet) and get re-kicked to the worker.
    """
    now = datetime.now(timezone.utc).isoformat()
    with get_conn(settings) as conn:
        conn.execute(
            "UPDATE jobs SET status = 'failed', "
            "errorMessage = 'interrupted by server restart', finishedAt = ? "
            "WHERE status = 'analyzing'",
            (now,),
        )
        queued_ids = [
            r["id"] for r in conn.execute(
                "SELECT id FROM jobs WHERE status = 'queued'"
            ).fetchall()
        ]
    for job_id in queued_ids:
        worker.kick(job_id)   # re-enters the same in-process trigger path
```

Wire this into `create_app()` right after `init_db(settings)`, before
`return app`, so it runs exactly once per process start and before any
request (including a new upload) can race it. This directly satisfies "an
in-flight job should end up `failed`, not silently lost or hung forever":
`analyzing` (mid-job when the container died) → `failed` unconditionally;
`queued` (never claimed) → safely retried, since nothing has run yet.

### Runner design (mockable without the ML extras)

Keep the boundary between "own the SQLite state machine" and "invoke
`badminton_track`" as one narrow, injectable function so pytest can swap it
without importing `ultralytics`/`mediapipe`/`ollama`:

```python
# app/jobs.py
from typing import Protocol

class PipelineRunner(Protocol):
    def __call__(self, video_path: str, mode: str) -> "PipelineResult": ...

class PipelineResult(NamedTuple):
    report_path: str
    court_map_path: str

def real_pipeline_runner(video_path: str, mode: str) -> PipelineResult:
    """The only place that imports badminton_track. Imported lazily so the
    backend process never needs the heavy extras installed to boot or to
    serve any non-video route."""
    from badminton_track import footwork, biomech, coach   # noqa: local import
    from badminton_track.errors import ExtrasMissingError
    ...  # dispatch on `mode`, call run_footwork/run_biomech + coach.produce_report

async def process_job(job_id: str, settings: Settings, runner: PipelineRunner) -> None:
    ...  # mark analyzing -> call runner() in a thread (asyncio.to_thread,
         # since the pipeline is CPU/GPU-bound sync code) -> mark done/failed
```

`runner` defaults to `real_pipeline_runner` in production wiring
(`app.state`), but every test constructs the worker with a fake
`PipelineRunner` (a lambda returning a canned `PipelineResult`, or one that
raises to exercise the `failed` path) — mirroring how `badminton_track`
itself already isolates its heavy imports behind `ExtrasMissingError` so its
*own* test suite runs headless (`badminton_track/pyproject.toml`:
"Pipeline modules import these lazily and raise `ExtrasMissingError`... so
the unit test suite runs headless"). The backend's job runner should catch
`ExtrasMissingError` specifically and store its message verbatim into
`jobs.errorMessage`, giving the owner an actionable "pip install ..." string
in the failed job row instead of a bare 500.

### Concurrency note

One `asyncio.Lock` (or simply "only claim a job if none is currently
`analyzing`") is enough — the use-case is explicit that heavy concurrency
isn't a goal, so there's no need for a worker pool, a queue depth limit, or
job priorities. If two videos finish uploading close together, the second
one sits `queued` until the worker's loop/kick picks it up next; simplicity
over throughput, per the brief.

## Search log

Searches (WebSearch, 2026-07-06):
- `huey python task queue SQLite backend 2026 maintained`
- `FastAPI BackgroundTasks limitations lost on restart no retry`
- `arq python redis task queue 2026 pypi`
- `dramatiq python task queue pypi 2026 broker`
- `APScheduler FastAPI background jobs SQLite job store 2026`
- `"poor man's" job queue SQLite polling asyncio FastAPI single-user self-hosted`
  (thin results specifically for this exact phrase — no dedicated named
  library exists for this pattern, which is itself the point: it's treated
  as a DIY pattern industry-wide, not a packaged product. Noted explicitly
  per the quality gate.)

Primary fetches (WebFetch):
- PyPI JSON API: huey 3.1.1 (2026-07-02), arq 0.28.0 (2026-04-16, MIT,
  >=3.9), dramatiq 2.2.0 (2026-06-17, LGPL/GPL, >=3.10), celery 5.6.3
  (BSD-3, >=3.9), APScheduler 3.11.3 (2026-06-28, MIT, >=3.8).
- GitHub repo pages: coleifer/huey (6.0k ★, MIT, 0 open issues, 1,152
  commits, 60 releases), python-arq/arq (3.0k ★, MIT, 85 open issues,
  maintenance-only per issue #510), Bogdanp/dramatiq (5.3k ★, LGPL-3.0/
  GPL-3.0, 43 open issues, RabbitMQ/Redis brokers only, no SQLite broker),
  celery/celery (28.7k ★, BSD, 657 open issues), agronholm/apscheduler
  (7.6k ★, MIT, 39 open issues, SQLAlchemy/SQLite job store, async support).
- `raw.githubusercontent.com/fastapi/fastapi/master/docs/en/docs/tutorial/background-tasks.md`
  — confirms in-process execution model and that FastAPI's own docs point
  to Celery for heavy computation (worked around `fastapi.tiangolo.com`
  403 via proxy, same block documented in `research/fastapi-auth.md`).

Blocked/unavailable: `fastapi.tiangolo.com` (403 via proxy, worked around
via GitHub raw), `apscheduler.readthedocs.io/en/3.x/userguide.html` (403 via
proxy) and the APScheduler `CHANGES.rst` raw path (404 — file has likely
moved/renamed in the current repo layout); APScheduler claims above rely on
the GitHub repo root page and search-result snippets instead, marked
accordingly. Star counts are single-fetch snapshots from GitHub's rendered
page (not the GitHub REST API, which required auth not available in this
environment) — treat as approximate, not exact-to-the-digit.
