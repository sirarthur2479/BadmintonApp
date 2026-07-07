import pytest

from tests.conftest import register_and_login
from tests.test_players import player_payload

TOURNAMENT = {
    "id": "t-1",
    "name": "Regional U13",
    "date": "2026-06-01T00:00:00.000",
    "location": "Auckland",
    "format": "Knockout",
}

# Exactly as Flutter TournamentMatch.toMap() emits: pipe scores, isWin 0/1.
MATCH = {
    "id": "m-1",
    "tournamentId": "t-1",
    "opponent": "A. Rival",
    "scores": "21-15|21-18",
    "isWin": 1,
    "notes": None,
}


@pytest.fixture()
def player(client, auth_headers) -> str:
    payload = player_payload()
    client.post("/api/v1/players", json=payload, headers=auth_headers)
    return payload["id"]


def url(pid: str, suffix: str = "") -> str:
    return f"/api/v1/players/{pid}/tournaments{suffix}"


def test_tournament_with_nested_matches_round_trip(client, auth_headers, player):
    client.post(url(player), json=TOURNAMENT, headers=auth_headers)
    client.post(url(player, "/t-1/matches"), json=MATCH, headers=auth_headers)

    listed = client.get(url(player), headers=auth_headers).json()

    assert len(listed) == 1
    t = listed[0]
    assert {k: t[k] for k in TOURNAMENT} == TOURNAMENT
    assert t["matches"] == [MATCH], "pipe scores and isWin int must round-trip"


def test_tournaments_listed_date_desc(client, auth_headers, player):
    client.post(url(player), json=TOURNAMENT, headers=auth_headers)
    newer = dict(TOURNAMENT, id="t-2", date="2026-08-01T00:00:00.000")
    client.post(url(player), json=newer, headers=auth_headers)

    ids = [t["id"] for t in client.get(url(player), headers=auth_headers).json()]

    assert ids == ["t-2", "t-1"]


def test_delete_tournament_cascades_matches(client, auth_headers, player, settings):
    import sqlite3

    client.post(url(player), json=TOURNAMENT, headers=auth_headers)
    client.post(url(player, "/t-1/matches"), json=MATCH, headers=auth_headers)

    resp = client.delete(url(player, "/t-1"), headers=auth_headers)

    assert resp.status_code == 204
    conn = sqlite3.connect(settings.db_path)
    assert conn.execute("SELECT COUNT(*) FROM matches").fetchone()[0] == 0
    conn.close()


def test_delete_match_only(client, auth_headers, player):
    client.post(url(player), json=TOURNAMENT, headers=auth_headers)
    client.post(url(player, "/t-1/matches"), json=MATCH, headers=auth_headers)

    resp = client.delete(url(player, "/t-1/matches/m-1"), headers=auth_headers)

    assert resp.status_code == 204
    listed = client.get(url(player), headers=auth_headers).json()
    assert listed[0]["matches"] == []


def test_match_only_attaches_to_own_players_tournament(client, auth_headers, player):
    # The tournament belongs to ANOTHER account's player.
    other_headers = register_and_login(client, email="other@example.com")
    other_player = player_payload("Theirs")
    client.post("/api/v1/players", json=other_player, headers=other_headers)
    client.post(url(other_player["id"]), json=TOURNAMENT, headers=other_headers)

    # Caller tries to attach a match through their own player id but a
    # foreign tournament id.
    resp = client.post(
        url(player, "/t-1/matches"), json=MATCH, headers=auth_headers
    )

    assert resp.status_code == 404
