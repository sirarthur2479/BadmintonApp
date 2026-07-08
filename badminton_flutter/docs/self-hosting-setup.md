# Self-Hosting Setup & Operations Guide

The backend source lives in this monorepo at **`badminton_backend/`**
(FastAPI + SQLite + JWT; spec in `ideas/use-cases/self-hosted-backend.md`).
This guide covers building the web app, deploying both to a home server via
Docker Compose, and exposing them with a Cloudflare Tunnel.

Auth stack note: the API signs JWTs with **PyJWT** and hashes passwords
with **pwdlib** (Argon2id). Older drafts of this plan pinned two JWT/hashing
libraries that are now vulnerable / unmaintained — never reintroduce them;
the rationale and the banned names live in `research/fastapi-auth.md`.

## Prerequisites

- A computer running Linux, macOS, or Windows with WSL2
- [Docker](https://docs.docker.com/get-docker/) with the Compose plugin
- A free [Cloudflare](https://cloudflare.com) account and a domain managed
  by Cloudflare (only needed for internet access; LAN-only works without it)

---

## Server Layout

```
~/badminton/badminton_backend/     ← copy of the monorepo directory
  Dockerfile
  pyproject.toml                   # fastapi / uvicorn / pyjwt / pwdlib[argon2]
  app/                             # API source
  deploy/
    docker-compose.yml
    nginx/nginx.conf
    .env                           # from .env.example, holds the real JWT_SECRET
    flutter-web/                   ← Flutter web build output goes here
    data/                          ← SQLite lives here (auto-created; BACK THIS UP)
```

---

## Step 1: Build the Flutter Web App

On your development machine, from `badminton_flutter/`:

```bash
flutter build web --dart-define=API_BASE_URL=https://badminton.yourdomain.com/api/v1
```

(For LAN-only use, point at the server's LAN address instead, e.g.
`http://192.168.1.50/api/v1`.)

## Step 2: Copy to the Server

```bash
rsync -av badminton_backend/ user@your-server:~/badminton/badminton_backend/
rsync -av badminton_flutter/build/web/ \
      user@your-server:~/badminton/badminton_backend/deploy/flutter-web/
```

## Step 3: Configure the Secret

On the server:

```bash
cd ~/badminton/badminton_backend/deploy
cp .env.example .env
python3 -c "import secrets; print(secrets.token_hex(32))"   # paste into .env
```

`.env` never leaves the server and is never committed.

## Step 4: Start the Server

```bash
cd ~/badminton/badminton_backend/deploy
docker compose up -d --build
```

Verify:
```bash
docker compose ps
docker compose logs -f backend
```

Test locally: `http://localhost` (web app), and the API responds under
`http://localhost/api/v1/...`.

---

## Step 5: Set Up Cloudflare Tunnel

Exposes the app to the internet without port forwarding, without exposing
your home IP, and with automatic HTTPS. JWT auth is built into the app, so
Cloudflare Access is not required.

```bash
# Install cloudflared (Debian/Ubuntu)
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o cloudflared.deb
sudo dpkg -i cloudflared.deb

# Authenticate with your Cloudflare account
cloudflared tunnel login

# Create the tunnel
cloudflared tunnel create badminton-app

# Create config at ~/.cloudflared/config.yml
tunnel: <tunnel-id-from-above>
credentials-file: /root/.cloudflared/<tunnel-id>.json
ingress:
  - hostname: badminton.yourdomain.com
    service: http://localhost:80
  - service: http_status:404

# Add DNS record
cloudflared tunnel route dns badminton-app badminton.yourdomain.com

# Install and start as a system service
sudo cloudflared service install
sudo systemctl enable cloudflared
sudo systemctl start cloudflared
```

Verify from outside your home network (e.g. mobile data):
`https://badminton.yourdomain.com`

---

## Step 6: First-Time App Setup

1. Open the app in a browser
2. Click **Register** to create your account
3. Add your first player (e.g. your name, or a child's name)
4. Add more players to the same account as needed (family members)
5. Refresh the browser — login and data must survive (they're on the server)

---

## Video Analysis (LAN-Only)

The mobile app can upload training videos to this server for automatic
analysis (BadmintonTrack pipeline: footwork/biomech + coach report). Two
things make this different from the rest of the setup:

**The ingest port never goes through the tunnel.** Footage of a minor must
stay on the home network, so video upload and job-status routes are used via
host port **8001** (`ports: "8001:8000"` in `docker-compose.yml`), and
`nginx.conf` explicitly returns 403 for `/api/v1/uploads` on the tunneled
hostname. In the app's settings screen, enter the server's LAN address —
e.g. `http://192.168.1.50:8001` — as the analysis server. Do not create a
public DNS record or tunnel route for this port.

**The analysis pipeline is an optional install.** The backend serves
accounts/players/data without it; analysis jobs will fail with an
actionable message until you install the pipeline next to the backend and
save a court calibration:

```bash
# In the backend's Python environment on the server:
pip install -e ../badminton_track   # plus its ML extras, see its README

# One-time court calibration (name it to match CALIBRATION_NAME):
badminton-track calibrate <sample-video.mp4> --name default
```

Environment knobs (set on the `backend` service in `docker-compose.yml`):

| Variable | Default | Meaning |
|---|---|---|
| `UPLOAD_DIR` | `/data/uploads` | where uploaded videos + reports land (inside the backed-up `./data` volume) |
| `CALIBRATION_NAME` | `default` | which saved court calibration footwork mode uses |
| `TRACK_CONFIG` | (defaults) | optional YAML overriding pipeline config |

Uploaded videos and analysis outputs live under `deploy/data/uploads/` —
they are part of the same "back up this one directory" story as the
database, and stay out of git like all other footage.

---

## Migrating to a New Server

SQLite is a single file — migration is a straightforward copy.

```bash
# 1. Stop the backend on the old machine (no in-flight writes)
cd ~/badminton/badminton_backend/deploy && docker compose stop backend

# 2. Copy the whole project (includes deploy/data/badminton.db and .env)
scp -r ~/badminton/ user@new-server:~/badminton/

# 3. Start on the new machine
cd ~/badminton/badminton_backend/deploy && docker compose up -d --build

# 4. Re-install cloudflared and copy ~/.cloudflared/ (tunnel id + domain stay)
scp -r ~/.cloudflared/ user@new-server:~/.cloudflared/
sudo cloudflared service install && sudo systemctl enable --now cloudflared
```

Nothing is tied to a specific machine.

---

## Backup

All data is one file:

```bash
# Manual backup
cp ~/badminton/badminton_backend/deploy/data/badminton.db \
   ~/badminton/backups/badminton.db.$(date +%Y%m%d)

# Automated daily backup via cron (crontab -e):
0 2 * * * cp ~/badminton/badminton_backend/deploy/data/badminton.db ~/badminton/backups/badminton.db.$(date +\%Y\%m\%d)
```

---

## Useful Commands

```bash
docker compose ps                      # running containers
docker compose logs -f backend         # backend logs
docker compose restart                 # restart everything
docker compose down                    # stop everything (data survives)
docker compose up -d --build backend   # rebuild after backend code changes
sudo systemctl status cloudflared      # tunnel status
cloudflared tunnel info badminton-app
```

---

## API Payload Notes (for anyone poking the API directly)

Payloads mirror the Flutter models' `toMap()` exactly:

- Session `drills` is a **JSON array** encoded as a string, e.g.
  `"[\"Footwork\",\"Multi-feed, front court\"]"` — this is what makes
  custom drill tags containing commas safe.
- Sessions carry the goal/reflection fields (`sessionGoal`,
  `goalAchievementScore`, `playerRemarks`, `coachRemarks`,
  `reflectionAnswersJson`); `intensity` is nullable (legacy rating).
- Match `scores` are pipe-delimited (`"21-15|21-18"`); `isWin` is `0`/`1`.
- All ids are client-generated UUID strings; dates are ISO-8601 strings.
