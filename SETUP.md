# BadmintonApp — Setup & Start Guide

## Prerequisites

| Tool | Purpose | Install |
|------|---------|---------|
| Flutter SDK (≥ 3.11) | Build and run the app | https://docs.flutter.dev/get-started/install |
| Docker Desktop | Run the backend server (must be **running** before any docker-compose command) | https://docs.docker.com/get-docker/ |
| Git | Version control | https://git-scm.com |

Optional (production only):
- A domain managed by Cloudflare (for internet access)
- `cloudflared` CLI (Cloudflare Tunnel)

---

## Option A — Mobile App (no backend needed)

The mobile app stores all data locally on-device. No server setup required.

```bash
cd badminton_flutter
flutter pub get
flutter run          # connects to a plugged-in device or simulator
```

To pick a specific device:
```bash
flutter devices      # list available devices
flutter run -d <device-id>
```

---

## Option A2 — Laptop App (desktop, no backend, no internet)

Runs the same offline-first app as mobile, on the laptop's big screen —
best for tagging match points (side-by-side video + tag panel) and for
reviewing opponent profiles. No server or internet needed; data lives in a
local database exactly like on the phone.

```bash
cd badminton_flutter
flutter pub get
flutter run -d macos        # the primary laptop target
```

Notes:
- macOS supports everything, including video playback for point tagging.
  Copy the match video onto the laptop (AirDrop works) and pick it with
  the "Choose video" button on the match log.
- `flutter run -d linux` / `-d windows` also work for data entry and
  stats, but the official video plugin has no Linux/Windows backend, so
  the tagging screen shows a placeholder instead of the video there.
- The tactical brief's AI narrative needs the analysis server + Ollama
  (Option B/C); without them the app shows the metrics-only brief.

## Option B — Web App (local, with backend)

### Step 1 — Start Docker Desktop

Open **Docker Desktop** from the Start menu and wait until the whale icon in the system tray stops animating. The engine must be running before any `docker-compose` command will work.

### Step 2 — Start the backend

```bash
cd badminton-server
docker-compose up -d
```

Verify it's running:
```bash
docker-compose ps
docker-compose logs -f backend
```

API docs available at: `http://localhost:8000/docs`

### Step 3 — Run Flutter web locally

```powershell
cd badminton_flutter
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000/api/v1
```

The app opens at `http://localhost` in Chrome with hot-reload enabled.

### Stopping the backend

```bash
cd badminton-server
docker-compose down
```

---

## Option C — Production (self-hosted + internet access)

### Step 1 — Build Flutter web for production

```powershell
cd badminton_flutter
flutter build web --dart-define=API_BASE_URL=https://badminton.yourdomain.com/api/v1
```

### Step 2 — Copy web build to the server

```bash
rsync -av build/web/ user@your-server:~/badminton/flutter-web/
```

### Step 3 — Start the server

```bash
ssh user@your-server
cd ~/badminton
docker-compose up -d
```

### Step 4 — Set up Cloudflare Tunnel (one-time)

```bash
# On the server:
cloudflared tunnel login
cloudflared tunnel create badminton-app
cloudflared tunnel route dns badminton-app badminton.yourdomain.com

# Create ~/.cloudflared/config.yml:
tunnel: <tunnel-id>
credentials-file: /root/.cloudflared/<tunnel-id>.json
ingress:
  - hostname: badminton.yourdomain.com
    service: http://localhost:80
  - service: http_status:404

sudo cloudflared service install
sudo systemctl enable cloudflared
sudo systemctl start cloudflared
```

Access the app at: `https://badminton.yourdomain.com`

---

## Local Network Access

To open the web app from any device on the same WiFi (phone, tablet, another PC):

```powershell
# 1. Find your WiFi IP
ipconfig
# Look for: "Wireless LAN adapter Wi-Fi" → "IPv4 Address" e.g. 192.168.1.42

# 2. Start the backend (if not already running)
cd badminton-server
docker-compose up -d

# 3. Run Flutter web bound to all interfaces
cd badminton_flutter
flutter run -d chrome --web-hostname 0.0.0.0 --web-port 8080 --dart-define=API_BASE_URL=http://192.168.1.42:8000/api/v1
```

Other devices on the same WiFi open: `http://192.168.1.42:8080`

> Replace `192.168.1.42` with your actual WiFi IP from `ipconfig`.

### Verify the backend is working

```powershell
cd c:\Source\BadmintonApp
pip install httpx   # one-time
python scripts/test_flow.py

# Against a remote IP:
python scripts/test_flow.py --base http://192.168.1.42:8000/api/v1
```

The script logs in as `coach@local`, creates a test session and match log, verifies pagination and GZip, then deletes the test data.

---

## First-Time App Setup (Web)

1. Open the app in a browser
2. Log in with the pre-seeded local account: **coach@local** / **badminton**
3. Your default player profile is created automatically
4. Start logging training sessions and match results

---

## Backend Environment Variables

Set these in `badminton-server/docker-compose.yml` under the `backend` service:

| Variable | Default | Description |
|----------|---------|-------------|
| `DB_PATH` | `/data/badminton.db` | SQLite file location inside the container |
| `JWT_SECRET` | *(must set)* | Random secret for signing JWT tokens — change before going live |
| `JWT_EXPIRE_DAYS` | `30` | How many days before a login token expires |

Example:
```yaml
environment:
  - DB_PATH=/data/badminton.db
  - JWT_SECRET=change-this-to-a-long-random-string
  - JWT_EXPIRE_DAYS=30
```

---

## Useful Commands

```bash
# View running containers
docker-compose ps

# Tail backend logs
docker-compose logs -f backend

# Restart backend after a code change
docker-compose up -d --build backend

# Rebuild everything
docker-compose down && docker-compose up -d --build

# Check Cloudflare tunnel status
sudo systemctl status cloudflared
cloudflared tunnel info badminton-app
```

---

## Backup & Migration

All data is a single SQLite file. Stop the backend before copying to avoid partial writes.

```bash
# Manual backup
cp ~/badminton/data/badminton.db \
   ~/badminton/data/backups/badminton.db.$(date +%Y%m%d)

# Automated daily backup (add to crontab -e)
0 2 * * * cp ~/badminton/data/badminton.db \
            ~/badminton/data/backups/badminton.db.$(date +\%Y\%m\%d)
```

To migrate to a new server, copy `~/badminton/data/badminton.db` and the `~/badminton/` project folder. Re-install `cloudflared` with the same config — the tunnel ID and domain stay the same.

---

## Adding YouTube Videos to the Technique Library

Each technique has a commented-out `videoUrl` line in:
```
badminton_flutter/lib/data/techniques_seed.dart
```

### Automated (recommended)

No API key needed — uses `yt-dlp` to search YouTube directly.

```powershell
cd c:\Source\BadmintonApp
python -m pip install yt-dlp   # one-time
python scripts/find_videos.py
```

The script searches YouTube for each technique's TODO query, picks the top result, and patches the dart file in-place. Already-set entries are skipped.

Preview without writing:
```powershell
python scripts/find_videos.py --dry-run
```

### Manual

1. Search YouTube using the `TODO` comment as the search query
2. Copy the 11-character video ID from the URL: `youtube.com/watch?v=XXXXXXXXXXX`
3. Uncomment the `videoUrl` line and replace `XXXXXXXXXXX` with the real ID
4. Add `// verified YYYY-MM-DD` as a note
5. Hot-reload or rebuild the app

```dart
videoUrl: 'qz9y5YPDYH4', // Badminton Insight — How To Smash, verified 2026-03-24
```
