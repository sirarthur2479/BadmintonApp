"""SQLite schema and connections.

Column names deliberately mirror the Flutter models' toMap() keys
(camelCase) so payloads pass through without translation. The sessions
schema matches the app's schema v2 (TASK-008): drills is a JSON-array
string, intensity is nullable, and the Part-A goal/reflection columns exist.
"""

import sqlite3
from pathlib import Path

from .settings import Settings

_SCHEMA = """
CREATE TABLE IF NOT EXISTS accounts (
    id TEXT PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS players (
    id TEXT PRIMARY KEY,
    accountId TEXT NOT NULL REFERENCES accounts (id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    age INTEGER,
    club TEXT NOT NULL DEFAULT '',
    playingStyle TEXT NOT NULL DEFAULT '',
    preferredGrip TEXT NOT NULL DEFAULT '',
    shortTermGoal TEXT NOT NULL DEFAULT '',
    longTermGoal TEXT NOT NULL DEFAULT '',
    photoPath TEXT
);
CREATE TABLE IF NOT EXISTS sessions (
    id TEXT PRIMARY KEY,
    playerId TEXT NOT NULL REFERENCES players (id) ON DELETE CASCADE,
    date TEXT NOT NULL,
    durationMinutes INTEGER NOT NULL,
    drills TEXT NOT NULL,
    intensity INTEGER,
    notes TEXT NOT NULL DEFAULT '',
    photoPath TEXT,
    sessionGoal TEXT NOT NULL DEFAULT '',
    goalAchievementScore INTEGER NOT NULL DEFAULT 3,
    playerRemarks TEXT NOT NULL DEFAULT '',
    coachRemarks TEXT NOT NULL DEFAULT '',
    reflectionAnswersJson TEXT NOT NULL DEFAULT '[]'
);
CREATE TABLE IF NOT EXISTS tournaments (
    id TEXT PRIMARY KEY,
    playerId TEXT NOT NULL REFERENCES players (id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    date TEXT NOT NULL,
    location TEXT NOT NULL,
    format TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS matches (
    id TEXT PRIMARY KEY,
    tournamentId TEXT NOT NULL REFERENCES tournaments (id) ON DELETE CASCADE,
    opponent TEXT NOT NULL,
    scores TEXT NOT NULL,
    isWin INTEGER NOT NULL,
    notes TEXT
);
CREATE TABLE IF NOT EXISTS match_logs (
    id TEXT PRIMARY KEY,
    playerId TEXT NOT NULL REFERENCES players (id) ON DELETE CASCADE,
    date TEXT NOT NULL,
    opponent TEXT NOT NULL,
    eventContext TEXT NOT NULL DEFAULT '',
    scores TEXT NOT NULL DEFAULT '',
    isWin INTEGER NOT NULL,
    gameplan TEXT NOT NULL DEFAULT '',
    readinessScore INTEGER NOT NULL DEFAULT 3,
    performanceNotes TEXT NOT NULL DEFAULT '',
    keyMoments TEXT NOT NULL DEFAULT '',
    videoRef TEXT
);
CREATE TABLE IF NOT EXISTS uploads (
    id TEXT PRIMARY KEY,
    accountId TEXT NOT NULL REFERENCES accounts (id) ON DELETE CASCADE,
    playerId TEXT NOT NULL REFERENCES players (id) ON DELETE CASCADE,
    sessionId TEXT NOT NULL,
    mode TEXT NOT NULL,
    filename TEXT NOT NULL,
    total_bytes INTEGER NOT NULL,
    offset_bytes INTEGER NOT NULL DEFAULT 0,
    storage_path TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'in_progress',
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS jobs (
    id TEXT PRIMARY KEY,
    playerId TEXT NOT NULL REFERENCES players (id) ON DELETE CASCADE,
    sessionId TEXT NOT NULL,
    videoPath TEXT NOT NULL,
    mode TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'queued',
    reportPath TEXT,
    courtMapPath TEXT,
    errorMessage TEXT,
    createdAt TEXT NOT NULL,
    startedAt TEXT,
    finishedAt TEXT
);
CREATE TABLE IF NOT EXISTS custom_tags (
    playerId TEXT NOT NULL REFERENCES players (id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    PRIMARY KEY (playerId, name)
);
"""


def get_conn(settings: Settings) -> sqlite3.Connection:
    """A connection with rows-as-dicts and foreign keys ON (sqlite defaults off)."""
    conn = sqlite3.connect(settings.db_path)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def init_db(settings: Settings) -> None:
    Path(settings.db_path).parent.mkdir(parents=True, exist_ok=True)
    with get_conn(settings) as conn:
        conn.executescript(_SCHEMA)
