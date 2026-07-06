import uuid

from tests.conftest import register_and_login


def player_payload(name: str = "Kid One") -> dict:
    return {
        "id": str(uuid.uuid4()),
        "name": name,
        "age": 12,
        "club": "North Shore BC",
        "playingStyle": "attacking",
        "preferredGrip": "forehand",
        "shortTermGoal": "Sharper net kills",
        "longTermGoal": "Regional top 8",
        "photoPath": None,
    }


def test_all_player_routes_require_auth(client):
    assert client.get("/api/v1/players").status_code == 401
    assert client.post("/api/v1/players", json=player_payload()).status_code == 401
    assert client.put("/api/v1/players/x", json=player_payload()).status_code == 401
    assert client.delete("/api/v1/players/x").status_code == 401


def test_create_player_with_client_uuid_and_list(client, auth_headers):
    payload = player_payload()

    created = client.post("/api/v1/players", json=payload, headers=auth_headers)
    listed = client.get("/api/v1/players", headers=auth_headers)

    assert created.status_code == 201
    assert created.json()["id"] == payload["id"]
    assert created.json()["name"] == "Kid One"
    assert [p["id"] for p in listed.json()] == [payload["id"]]


def test_create_player_requires_name(client, auth_headers):
    bad = player_payload()
    bad["name"] = ""

    resp = client.post("/api/v1/players", json=bad, headers=auth_headers)

    assert resp.status_code == 422


def test_list_returns_only_own_players(client, auth_headers):
    other_headers = register_and_login(client, email="other@example.com")
    mine = player_payload("Mine")
    theirs = player_payload("Theirs")
    client.post("/api/v1/players", json=mine, headers=auth_headers)
    client.post("/api/v1/players", json=theirs, headers=other_headers)

    listed = client.get("/api/v1/players", headers=auth_headers)

    names = [p["name"] for p in listed.json()]
    assert names == ["Mine"]


def test_update_player_fields(client, auth_headers):
    payload = player_payload()
    client.post("/api/v1/players", json=payload, headers=auth_headers)
    payload["club"] = "West End BC"
    payload["shortTermGoal"] = "Steeper smashes"

    resp = client.put(
        f"/api/v1/players/{payload['id']}", json=payload, headers=auth_headers
    )

    assert resp.status_code == 200
    listed = client.get("/api/v1/players", headers=auth_headers).json()
    assert listed[0]["club"] == "West End BC"
    assert listed[0]["shortTermGoal"] == "Steeper smashes"


def test_delete_player_cascades_all_data(client, auth_headers, settings):
    import sqlite3

    payload = player_payload()
    pid = payload["id"]
    client.post("/api/v1/players", json=payload, headers=auth_headers)
    # Seed one row into every child table directly.
    conn = sqlite3.connect(settings.db_path)
    conn.execute("PRAGMA foreign_keys = ON")
    conn.execute(
        "INSERT INTO sessions (id, playerId, date, durationMinutes, drills) "
        "VALUES ('s1', ?, '2026-07-01', 60, '[\"Smash\"]')",
        (pid,),
    )
    conn.execute(
        "INSERT INTO tournaments (id, playerId, name, date, location, format) "
        "VALUES ('t1', ?, 'Regional', '2026-06-01', 'Auckland', 'Knockout')",
        (pid,),
    )
    conn.execute(
        "INSERT INTO matches (id, tournamentId, opponent, scores, isWin) "
        "VALUES ('m1', 't1', 'Rival', '21-15', 1)"
    )
    conn.execute(
        "INSERT INTO custom_tags (playerId, name) VALUES (?, 'Deception')", (pid,)
    )
    conn.commit()

    resp = client.delete(f"/api/v1/players/{pid}", headers=auth_headers)

    assert resp.status_code == 204
    for table in ("sessions", "tournaments", "matches", "custom_tags", "players"):
        count = conn.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
        assert count == 0, f"{table} must be empty after player delete"
    conn.close()


def test_delete_other_accounts_player_404(client, auth_headers):
    other_headers = register_and_login(client, email="other@example.com")
    theirs = player_payload("Theirs")
    client.post("/api/v1/players", json=theirs, headers=other_headers)

    resp = client.delete(f"/api/v1/players/{theirs['id']}", headers=auth_headers)

    assert resp.status_code == 404
    still_there = client.get("/api/v1/players", headers=other_headers).json()
    assert len(still_there) == 1


def test_update_other_accounts_player_404(client, auth_headers):
    other_headers = register_and_login(client, email="other@example.com")
    theirs = player_payload("Theirs")
    client.post("/api/v1/players", json=theirs, headers=other_headers)

    resp = client.put(
        f"/api/v1/players/{theirs['id']}", json=theirs, headers=auth_headers
    )

    assert resp.status_code == 404, "no existence leak across accounts"
