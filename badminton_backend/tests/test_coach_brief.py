"""POST /api/v1/coach/opponent-brief: thin authed wrapper over the
badminton_track tactics engine. The engine is a seam on app.state so tests
never touch Ollama."""

BODY = {
    "opponent": "Ken T.",
    "facts": [
        "Head-to-head vs Ken T.: won 3 of 5 matches.",
        "Their winners come mostly from: smash (6).",
    ],
}

URL = "/api/v1/coach/opponent-brief"


def test_endpoint_returns_markdown_from_engine(client, auth_headers):
    seen = {}

    def fake_engine(opponent, facts):
        seen["opponent"] = opponent
        seen["facts"] = facts
        return f"# Tactical brief — {opponent}\n\nServe low."

    client.app.state.tactics_engine = fake_engine

    resp = client.post(URL, json=BODY, headers=auth_headers)

    assert resp.status_code == 200
    assert resp.json() == {
        "markdown": "# Tactical brief — Ken T.\n\nServe low."
    }
    assert seen["opponent"] == "Ken T."
    assert seen["facts"] == BODY["facts"]


def test_endpoint_503_when_engine_unavailable(client, auth_headers):
    def down(opponent, facts):
        return None  # tactics engine: Ollama unreachable / lint failed

    client.app.state.tactics_engine = down

    resp = client.post(URL, json=BODY, headers=auth_headers)

    assert resp.status_code == 503
    assert "Ollama" in resp.json()["detail"]


def test_endpoint_503_with_actionable_message_on_missing_extras(
    client, auth_headers
):
    def missing(opponent, facts):
        raise RuntimeError(
            "badminton_track is not installed in the server environment — "
            "install it next to the backend: pip install -e ../badminton_track"
        )

    client.app.state.tactics_engine = missing

    resp = client.post(URL, json=BODY, headers=auth_headers)

    assert resp.status_code == 503
    assert "pip install" in resp.json()["detail"]


def test_endpoint_requires_auth(client):
    assert client.post(URL, json=BODY).status_code == 401


def test_endpoint_validates_body(client, auth_headers):
    resp = client.post(URL, json={"opponent": ""}, headers=auth_headers)
    assert resp.status_code == 422
