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


def test_post_same_id_replaces_row(client, auth_headers, player):
    client.post(url(player), json=FLUTTER_MATCH_LOG, headers=auth_headers)
    edited = log_payload(opponent="Ken T. (rematch)", isWin=0)
    client.post(url(player), json=edited, headers=auth_headers)

    listed = client.get(url(player), headers=auth_headers).json()
    assert listed == [edited]


def test_batch_insert_ignores_duplicates(client, auth_headers, player):
    client.post(url(player), json=FLUTTER_MATCH_LOG, headers=auth_headers)
    batch = [
        log_payload(opponent="SHOULD NOT REPLACE"),  # duplicate id, ignored
        log_payload(id="matchlog-2", date="2026-07-13T09:00:00.000"),
    ]

    resp = client.post(url(player, "/batch"), json=batch, headers=auth_headers)
    listed = client.get(url(player), headers=auth_headers).json()

    assert resp.status_code == 201
    assert resp.json() == {"received": 2}
    assert [log["id"] for log in listed] == ["matchlog-2", "matchlog-1"]
    assert listed[1]["opponent"] == "Ken T."


def test_update_replaces_fields(client, auth_headers, player):
    client.post(url(player), json=FLUTTER_MATCH_LOG, headers=auth_headers)
    edited = log_payload(performanceNotes="Net play fixed", readinessScore=5)

    resp = client.put(
        url(player, f"/{FLUTTER_MATCH_LOG['id']}"), json=edited, headers=auth_headers
    )
    listed = client.get(url(player), headers=auth_headers).json()

    assert resp.status_code == 200
    assert listed == [edited]


def test_update_missing_log_404s(client, auth_headers, player):
    resp = client.put(
        url(player, "/no-such-log"), json=FLUTTER_MATCH_LOG, headers=auth_headers
    )
    assert resp.status_code == 404


def test_delete_removes_row(client, auth_headers, player):
    client.post(url(player), json=FLUTTER_MATCH_LOG, headers=auth_headers)

    resp = client.delete(
        url(player, f"/{FLUTTER_MATCH_LOG['id']}"), headers=auth_headers
    )

    assert resp.status_code == 204
    assert client.get(url(player), headers=auth_headers).json() == []


def test_any_reports_presence_of_logs(client, auth_headers, player):
    before = client.get(url(player, "/any"), headers=auth_headers).json()
    client.post(url(player), json=FLUTTER_MATCH_LOG, headers=auth_headers)
    after = client.get(url(player, "/any"), headers=auth_headers).json()

    assert before == {"any": False}
    assert after == {"any": True}


def test_requires_auth(client, auth_headers, player):
    assert client.get(url(player)).status_code == 401
    assert client.post(url(player), json=FLUTTER_MATCH_LOG).status_code == 401


def test_foreign_players_logs_are_invisible(client, auth_headers, player):
    client.post(url(player), json=FLUTTER_MATCH_LOG, headers=auth_headers)
    other_headers = register_and_login(client, email="other@example.com")

    # The other account can't list, write into, or delete from this player:
    # every route 404s before the handler runs, leaking nothing.
    assert client.get(url(player), headers=other_headers).status_code == 404
    assert (
        client.post(
            url(player), json=log_payload(id="intruder"), headers=other_headers
        ).status_code
        == 404
    )
    assert (
        client.delete(
            url(player, f"/{FLUTTER_MATCH_LOG['id']}"), headers=other_headers
        ).status_code
        == 404
    )

    # And the owner's data is untouched.
    listed = client.get(url(player), headers=auth_headers).json()
    assert [log["id"] for log in listed] == ["matchlog-1"]
