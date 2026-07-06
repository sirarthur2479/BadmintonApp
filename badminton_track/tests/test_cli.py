import json

import numpy as np
import pandas as pd
import pytest

from badminton_track import calibrate, cli, court, footwork


@pytest.fixture()
def identity_calib():
    return calibrate.Calibration.create(
        name="setup1", pixel_corners=court.corner_points_m(), video_size=(1920, 1080)
    )


@pytest.fixture()
def workspace(tmp_path, monkeypatch, identity_calib):
    """A tmp cwd with config dirs and a saved calibration."""
    monkeypatch.chdir(tmp_path)
    data = tmp_path / "data"
    data.mkdir()
    identity_calib.save(data / "calibration-setup1.json")
    (tmp_path / "clip.mp4").touch()
    return tmp_path


def fake_telemetry() -> pd.DataFrame:
    rows = [
        (0.0, 3.05, 8.68),
        (0.1, 3.05, 11.0),  # 2.32 m excursion
        (0.2, 3.05, 8.68),
    ]
    return pd.DataFrame(rows, columns=["t", "x_m", "y_m"]).astype(float)


def test_cli_analyze_footwork_produces_map_and_summary(workspace, monkeypatch):
    monkeypatch.setattr(
        footwork, "run_footwork", lambda video, calib, cfg: fake_telemetry()
    )

    rc = cli.main(
        ["analyze", "clip.mp4", "--mode", "footwork", "--calibration", "setup1"]
    )

    assert rc == 0
    assert (workspace / "output" / "clip-court-map.png").exists()
    summary_path = workspace / "output" / "clip-summary.json"
    assert summary_path.exists()
    summary = json.loads(summary_path.read_text())
    assert summary["episodes"]["count"] == 1
    assert summary["session"]["duration_s"] == pytest.approx(0.2)


def test_cli_analyze_missing_calibration_exits_2_with_hint(workspace, capsys):
    rc = cli.main(
        ["analyze", "clip.mp4", "--mode", "footwork", "--calibration", "nope"]
    )

    assert rc == 2
    err = capsys.readouterr().err
    assert "calibrate" in err, "error must point at the calibrate command"


def test_cli_analyze_extras_missing_exits_2(workspace, monkeypatch, capsys):
    def boom(video, calib, cfg):
        raise footwork.ExtrasMissingError('pip install "badminton-track[footwork]"')

    monkeypatch.setattr(footwork, "run_footwork", boom)

    rc = cli.main(
        ["analyze", "clip.mp4", "--mode", "footwork", "--calibration", "setup1"]
    )

    assert rc == 2
    assert "badminton-track[footwork]" in capsys.readouterr().err


def test_cli_analyze_biomech_writes_summary(workspace, monkeypatch):
    from badminton_track import biomech

    summary = pd.DataFrame(
        [
            {
                "window": "smash-1",
                "angle": "smash_extension",
                "n_samples": 60,
                "min_deg": 90.0,
                "max_deg": 180.0,
                "warning": "",
            }
        ]
    )
    monkeypatch.setattr(biomech, "run_biomech", lambda video, cfg: summary)

    rc = cli.main(["analyze", "clip.mp4", "--mode", "biomech"])

    assert rc == 0
    out = workspace / "output" / "clip-biomech-summary.json"
    assert out.exists()
    payload = json.loads(out.read_text())
    assert payload["windows"][0]["window"] == "smash-1"
    assert payload["windows"][0]["min_deg"] == 90.0


def test_cli_analyze_footwork_requires_calibration_flag(workspace, capsys):
    rc = cli.main(["analyze", "clip.mp4", "--mode", "footwork"])

    assert rc == 2
    assert "--calibration" in capsys.readouterr().err


def test_cli_calibrate_saves_json_and_runs_sanity_check(
    workspace, monkeypatch, capsys
):
    monkeypatch.setattr(
        calibrate, "pick_corners", lambda video, frame_idx=0: court.corner_points_m()
    )
    monkeypatch.setattr(cli, "_video_size", lambda video: (1920, 1080))

    rc = cli.main(["calibrate", "clip.mp4", "--name", "garage"])

    assert rc == 0
    saved = calibrate.Calibration.load(
        workspace / "data" / "calibration-garage.json"
    )
    assert saved.name == "garage"
    np.testing.assert_array_equal(saved.pixel_corners, court.corner_points_m())


def test_cli_report_writes_markdown_and_warns_without_llm(
    workspace, monkeypatch, capsys
):
    from badminton_track import coach

    # A prior footwork analysis left its summary behind.
    monkeypatch.setattr(
        footwork, "run_footwork", lambda video, calib, cfg: fake_telemetry()
    )
    cli.main(["analyze", "clip.mp4", "--mode", "footwork", "--calibration", "setup1"])

    # LLM unavailable -> metrics-only fallback, still exit 0.
    monkeypatch.setattr(
        coach,
        "generate_coach_report",
        lambda summary, cfg, extra_instruction=None: None,
    )

    rc = cli.main(["report", "clip"])

    assert rc == 0
    report_path = workspace / "output" / "clip-coach-report.md"
    assert report_path.exists()
    md = report_path.read_text()
    assert md.startswith("## Coach Report")
    assert "rallies" in md or "recover" in md.lower()
    assert "metrics-only" in capsys.readouterr().err


def test_cli_report_without_any_summaries_exits_2(workspace, capsys):
    rc = cli.main(["report", "nothing-here"])

    assert rc == 2
    assert "analyze" in capsys.readouterr().err


def test_summary_json_is_nan_safe(workspace, monkeypatch):
    # Single-episode session -> trend slope is NaN and must serialize as null.
    monkeypatch.setattr(
        footwork, "run_footwork", lambda video, calib, cfg: fake_telemetry()
    )

    cli.main(["analyze", "clip.mp4", "--mode", "footwork", "--calibration", "setup1"])

    summary = json.loads((workspace / "output" / "clip-summary.json").read_text())
    assert summary["episodes"]["trend_slope_s_per_episode"] is None
