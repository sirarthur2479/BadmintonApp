"""Analysis job queue (research/background-jobs.md).

One SQLite `jobs` table + one in-process asyncio worker — deliberately no
Redis/Celery on a single-user home server. `sessionId` is the phone's local
session id, an opaque correlation key (the phone is offline-first; its
sessions don't exist server-side).
"""

import sqlite3
import uuid
from datetime import datetime, timezone
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
