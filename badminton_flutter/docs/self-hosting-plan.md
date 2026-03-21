# Plan: Self-Host Flutter Web App at Home (Multi-User)

## Context
The app is currently a fully offline Flutter app (mobile + web). The web version uses in-memory arrays — data is lost on every refresh. The goal is to self-host at home (no cloud cost) with persistent storage, JWT-based login, and an **Account → Players** hierarchy so one login can manage multiple players (e.g. a parent with two kids).

## Architecture Overview

```
Internet → Cloudflare Tunnel → nginx (port 80) → Flutter web static files
                                                 → FastAPI backend (/api/)
                                                      → SQLite (badminton.db)
                                                           accounts
                                                           players
                                                           sessions (per player)
                                                           tournaments (per player)
                                                           matches
```

---

## Data Model

```
accounts (login credentials)
  id, email, password_hash, created_at

players (one account → many players)
  id, accountId FK, name, age, club, playingStyle,
  preferredGrip, shortTermGoal, longTermGoal, photoPath

sessions      → playerId FK
tournaments   → playerId FK
matches       → tournamentId FK (cascade delete)
```

One account = one login. One account can have multiple players (e.g. parent + 2 kids). All data (sessions, tournaments) is scoped to a `playerId`, not an account.

---

## Phase 1: Backend API (Python + FastAPI + SQLite)

**Directory structure (outside Flutter project):**
```
~/badminton/
  docker-compose.yml
  nginx/nginx.conf
  backend/
    app/main.py          # FastAPI app, CORS, startup
    app/database.py      # schema creation, connection
    app/auth.py          # JWT encode/decode, password hashing
    app/models.py        # Pydantic request/response models
    app/routers/
      auth.py            # /auth/register, /auth/login
      players.py         # CRUD for players under the account
      sessions.py
      tournaments.py
    Dockerfile
    requirements.txt
  flutter-web/           ← Flutter build output
  data/badminton.db      ← auto-created on first run
```

**`requirements.txt`:**
```
fastapi==0.111.0
uvicorn[standard]==0.29.0
python-jose[cryptography]==3.3.0   # JWT
passlib[bcrypt]==1.7.4             # password hashing
```

### Auth endpoints
```
POST /api/v1/auth/register    body: {email, password} → {id, email}
POST /api/v1/auth/login       body: {email, password} → {access_token, token_type}
```

JWT payload: `{ "sub": accountId, "exp": ... }`. Token expiry: 30 days (personal app — long expiry is fine, avoids constant re-login).

All non-auth endpoints require `Authorization: Bearer <token>` header. FastAPI dependency extracts `accountId` from token automatically.

### Player endpoints
```
GET    /api/v1/players                  → list players for this account
POST   /api/v1/players                  → create player
PUT    /api/v1/players/{id}             → update player
DELETE /api/v1/players/{id}             → delete player + cascade all their data
```

### Data endpoints (all scoped to a playerId, verified to belong to the account)
```
GET/POST       /api/v1/players/{playerId}/sessions
DELETE         /api/v1/players/{playerId}/sessions/{id}
GET            /api/v1/players/{playerId}/sessions/any
POST           /api/v1/players/{playerId}/sessions/batch

GET/POST       /api/v1/players/{playerId}/tournaments
DELETE         /api/v1/players/{playerId}/tournaments/{id}
POST           /api/v1/players/{playerId}/tournaments/{id}/matches
DELETE         /api/v1/players/{playerId}/tournaments/{id}/matches/{mid}
```

**Security:** Backend always verifies `players.accountId == JWT accountId` before returning or mutating data. A user cannot access another account's player data even if they guess a playerId UUID.

**Critical serialization details** (must match Flutter `fromMap()` exactly):
- `drills` is comma-delimited: `"Footwork,Smash"`
- `scores` is pipe-delimited: `"21-15|21-18"`
- `isWin` is integer `0` or `1`
- All IDs are client-generated UUIDs

---

## Phase 2: New Flutter Screens

### New screens to create
- `lib/screens/auth/login_screen.dart` — email + password form; on success stores JWT, navigates to player select
- `lib/screens/auth/register_screen.dart` — create account form
- `lib/screens/player/player_select_screen.dart` — grid of player cards for the account; "Add Player" button; tap to select active player

### New providers/services to create
- `lib/providers/auth_provider.dart` — holds JWT token, accountId; `login()`, `logout()`, `register()`; persists token to `localStorage` (web) / `flutter_secure_storage` (mobile)
- `lib/providers/player_provider.dart` — holds list of players for account + `activePlayer`; `switchPlayer(id)`

