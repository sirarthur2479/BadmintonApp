import sqlite3
from contextlib import asynccontextmanager
from typing import Annotated

from fastapi import Depends, FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .database import init_db
from .deps import current_account
from .jobs import JobWorker, PipelineRunner, resume_or_fail_orphaned_jobs
from .models import AccountOut
from .routers import auth as auth_router
from .routers import players as players_router
from .routers import sessions as sessions_router
from .routers import tags as tags_router
from .routers import tournaments as tournaments_router
from .routers import uploads as uploads_router
from .settings import Settings


def _default_runner(video_path: str, mode: str, out_dir: str):
    # Placeholder until the real badminton_track runner lands (TASK-029
    # slice 5); jobs fail actionably instead of hanging.
    raise NotImplementedError("pipeline runner not wired yet")


def create_app(
    settings: Settings | None = None, runner: PipelineRunner | None = None
) -> FastAPI:
    settings = settings or Settings.from_env()
    init_db(settings)

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        # Runs once per process start, on the serving event loop (kick needs
        # it), before any request can race the sweep.
        resume_or_fail_orphaned_jobs(settings, app.state.job_worker)
        yield

    app = FastAPI(title="badminton-backend", lifespan=lifespan)
    app.state.settings = settings
    app.state.job_worker = JobWorker(settings, runner or _default_runner)
    # Same-origin in production (nginx serves both); permissive CORS keeps
    # local `flutter run -d chrome` development working.
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.include_router(auth_router.router, prefix="/api/v1")
    app.include_router(players_router.router, prefix="/api/v1")
    app.include_router(sessions_router.router, prefix="/api/v1")
    app.include_router(tournaments_router.router, prefix="/api/v1")
    app.include_router(tags_router.router, prefix="/api/v1")
    app.include_router(uploads_router.router, prefix="/api/v1")

    @app.get("/api/v1/me", response_model=AccountOut)
    def me(
        account: Annotated[sqlite3.Row, Depends(current_account)],
    ) -> AccountOut:
        return AccountOut(id=account["id"], email=account["email"])

    return app


# Production entrypoint: uvicorn "app.main:create_app" --factory
# (no module-level app instance — tests build their own with temp settings).
