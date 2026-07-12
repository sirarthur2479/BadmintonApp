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
