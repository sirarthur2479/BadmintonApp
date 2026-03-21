# Self-Hosting Setup & Operations Guide

## Prerequisites

- A computer running Linux, macOS, or Windows with WSL2
- [Docker](https://docs.docker.com/get-docker/) and [Docker Compose](https://docs.docker.com/compose/install/) installed
- A free [Cloudflare](https://cloudflare.com) account and a domain managed by Cloudflare

---

## Directory Structure

Create the following on your server:

```
~/badminton/
  docker-compose.yml
  nginx/
    nginx.conf
  backend/
    app/
      main.py
      database.py
      auth.py
      models.py
      routers/
        auth.py
        players.py
        sessions.py
        tournaments.py
    Dockerfile
    requirements.txt
  flutter-web/        ← paste Flutter web build output here
  data/               ← SQLite database lives here (auto-created)
```

---

## Step 1: Build the Flutter Web App

On your development machine:

```bash
flutter build web --dart-define=API_BASE_URL=https://badminton.yourdomain.com/api/v1
```

Copy the output to the server:
```bash
rsync -av build/web/ user@your-server:~/badminton/flutter-web/
```

---

## Step 2: Start the Server

```bash
cd ~/badminton
docker-compose up -d
```

Verify it's running:
```bash
docker-compose ps
docker-compose logs -f backend
```

Test the API locally:
```
http://localhost:8000/docs
```

Test the web app locally:
```
http://localhost
```

---

## Step 3: Set Up Cloudflare Tunnel

This exposes the app to the internet without port forwarding, without exposing your home IP, and with automatic HTTPS.

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
```
https://badminton.yourdomain.com
```

---

## Step 4: First-Time App Setup

1. Open the app in a browser
2. Click **Register** to create your account
3. Add your first player (e.g. your name, or a child's name)
4. Add more players to the same account as needed (family members)

---

## Migrating to a New Server

SQLite is a single file — migration is a straightforward copy.

### 1. Stop the backend on the old machine
```bash
cd ~/badminton
docker-compose stop backend
```
Stop before copying to ensure no writes are in-flight.

### 2. Copy the database to the new machine
```bash
# From the old machine:
scp ~/badminton/data/badminton.db user@new-server:~/badminton/data/badminton.db
```

Or copy via USB/network share if both machines are on the same LAN.

### 3. Copy the project files
```bash
scp -r ~/badminton/ user@new-server:~/badminton/
```

### 4. Start on the new machine
```bash
cd ~/badminton
docker-compose up -d
```

### 5. Re-install Cloudflare Tunnel on the new machine

The tunnel ID and domain stay the same — just install `cloudflared` and copy the config:
```bash
scp ~/.cloudflared/ user@new-server:~/.cloudflared/
sudo cloudflared service install
sudo systemctl enable cloudflared
sudo systemctl start cloudflared
```

### What transfers
| Data | How |
|---|---|
| All accounts, players, sessions, tournaments | `data/badminton.db` — one file |
| App config and backend code | The `~/badminton/` folder |
| Flutter web build | `flutter-web/` folder inside the project |
| Cloudflare tunnel | Re-install `cloudflared` + copy `~/.cloudflared/` config |

Nothing is tied to a specific machine.

---

## Backup

Since all data is a single file, backup is simple:

```bash
# Manual backup
cp ~/badminton/data/badminton.db ~/badminton/data/badminton.db.$(date +%Y%m%d)

# Automated daily backup via cron
# Run: crontab -e  and add:
0 2 * * * cp ~/badminton/data/badminton.db ~/badminton/data/backups/badminton.db.$(date +\%Y\%m\%d)
```

---

## Useful Commands

```bash
# View running containers
docker-compose ps

# View backend logs
docker-compose logs -f backend

# Restart everything
docker-compose restart

# Stop everything
docker-compose down

# Rebuild after backend code changes
docker-compose up -d --build backend

# Check Cloudflare tunnel status
sudo systemctl status cloudflared
cloudflared tunnel info badminton-app
```
