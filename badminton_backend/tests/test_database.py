import sqlite3

from app.database import get_conn, init_db
from app.settings import Settings

EXPECTED_TABLES = {
    "accounts",
    "players",
    "sessions",
    "tournaments",
    "matches",
    "custom_tags",
}


def settings_for(tmp_path) -> Settings:
    return Settings(db_path=str(tmp_path / "test.db"), jwt_secret="test-secret")


def test_init_db_creates_all_tables(tmp_path):
    settings = settings_for(tmp_path)

    init_db(settings)

    conn = sqlite3.connect(settings.db_path)
    names = {
        row[0]
        for row in conn.execute(
            "SELECT name FROM sqlite_master WHERE type='table'"
        )
    }
    conn.close()
    assert EXPECTED_TABLES <= names


def test_connections_enforce_foreign_keys(tmp_path):
    settings = settings_for(tmp_path)
    init_db(settings)

    with get_conn(settings) as conn:
        assert conn.execute("PRAGMA foreign_keys").fetchone()[0] == 1


def test_sessions_schema_matches_current_flutter_columns(tmp_path):
    settings = settings_for(tmp_path)
    init_db(settings)

    with get_conn(settings) as conn:
        cols = {row[1]: row for row in conn.execute("PRAGMA table_info(sessions)")}

    # Part-A columns must exist; intensity must be nullable (notnull == 0).
    for col in (
        "sessionGoal",
        "goalAchievementScore",
        "playerRemarks",
        "coachRemarks",
        "reflectionAnswersJson",
    ):
        assert col in cols, f"sessions missing Part-A column {col}"
    assert cols["intensity"][3] == 0, "intensity must be nullable"
    assert "playerId" in cols


def test_matches_cascade_delete_with_tournament(tmp_path):
    settings = settings_for(tmp_path)
    init_db(settings)

    with get_conn(settings) as conn:
        conn.execute(
            "INSERT INTO accounts (id, email, password_hash, created_at) "
            "VALUES ('a1', 'a@b.c', 'x', 'now')"
        )
        conn.execute(
            "INSERT INTO players (id, accountId, name) VALUES ('p1', 'a1', 'Kid')"
        )
        conn.execute(
            "INSERT INTO tournaments (id, playerId, name, date, location, format) "
            "VALUES ('t1', 'p1', 'Regional', '2026-06-01', 'Auckland', 'Knockout')"
        )
        conn.execute(
            "INSERT INTO matches (id, tournamentId, opponent, scores, isWin) "
            "VALUES ('m1', 't1', 'Rival', '21-15', 1)"
        )
        conn.execute("DELETE FROM tournaments WHERE id = 't1'")
        orphans = conn.execute(
            "SELECT COUNT(*) FROM matches WHERE tournamentId = 't1'"
        ).fetchone()[0]

    assert orphans == 0, "matches must cascade-delete with their tournament"


def test_settings_require_secret_outside_dev(tmp_path, monkeypatch):
    import pytest

    from app.settings import Settings

    monkeypatch.delenv("JWT_SECRET", raising=False)
    with pytest.raises(RuntimeError, match="JWT_SECRET"):
        Settings.from_env(dev=False)
