import pytest

from tests.conftest import register_and_login
from tests.test_players import player_payload
from tests.test_sessions import FLUTTER_SESSION
from tests.test_tournaments import MATCH, TOURNAMENT


@pytest.fixture()
def player(client, auth_headers) -> str:
    payload = player_payload()
    client.post("/api/v1/players", json=payload, headers=auth_headers)
    return payload["id"]


def test_tags_idempotent_insert_sorted_list_delete(client, auth_headers, player):
    base = f"/api/v1/players/{player}/tags"

    client.post(base, json={"name": "Shadow Footwork"}, headers=auth_headers)
    client.post(base, json={"name": "Deception"}, headers=auth_headers)
    client.post(base, json={"name": "Deception"}, headers=auth_headers)  # dup

    listed = client.get(base, headers=auth_headers).json()
    assert listed == ["Deception", "Shadow Footwork"], "sorted, no duplicates"

    resp = client.delete(f"{base}/Deception", headers=auth_headers)
    assert resp.status_code == 204
    assert client.get(base, headers=auth_headers).json() == ["Shadow Footwork"]


# Every data route, expressed as (method, url-template, payload) — the
# cross-account matrix hits each with a playerId owned by someone else.
ROUTES = [
    ("GET", "/api/v1/players/{pid}/sessions", None),
    ("POST", "/api/v1/players/{pid}/sessions", FLUTTER_SESSION),
    ("POST", "/api/v1/players/{pid}/sessions/batch", [FLUTTER_SESSION]),
    ("GET", "/api/v1/players/{pid}/sessions/any", None),
    ("PUT", "/api/v1/players/{pid}/sessions/session-7", FLUTTER_SESSION),
    ("DELETE", "/api/v1/players/{pid}/sessions/session-7", None),
    ("GET", "/api/v1/players/{pid}/tournaments", None),
    ("POST", "/api/v1/players/{pid}/tournaments", TOURNAMENT),
    ("DELETE", "/api/v1/players/{pid}/tournaments/t-1", None),
    ("POST", "/api/v1/players/{pid}/tournaments/t-1/matches", MATCH),
    ("DELETE", "/api/v1/players/{pid}/tournaments/t-1/matches/m-1", None),
    ("GET", "/api/v1/players/{pid}/tags", None),
    ("POST", "/api/v1/players/{pid}/tags", {"name": "X"}),
    ("DELETE", "/api/v1/players/{pid}/tags/X", None),
]


@pytest.mark.parametrize("method,template,payload", ROUTES)
def test_cross_account_404_matrix(client, auth_headers, method, template, payload):
    other_headers = register_and_login(client, email="other@example.com")
    theirs = player_payload("Theirs")
    client.post("/api/v1/players", json=theirs, headers=other_headers)
    url = template.format(pid=theirs["id"])

    resp = client.request(method, url, json=payload, headers=auth_headers)

    assert resp.status_code == 404, f"{method} {template} must 404 across accounts"


@pytest.mark.parametrize("method,template,payload", ROUTES)
def test_all_data_routes_require_auth(client, method, template, payload):
    url = template.format(pid="whoever")

    resp = client.request(method, url, json=payload)

    assert resp.status_code == 401, f"{method} {template} must require a token"
