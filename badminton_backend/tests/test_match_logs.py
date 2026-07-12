import pytest

from tests.conftest import register_and_login
from tests.test_players import player_payload

# A payload exactly as the Flutter MatchLog.toMap() emits it (TASK-035):
# isWin is a 0/1 int, date an ISO-8601 string, videoRef nullable.
FLUTTER_MATCH_LOG = {
    "id": "matchlog-1",
    "date": "2026-07-12T14:30:00.000",
    "opponent": "Ken T.",
    "eventContext": "League round 3",
    "scores": "21-15, 18-21, 21-19",
    "isWin": 1,
    "gameplan": "Attack the backhand, keep rallies short",
    "readinessScore": 4,
    "performanceNotes": "Smash landed; net play broke down in game 2",
    "keyMoments": "Saved 2 game points at 18-20 in the decider",
    "videoRef": "/videos/league-r3.mp4",
}


@pytest.fixture()
def player(client, auth_headers) -> str:
    payload = player_payload()
    client.post("/api/v1/players", json=payload, headers=auth_headers)
    return payload["id"]


def url(pid: str, suffix: str = "") -> str:
    return f"/api/v1/players/{pid}/match-logs{suffix}"


def log_payload(**overrides) -> dict:
    return dict(FLUTTER_MATCH_LOG, **overrides)


def test_match_log_flutter_map_round_trips_verbatim(client, auth_headers, player):
    created = client.post(url(player), json=FLUTTER_MATCH_LOG, headers=auth_headers)
    listed = client.get(url(player), headers=auth_headers)

    assert created.status_code == 201
    assert listed.json() == [FLUTTER_MATCH_LOG], "key-for-key round trip"


def test_list_is_ordered_by_date_desc(client, auth_headers, player):
    older = log_payload(id="matchlog-old", date="2026-07-01T10:00:00.000")
    newer = log_payload(id="matchlog-new", date="2026-07-10T10:00:00.000")

    client.post(url(player), json=older, headers=auth_headers)
    client.post(url(player), json=newer, headers=auth_headers)

    ids = [log["id"] for log in client.get(url(player), headers=auth_headers).json()]
    assert ids == ["matchlog-new", "matchlog-old"]


def test_any_reports_presence_of_logs(client, auth_headers, player):
    before = client.get(url(player, "/any"), headers=auth_headers).json()
    client.post(url(player), json=FLUTTER_MATCH_LOG, headers=auth_headers)
    after = client.get(url(player, "/any"), headers=auth_headers).json()

    assert before == {"any": False}
    assert after == {"any": True}
