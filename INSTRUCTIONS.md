# BadmintonApp

A Flutter badminton training app for mobile (iOS/Android) and self-hosted web.

## Docs

| File | Purpose |
|------|---------|
| [SETUP.md](SETUP.md) | Install prerequisites, run the app and backend server |
| [USER_GUIDE.md](USER_GUIDE.md) | How to use every feature of the app |
| [badminton_flutter/docs/self-hosting-plan.md](badminton_flutter/docs/self-hosting-plan.md) | Full architecture spec for remote backend + Flutter auth |
| [badminton_flutter/docs/log-session-improvement-plan.md](badminton_flutter/docs/log-session-improvement-plan.md) | Full spec for log improvements (goals, match log, export) |
| [badminton_flutter/docs/self-hosting-setup.md](badminton_flutter/docs/self-hosting-setup.md) | Production deployment, server migration, backup |

## Quick Start

```powershell
# Mobile (offline, no backend needed)
cd badminton_flutter; flutter pub get; flutter run

# Web + backend (local) — run each line in its own terminal
cd badminton-server; docker-compose up -d
cd badminton_flutter; flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000/api/v1
```

## Repository Layout

```
BadmintonApp/
  badminton_flutter/    Flutter app (mobile + web)
    lib/
      models/           Data models
      providers/        State (ChangeNotifier)
      services/         DatabaseService, StorageService
      screens/          home / train / learn / profile
      widgets/          Reusable UI components
    docs/               Feature plans and ops guides
    pubspec.yaml
  badminton-server/     Self-hosted backend (Docker Compose)
    backend/app/        FastAPI (Python) — auth, players, sessions, tournaments
    nginx/              Reverse proxy config
    docker-compose.yml
    data/               SQLite database (auto-created on first run)
    flutter-web/        Paste Flutter web build output here
  SETUP.md
  USER_GUIDE.md
```
