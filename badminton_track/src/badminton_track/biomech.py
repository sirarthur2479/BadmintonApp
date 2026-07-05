"""Module 3 — side-view joint-angle biomechanics.

Runs at the FULL frame rate (a smash swing is a 100–200 ms event — no
striding here, unlike Module 2). 2D angles are valid only when the movement
plane is roughly parallel to the camera; the oblique-view guard watches the
landmark z-spread for violations.

MediaPipe is confined to `iter_pose_frames` (Tasks `PoseLandmarker` API only
— the legacy `mp.solutions.pose` no longer ships in the wheel).
"""

from dataclasses import dataclass
from typing import Literal

import numpy as np
import pandas as pd

# MediaPipe 33-landmark BlazePose topology, per camera side.
LANDMARKS: dict[str, dict[str, tuple[int, int, int]]] = {
    "right": {
        "smash_extension": (12, 14, 16),  # shoulder–elbow–wrist
        "knee_lunge": (24, 26, 28),  # hip–knee–ankle
    },
    "left": {
        "smash_extension": (11, 13, 15),
        "knee_lunge": (23, 25, 27),
    },
}

AngleName = Literal["smash_extension", "knee_lunge"]


@dataclass(frozen=True)
class PoseFrame:
    """One frame of pose output.

    landmarks: (33, 4) array of [x, y, z, visibility], or None when no pose
    was detected in the frame. world_landmarks (metric-ish, for the oblique
    guard) is optional.
    """

    t: float
    landmarks: np.ndarray | None
    world_landmarks: np.ndarray | None = None


@dataclass(frozen=True)
class AnalysisWindow:
    """A manually-defined clip segment to analyse (config-driven for MVP)."""

    name: str
    start_s: float
    end_s: float
    angle: AngleName


def triplet_angle(
    a: tuple[float, float], b: tuple[float, float], c: tuple[float, float]
) -> float:
    """2D angle in degrees at vertex b of triplet a–b–c."""
    v1 = np.asarray(a, dtype=np.float64) - np.asarray(b, dtype=np.float64)
    v2 = np.asarray(c, dtype=np.float64) - np.asarray(b, dtype=np.float64)
    cross = v1[0] * v2[1] - v1[1] * v2[0]
    dot = float(np.dot(v1, v2))
    return float(np.degrees(np.arctan2(abs(cross), dot)))


def angle_series(
    frames: list[PoseFrame],
    triplet: tuple[int, int, int],
    visibility_threshold: float,
) -> pd.DataFrame:
    """Per-frame triplet angle; NaN when the pose or any landmark is unusable."""
    rows: list[tuple[float, float]] = []
    for frame in frames:
        lm = frame.landmarks
        if lm is None or (lm[list(triplet), 3] < visibility_threshold).any():
            rows.append((frame.t, np.nan))
            continue
        a, b, c = (lm[i, :2] for i in triplet)
        rows.append((frame.t, triplet_angle(tuple(a), tuple(b), tuple(c))))
    return pd.DataFrame(rows, columns=["t", "angle_deg"]).astype(float)


def slice_window(df: pd.DataFrame, window: AnalysisWindow) -> pd.DataFrame:
    """Rows of an angle series inside a window (inclusive bounds)."""
    mask = (df["t"] >= window.start_s) & (df["t"] <= window.end_s)
    return df.loc[mask].reset_index(drop=True)
