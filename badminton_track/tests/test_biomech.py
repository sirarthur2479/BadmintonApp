import numpy as np
import pandas as pd
import pytest

from badminton_track import biomech


def pose_frame(
    t: float,
    joints: dict[int, tuple[float, float]],
    visibility: float = 1.0,
    z: dict[int, float] | None = None,
) -> biomech.PoseFrame:
    """A fabricated PoseFrame: 33 landmarks, given joints placed, rest hidden."""
    landmarks = np.zeros((33, 4))
    for idx, (x, y) in joints.items():
        landmarks[idx] = [x, y, (z or {}).get(idx, 0.0), visibility]
    return biomech.PoseFrame(t=t, landmarks=landmarks)


def test_triplet_angle_right_angle_is_90():
    angle = biomech.triplet_angle((0.0, 1.0), (0.0, 0.0), (1.0, 0.0))

    assert angle == pytest.approx(90.0)


def test_triplet_angle_straight_line_is_180():
    angle = biomech.triplet_angle((-1.0, 0.0), (0.0, 0.0), (1.0, 0.0))

    assert angle == pytest.approx(180.0)


def test_landmark_tables_cover_both_sides_and_angles():
    right = biomech.LANDMARKS["right"]
    left = biomech.LANDMARKS["left"]

    assert right["smash_extension"] == (12, 14, 16)
    assert right["knee_lunge"] == (24, 26, 28)
    assert left["smash_extension"] == (11, 13, 15)
    assert left["knee_lunge"] == (23, 25, 27)


def right_elbow_frames() -> list[biomech.PoseFrame]:
    """3 frames of a right arm: straight, right angle, straight."""
    shoulder, elbow, wrist = 12, 14, 16
    return [
        pose_frame(0.0, {shoulder: (0.0, 0.0), elbow: (0.1, 0.0), wrist: (0.2, 0.0)}),
        pose_frame(1 / 60, {shoulder: (0.0, 0.0), elbow: (0.1, 0.0), wrist: (0.1, 0.1)}),
        pose_frame(2 / 60, {shoulder: (0.0, 0.0), elbow: (0.1, 0.0), wrist: (0.2, 0.0)}),
    ]


def test_angle_series_computes_configured_triplet():
    df = biomech.angle_series(
        right_elbow_frames(), triplet=(12, 14, 16), visibility_threshold=0.5
    )

    assert list(df.columns) == ["t", "angle_deg"]
    np.testing.assert_allclose(df["angle_deg"], [180.0, 90.0, 180.0], atol=1e-9)
    np.testing.assert_allclose(df["t"], [0.0, 1 / 60, 2 / 60])


def test_angle_series_nan_when_any_landmark_below_visibility():
    frames = right_elbow_frames()
    # Occlude the wrist in the middle frame.
    frames[1].landmarks[16, 3] = 0.3

    df = biomech.angle_series(frames, triplet=(12, 14, 16), visibility_threshold=0.5)

    assert np.isnan(df["angle_deg"].iloc[1])
    assert not df["angle_deg"].iloc[[0, 2]].isna().any()


def test_angle_series_nan_for_frame_without_pose():
    frames = right_elbow_frames()
    frames[1] = biomech.PoseFrame(t=1 / 60, landmarks=None)

    df = biomech.angle_series(frames, triplet=(12, 14, 16), visibility_threshold=0.5)

    assert np.isnan(df["angle_deg"].iloc[1])


def test_windows_slice_series_by_time():
    df = pd.DataFrame(
        {"t": [0.0, 0.5, 1.0, 1.5, 2.0], "angle_deg": [10.0, 20.0, 30.0, 40.0, 50.0]}
    )
    window = biomech.AnalysisWindow(
        name="lunge-1", start_s=0.5, end_s=1.5, angle="knee_lunge"
    )

    sliced = biomech.slice_window(df, window)

    np.testing.assert_allclose(sliced["angle_deg"], [20.0, 30.0, 40.0])
