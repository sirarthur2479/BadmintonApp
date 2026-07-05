import numpy as np
import pandas as pd

from badminton_track import calibrate, court, footwork, metrics
from badminton_track.config import FootworkConfig

# Pixel corners identical to the metre corners -> identity homography, so
# fabricated bboxes can be placed directly in court coordinates.
IDENTITY_CALIB = calibrate.Calibration.create(
    name="identity", pixel_corners=court.corner_points_m(), video_size=(1920, 1080)
)

CFG = FootworkConfig(lock_warmup_s=0.3, lock_grace_s=0.25)


def track(track_id: int, x: float, y: float) -> footwork.RawTrack:
    """A RawTrack whose bbox bottom-centre sits at court point (x, y)."""
    return footwork.RawTrack(
        track_id=track_id,
        bbox_xyxy=np.array([x - 0.3, y - 1.6, x + 0.3, y]),
    )


def near(track_id: int = 1, x: float = 3.0, y: float = 10.0) -> footwork.RawTrack:
    return track(track_id, x, y)


def far(track_id: int = 2, x: float = 3.0, y: float = 3.0) -> footwork.RawTrack:
    return track(track_id, x, y)


def test_lock_target_picks_track_on_near_half():
    frames = [
        (0.0, [near(1, 2.0, 9.0), far(2)]),
        (0.1, [near(1, 2.5, 9.5), far(2)]),
        (0.2, [near(1, 3.0, 10.0), far(2)]),
    ]

    df = footwork.lock_target(frames, IDENTITY_CALIB, CFG)

    np.testing.assert_allclose(df["x_m"], [2.0, 2.5, 3.0])
    np.testing.assert_allclose(df["y_m"], [9.0, 9.5, 10.0])


def test_lock_ignores_opponent_on_far_half():
    # Opponent (id 2) present in every frame; player (id 1) missing in one.
    frames = [
        (0.0, [near(1), far(2)]),
        (0.1, [far(2)]),
        (0.2, [near(1), far(2)]),
    ]

    df = footwork.lock_target(frames, IDENTITY_CALIB, CFG)

    assert np.isnan(df["x_m"].iloc[1]), "opponent must never fill in for the player"
    np.testing.assert_allclose(df["x_m"].iloc[[0, 2]], [3.0, 3.0])


def test_lock_survives_brief_disappearance_within_grace():
    frames = [
        (0.0, [near(1)]),
        (0.1, []),  # gone for one frame (0.1 s < grace 0.25 s)
        (0.2, [near(1, 3.5, 10.5)]),
    ]

    df = footwork.lock_target(frames, IDENTITY_CALIB, CFG)

    assert np.isnan(df["x_m"].iloc[1])
    assert df["x_m"].iloc[2] == 3.5, "lock must survive a brief disappearance"


def test_lock_switches_after_sustained_absence():
    # id 1 vanishes for good (ByteTrack re-identified the player as id 7).
    frames = [
        (0.0, [near(1)]),
        (0.1, [near(1)]),
        (0.2, []),
        (0.5, [near(7, 2.0, 11.0)]),  # absence 0.4s > grace 0.25s
        (0.6, [near(7, 2.1, 11.1)]),
    ]

    df = footwork.lock_target(frames, IDENTITY_CALIB, CFG)

    assert df["x_m"].iloc[3] == 2.0, "must relock onto the new near-half id"
    assert df["x_m"].iloc[4] == 2.1


def test_missing_frames_become_nan_rows():
    frames = [
        (0.0, [near(1)]),
        (0.1, []),
        (0.2, []),
        (0.3, [near(1)]),
    ]

    df = footwork.lock_target(frames, IDENTITY_CALIB, CFG)

    assert len(df) == 4
    assert df["x_m"].isna().sum() == 2


def test_telemetry_time_axis_matches_frame_times():
    frames = [(0.0, [near(1)]), (0.15, [near(1)]), (0.3, [near(1)])]

    df = footwork.lock_target(frames, IDENTITY_CALIB, CFG)

    np.testing.assert_allclose(df["t"], [0.0, 0.15, 0.3])


def test_telemetry_feeds_metrics_detect_episodes():
    base = (3.05, 8.68)
    # Excursion: at base, out 2 m, back to base.
    frames = [
        (0.0, [near(1, base[0], base[1])]),
        (0.1, [near(1, base[0], base[1] + 2.0)]),
        (0.2, [near(1, base[0], base[1])]),
    ]

    df = footwork.lock_target(frames, IDENTITY_CALIB, CFG)
    episodes = metrics.detect_episodes(df, base_xy=base, radius_m=1.0)

    assert len(episodes) == 1
    assert episodes[0].peak_distance_m == 2.0


def test_lock_target_empty_input_returns_empty_telemetry():
    df = footwork.lock_target([], IDENTITY_CALIB, CFG)

    assert isinstance(df, pd.DataFrame)
    assert list(df.columns) == ["t", "x_m", "y_m"]
    assert df.empty
