"""Analysis job queue (research/background-jobs.md).

One SQLite `jobs` table + one in-process asyncio worker — deliberately no
Redis/Celery on a single-user home server. `sessionId` is the phone's local
session id, an opaque correlation key (the phone is offline-first; its
sessions don't exist server-side).
"""

import asyncio
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import NamedTuple, Protocol

from .database import get_conn
from .settings import Settings


class PipelineResult(NamedTuple):
    report_path: str
    court_map_path: str  # empty for modes that produce no court map


class PipelineRunner(Protocol):
    def __call__(self, video_path: str, mode: str, out_dir: str) -> PipelineResult: ...


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


class JobWorker:
    """Owns the jobs state machine; invokes the (injectable) pipeline runner."""

    def __init__(self, settings: Settings, runner: PipelineRunner) -> None:
        self._settings = settings
        self._runner = runner
        # One job at a time, per the brief — no worker pool on a home server.
        self._serial = asyncio.Lock()
        # Strong refs so fire-and-forget tasks aren't garbage-collected.
        self._tasks: set[asyncio.Task] = set()

    def enqueue(self, *, player_id: str, session_id: str, video_path: str,
                mode: str) -> str:
        job_id = str(uuid.uuid4())
        with get_conn(self._settings) as conn:
            conn.execute(
                "INSERT INTO jobs (id, playerId, sessionId, videoPath, mode,"
                " createdAt) VALUES (?, ?, ?, ?, ?, ?)",
                (job_id, player_id, session_id, video_path, mode, _now()),
            )
        return job_id

    def kick(self, job_id: str) -> None:
        """Schedule processing on the running loop (fire-and-forget)."""
        task = asyncio.get_running_loop().create_task(self._process(job_id))
        self._tasks.add(task)
        task.add_done_callback(self._tasks.discard)

    async def _process(self, job_id: str) -> None:
        async with self._serial:
            with get_conn(self._settings) as conn:
                row = conn.execute(
                    "SELECT * FROM jobs WHERE id = ?", (job_id,)
                ).fetchone()
                if row is None or row["status"] != "queued":
                    return
                conn.execute(
                    "UPDATE jobs SET status = 'analyzing', startedAt = ?"
                    " WHERE id = ?",
                    (_now(), job_id),
                )

            out_dir = Path(self._settings.upload_dir) / job_id
            out_dir.mkdir(parents=True, exist_ok=True)
            try:
                # The pipeline is synchronous CPU/GPU-bound code — run it off
                # the event loop so uploads/polling stay responsive.
                result = await asyncio.to_thread(
                    self._runner, row["videoPath"], row["mode"], str(out_dir)
                )
            except Exception as exc:
                # str(exc) verbatim: for ExtrasMissingError this is the
                # actionable "pip install ..." hint the owner needs.
                with get_conn(self._settings) as conn:
                    conn.execute(
                        "UPDATE jobs SET status = 'failed', errorMessage = ?,"
                        " finishedAt = ? WHERE id = ?",
                        (str(exc), _now(), job_id),
                    )
                return

            with get_conn(self._settings) as conn:
                conn.execute(
                    "UPDATE jobs SET status = 'done', reportPath = ?,"
                    " courtMapPath = ?, finishedAt = ? WHERE id = ?",
                    (
                        result.report_path,
                        result.court_map_path or None,
                        _now(),
                        job_id,
                    ),
                )


def resume_or_fail_orphaned_jobs(settings: Settings, worker: JobWorker) -> None:
    """Startup sweep. 'analyzing' means the previous process died mid-job —
    there is no safe way to resume mid-pipeline, so those fail loudly rather
    than hang or silently vanish. 'queued' jobs have no partial side effects
    and are re-kicked."""
    with get_conn(settings) as conn:
        conn.execute(
            "UPDATE jobs SET status = 'failed',"
            " errorMessage = 'interrupted by server restart', finishedAt = ?"
            " WHERE status = 'analyzing'",
            (_now(),),
        )
        queued = [
            r["id"]
            for r in conn.execute(
                "SELECT id FROM jobs WHERE status = 'queued' ORDER BY createdAt"
            ).fetchall()
        ]
    for job_id in queued:
        worker.kick(job_id)
