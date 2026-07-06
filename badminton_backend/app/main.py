from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .database import init_db
from .routers import auth as auth_router
from .settings import Settings


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or Settings.from_env()
    init_db(settings)

    app = FastAPI(title="badminton-backend")
    app.state.settings = settings
    # Same-origin in production (nginx serves both); permissive CORS keeps
    # local `flutter run -d chrome` development working.
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.include_router(auth_router.router, prefix="/api/v1")
    return app


# Production entrypoint: uvicorn "app.main:create_app" --factory
# (no module-level app instance — tests build their own with temp settings).
