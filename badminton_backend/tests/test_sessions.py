import uuid

import pytest

from tests.test_players import player_payload

# A payload exactly as the current Flutter TrainingSession.toMap() emits it:
# drills is a JSON-array STRING (with an embedded comma in a tag), intensity
# null for new sessions, Part-A goal/reflection fields present.
FLUTTER_SESSION = {
    "id": "session-7",
    "date": "2026-07-14T00:00:00.000",
    "durationMinutes": 75,
    "drills": '["Multi-feed, front court","Net Play"]',
    "intensity": None,
    "notes": "",
    "photoPath": None,
    "sessionGoal": "Sharper net kills",
    "goalAchievementScore": 4,
    "playerRemarks": "Kills felt crisp",
    "coachRemarks": "Watch the recovery step",
    "reflectionAnswersJson": '[{"questionKey":"Why did you set this goal for today?","answer":"Coach picked it"}]',
}


@pytest.fixture()
def player(client, auth_headers) -> str:
    payload = player_payload()
    client.post("/api/v1/players", json=payload, headers=auth_headers)
    return payload["id"]


def url(pid: str, suffix: str = "") -> str:
    return f"/api/v1/players/{pid}/sessions{suffix}"


def test_session_flutter_map_round_trips_verbatim(client, auth_headers, player):
    created = client.post(url(player), json=FLUTTER_SESSION, headers=auth_headers)
    listed = client.get(url(player), headers=auth_headers)

    assert created.status_code == 201
    assert listed.json() == [FLUTTER_SESSION], "key-for-key round trip"


def test_legacy_session_with_intensity_round_trips(client, auth_headers, player):
    legacy = dict(FLUTTER_SESSION, id="legacy-1", intensity=4, sessionGoal="")

    client.post(url(player), json=legacy, headers=auth_headers)
    listed = client.get(url(player), headers=auth_headers).json()

    assert listed[0]["intensity"] == 4


def test_sessions_listed_date_desc(client, auth_headers, player):
    older = dict(FLUTTER_SESSION, id="s-old", date="2026-07-01T00:00:00.000")
    newer = dict(FLUTTER_SESSION, id="s-new", date="2026-07-20T00:00:00.000")
    client.post(url(player), json=older, headers=auth_headers)
    client.post(url(player), json=newer, headers=auth_headers)

    ids = [s["id"] for s in client.get(url(player), headers=auth_headers).json()]

    assert ids == ["s-new", "s-old"]


def test_session_update_and_delete(client, auth_headers, player):
    client.post(url(player), json=FLUTTER_SESSION, headers=auth_headers)
    edited = dict(FLUTTER_SESSION, sessionGoal="Edited goal", durationMinutes=90)

    updated = client.put(
        url(player, f"/{FLUTTER_SESSION['id']}"), json=edited, headers=auth_headers
    )
    assert updated.status_code == 200
    assert (
        client.get(url(player), headers=auth_headers).json()[0]["sessionGoal"]
        == "Edited goal"
    )

    deleted = client.delete(
        url(player, f"/{FLUTTER_SESSION['id']}"), headers=auth_headers
    )
    assert deleted.status_code == 204
    assert client.get(url(player), headers=auth_headers).json() == []


def test_sessions_batch_insert_ignores_duplicates(client, auth_headers, player):
    a = dict(FLUTTER_SESSION, id=str(uuid.uuid4()))
    b = dict(FLUTTER_SESSION, id=str(uuid.uuid4()))
    client.post(url(player), json=a, headers=auth_headers)

    resp = client.post(url(player, "/batch"), json=[a, b], headers=auth_headers)

    assert resp.status_code == 201
    assert len(client.get(url(player), headers=auth_headers).json()) == 2


def test_sessions_any_flag(client, auth_headers, player):
    assert (
        client.get(url(player, "/any"), headers=auth_headers).json()["any"] is False
    )

    client.post(url(player), json=FLUTTER_SESSION, headers=auth_headers)

    assert (
        client.get(url(player, "/any"), headers=auth_headers).json()["any"] is True
    )