### Modified files
- `lib/app.dart` — add auth gate: check `AuthProvider.isLoggedIn` + `PlayerProvider.activePlayer` on startup; route to login → player select → main app shell
- `lib/services/api_service.dart` — new file; all HTTP calls; injects JWT header from `AuthProvider`; uses `playerId`-scoped URLs
- `lib/services/database_service.dart` — replace `if (kIsWeb)` branches to delegate to `ApiService`; remove in-memory static lists
- `lib/services/storage_service.dart` — web profile reads/writes go through `ApiService` (player update endpoint)
- `lib/providers/session_provider.dart` — pass `activePlayerId` to all API calls
- `lib/providers/tournament_provider.dart` — same
- `pubspec.yaml` — add `http: ^1.2.0`, `flutter_secure_storage: ^9.0.0`

### App startup flow
```
App launch
  → AuthProvider checks stored JWT
      → No token / expired → LoginScreen
      → Valid token → PlayerProvider.loadPlayers()
          → 0 players → PlayerSelectScreen (add first player)
          → 1+ players → PlayerSelectScreen (or auto-select if only one)
              → tap player → main app shell (Home/Train/Learn/Profile tabs)
```

### Player switcher UI
Add a player avatar/name button in the app bar or profile tab. Tapping it returns to `PlayerSelectScreen` without logging out.

---

## Phase 3: Docker Compose

```yaml
services:
  backend:
    build: ./backend
    restart: unless-stopped
    volumes:
      - ./data:/data          # SQLite at /data/badminton.db
    environment:
      - DB_PATH=/data/badminton.db
      - JWT_SECRET=<random-secret-change-this>
      - JWT_EXPIRE_DAYS=30
    expose:
      - "8000"

  web:
    image: nginx:alpine
    restart: unless-stopped
    ports:
      - "80:80"
    volumes:
      - ./flutter-web:/usr/share/nginx/html:ro
      - ./nginx/nginx.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      - backend
```

**`nginx.conf` key rules:**
- `location /api/` → `proxy_pass http://backend:8000`
- `location /` → `try_files $uri $uri/ /index.html` (required for Flutter SPA routing)

---

## Phase 4: Internet Exposure via Cloudflare Tunnel (Free)

**Why not port forwarding:** No router config, home IP never in DNS, HTTPS automatic, free.

**Setup:**
1. Register domain on Cloudflare (free DNS)
2. Install `cloudflared` on home server
3. `cloudflared tunnel login` → `cloudflared tunnel create badminton-app`
4. Config at `~/.cloudflared/config.yml`: point tunnel to `http://localhost:80`
5. `cloudflared tunnel route dns badminton-app badminton.yourdomain.com`
6. `sudo cloudflared service install && sudo systemctl enable cloudflared`

**Note:** With JWT auth built into the app, Cloudflare Access is no longer required (the app handles its own login). Cloudflare Tunnel still provides HTTPS and hides your home IP.

**Build command for production:**
```bash
flutter build web --dart-define=API_BASE_URL=https://badminton.yourdomain.com/api/v1
```

---

## Implementation Order

1. **Backend auth + players** — register/login endpoints, JWT middleware, players CRUD; test with `http://localhost:8000/docs`
2. **Backend data endpoints** — sessions, tournaments scoped to playerId; test with curl using a real JWT
3. **Flutter auth screens** — login, register, JWT storage; test against local backend
4. **Flutter player select** — player list screen, active player state, player switcher
5. **Flutter data layer** — `api_service.dart`, update `database_service.dart` web branches, thread `activePlayerId` through providers
6. **Docker Compose** — containerize, test locally at `http://localhost`
7. **Home server + Cloudflare Tunnel** — deploy, rebuild Flutter web with production URL, test from mobile network

---

## Verification

- Register account → add 2 players → log sessions for each → switch player → correct sessions shown
- Login from two different browsers simultaneously with the same account → both see same data
- Register second account → cannot see first account's players or data
- Refresh browser → still logged in (JWT persisted), active player remembered
- Access from phone on mobile data → confirms tunnel working
- `docker-compose down && docker-compose up` → all data survives (SQLite volume persisted)

---

## Trade-offs / Decisions

- **Account → Players model**: Separates authentication (account) from training identity (player). Allows family sharing without multiple email addresses, while keeping all data isolated per player.
- **30-day JWT expiry**: Personal app — long expiry avoids friction. Logout button available if device is shared.
- **playerId in URL path** (`/players/{playerId}/sessions`): Explicit scoping makes backend authorization checks straightforward and the API self-documenting.
- **Mobile unchanged**: `kIsWeb` branching keeps mobile on local SQLite/SharedPreferences. Mobile offline-first is unaffected.
- **SQLite stays**: Still appropriate — multiple players and multiple accounts do not change the scale. Backup remains a single file copy.
- **No Cloudflare Access needed**: JWT auth in the app is the right layer. Cloudflare Tunnel is still used for HTTPS and IP privacy.
