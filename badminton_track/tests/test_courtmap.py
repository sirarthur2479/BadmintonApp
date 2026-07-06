import cv2
import numpy as np
import pandas as pd

from badminton_track import courtmap, metrics
from badminton_track.config import FootworkConfig

CFG = FootworkConfig()


def telemetry(rows):
    return pd.DataFrame(rows, columns=["t", "x_m", "y_m"]).astype(float)


def test_render_court_map_writes_png_with_expected_canvas_size(tmp_path):
    df = telemetry([(0.0, 3.05, 8.68), (0.1, 3.5, 10.0)])
    out = tmp_path / "map.png"

    result = courtmap.render_court_map(df, [], CFG, out, px_per_m=50)

    assert result == out
    assert out.exists()
    img = cv2.imread(str(out))
    # 6.1 m x 13.4 m at 50 px/m plus a margin on each side.
    margin = courtmap.MARGIN_PX
    assert img.shape[1] == int(6.1 * 50) + 2 * margin
    assert img.shape[0] == int(13.4 * 50) + 2 * margin


def test_render_court_map_draws_trajectory_pixels(tmp_path):
    # A long diagonal run must leave non-background pixels along its path.
    df = telemetry([(0.1 * i, 0.5 + 0.05 * i, 7.0 + 0.06 * i) for i in range(60)])
    out = tmp_path / "map.png"

    courtmap.render_court_map(df, [], CFG, out, px_per_m=50)

    img = cv2.imread(str(out))
    blank = courtmap.render_blank_court(CFG, px_per_m=50)
    assert (img != blank).any(), "trajectory must change pixels vs an empty court"


def test_render_handles_all_nan_telemetry(tmp_path):
    df = telemetry([(0.0, None, None), (0.1, None, None)])
    out = tmp_path / "map.png"

    result = courtmap.render_court_map(df, [], CFG, out, px_per_m=50)

    assert result.exists(), "all-NaN telemetry must still produce a court image"


def test_render_marks_episode_peaks(tmp_path):
    df = telemetry([(0.0, 3.05, 8.68), (0.1, 3.05, 11.0), (0.2, 3.05, 8.68)])
    episodes = metrics.detect_episodes(df, base_xy=(3.05, 8.68), radius_m=1.0)
    assert episodes, "fixture must contain one episode"
    out_with = tmp_path / "with.png"
    out_without = tmp_path / "without.png"

    courtmap.render_court_map(df, episodes, CFG, out_with, px_per_m=50)
    courtmap.render_court_map(df, [], CFG, out_without, px_per_m=50)

    a = cv2.imread(str(out_with))
    b = cv2.imread(str(out_without))
    assert (a != b).any(), "episode peak markers must be visible"
