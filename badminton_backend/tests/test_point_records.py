import pytest

from tests.conftest import register_and_login
from tests.test_match_logs import FLUTTER_MATCH_LOG
from tests.test_players import player_payload

# A payload exactly as the Flutter PointRecord.toMap() emits it (TASK-042):
# sides/endings are strings, nullables null, shots a JSON-encoded TEXT
# pass-through that must never be re-encoded server-side.
FLUTTER_POINT_RECORD = {
    "id": "pt-1",
    "matchLogId": "matchlog-1",
    "game": 2,
    "indexInGame": 15,
    "server": "player",
    "winner": "opponent",
    "playerScore": 7,
    "opponentScore": 8,
    "rallyLength": 12,
    "endingType": "unforcedError",
    "endingShot": "smash",
    "endingZone": "rearLeft",
    "endingSide": "player",
    "videoTimestampMs": 754300,
    "shots": '[{"shotType":"serve","side":"player","timestampMs":1000}]',
}


@pytest.fixture()
def player(client, auth_headers) -> str:
    payload = player_payload()
    client.post("/api/v1/players", json=payload, headers=auth_headers)
    return payload["id"]


@pytest.fixture()
def match_log(client, auth_headers, player) -> str:
    client.post(
        f"/api/v1/players/{player}/match-logs",
        json=FLUTTER_MATCH_LOG,
        headers=auth_headers,
    )
    return FLUTTER_MATCH_LOG["id"]


def url(pid: str, log_id: str, suffix: str = "") -> str:
    return f"/api/v1/players/{pid}/match-logs/{log_id}/points{suffix}"


def point_payload(**overrides) -> dict:
    return dict(FLUTTER_POINT_RECORD, **overrides)


def test_point_record_flutter_map_round_trips_verbatim(
    client, auth_headers, player, match_log
):
    created = client.post(
        url(player, match_log), json=FLUTTER_POINT_RECORD, headers=auth_headers
    )
    listed = client.get(url(player, match_log), headers=auth_headers)

    assert created.status_code == 201
    assert listed.json() == [FLUTTER_POINT_RECORD], "key-for-key round trip"


def test_list_ordered_by_game_then_index(client, auth_headers, player, match_log):
    g2_p1 = point_payload(id="pt-g2-1", game=2, indexInGame=1)
    g1_p2 = point_payload(id="pt-g1-2", game=1, indexInGame=2)
    g1_p1 = point_payload(id="pt-g1-1", game=1, indexInGame=1)

    for p in (g2_p1, g1_p2, g1_p1):
        client.post(url(player, match_log), json=p, headers=auth_headers)

    ids = [
        p["id"] for p in client.get(url(player, match_log), headers=auth_headers).json()
    ]
    assert ids == ["pt-g1-1", "pt-g1-2", "pt-g2-1"]


def test_post_same_id_replaces_row(client, auth_headers, player, match_log):
    client.post(url(player, match_log), json=FLUTTER_POINT_RECORD, headers=auth_headers)
    edited = point_payload(winner="player", endingType="winner", endingShot="net")
    client.post(url(player, match_log), json=edited, headers=auth_headers)

    listed = client.get(url(player, match_log), headers=auth_headers).json()
    assert listed == [edited]


def test_batch_replaces_existing_ids(client, auth_headers, player, match_log):
    client.post(url(player, match_log), json=FLUTTER_POINT_RECORD, headers=auth_headers)
    batch = [
        point_payload(winner="player", endingType="winner"),  # same id: replaced
        point_payload(id="pt-2", game=2, indexInGame=16),
    ]

    resp = client.post(url(player, match_log, "/batch"), json=batch, headers=auth_headers)
    listed = client.get(url(player, match_log), headers=auth_headers).json()

    assert resp.status_code == 201
    assert resp.json() == {"received": 2}
    assert [p["id"] for p in listed] == ["pt-1", "pt-2"]
    assert listed[0]["winner"] == "player", "batch upserts, not ignores"


def test_clear_all_removes_only_this_logs_points(client, auth_headers, player, match_log):
    other_log = dict(FLUTTER_MATCH_LOG, id="matchlog-2")
    client.post(
        f"/api/v1/players/{player}/match-logs", json=other_log, headers=auth_headers
    )
    client.post(url(player, match_log), json=FLUTTER_POINT_RECORD, headers=auth_headers)
    client.post(
        url(player, "matchlog-2"),
        json=point_payload(id="pt-other", matchLogId="matchlog-2"),
        headers=auth_headers,
    )

    resp = client.delete(url(player, match_log), headers=auth_headers)

    assert resp.status_code == 204
    assert client.get(url(player, match_log), headers=auth_headers).json() == []
    kept = client.get(url(player, "matchlog-2"), headers=auth_headers).json()
    assert [p["id"] for p in kept] == ["pt-other"]


def test_delete_removes_single_point(client, auth_headers, player, match_log):
    client.post(url(player, match_log), json=FLUTTER_POINT_RECORD, headers=auth_headers)
    client.post(
        url(player, match_log),
        json=point_payload(id="pt-2", indexInGame=16),
        headers=auth_headers,
    )

    resp = client.delete(url(player, match_log, "/pt-1"), headers=auth_headers)

    assert resp.status_code == 204
    listed = client.get(url(player, match_log), headers=auth_headers).json()
    assert [p["id"] for p in listed] == ["pt-2"]


def test_unknown_match_log_404s(client, auth_headers, player):
    resp = client.get(url(player, "no-such-log"), headers=auth_headers)
    assert resp.status_code == 404


def test_foreign_match_log_404s_before_handler(client, auth_headers, player, match_log):
    client.post(url(player, match_log), json=FLUTTER_POINT_RECORD, headers=auth_headers)
    other_headers = register_and_login(client, email="other@example.com")
    other_player = player_payload(name="Other Kid")
    client.post("/api/v1/players", json=other_player, headers=other_headers)

    # The other account reaches through ITS OWN player at OUR match log:
    # the own-log guard 404s without leaking that the log exists.
    foreign = url(other_player["id"], match_log)
    assert client.get(foreign, headers=other_headers).status_code == 404
    assert (
        client.post(
            foreign, json=point_payload(id="intruder"), headers=other_headers
        ).status_code
        == 404
    )
    assert client.delete(foreign, headers=other_headers).status_code == 404

    # And the owner's points are untouched.
    listed = client.get(url(player, match_log), headers=auth_headers).json()
    assert [p["id"] for p in listed] == ["pt-1"]


def test_deleting_match_log_cascades_points(client, auth_headers, player, match_log):
    client.post(url(player, match_log), json=FLUTTER_POINT_RECORD, headers=auth_headers)

    client.delete(
        f"/api/v1/players/{player}/match-logs/{match_log}", headers=auth_headers
    )

    # Recreate the log: its points must NOT resurrect.
    client.post(
        f"/api/v1/players/{player}/match-logs",
        json=FLUTTER_MATCH_LOG,
        headers=auth_headers,
    )
    assert client.get(url(player, match_log), headers=auth_headers).json() == []


def test_requires_auth(client, auth_headers, player, match_log):
    assert client.get(url(player, match_log)).status_code == 401
    assert (
        client.post(url(player, match_log), json=FLUTTER_POINT_RECORD).status_code
        == 401
    )
