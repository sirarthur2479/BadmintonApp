"""Badminton court geometry in metres — the single source of truth.

Court coordinate frame (all functions return metres, float64):
    x — across the court, 0 at the left doubles sideline (seen from the
        rear camera), increasing rightward to 6.1.
    y — down the court, 0 at the FAR baseline, 6.7 at the net,
        13.4 at the NEAR baseline (the camera side).

Only points on the court plane (players' feet) may live in this frame —
projecting anything else through the homography is invalid.
"""

import numpy as np

COURT_LENGTH = 13.4
COURT_WIDTH_DOUBLES = 6.1
COURT_WIDTH_SINGLES = 5.18
NET_Y = 6.7
FRONT_SERVICE_LINE_FROM_NET = 1.98


def corner_points_m() -> np.ndarray:
    """The 4 doubles-court corners, clockwise from far-left.

    Calibration clicks must follow this exact order:
    far-left, far-right, near-right, near-left.
    """
    return np.array(
        [
            [0.0, 0.0],
            [COURT_WIDTH_DOUBLES, 0.0],
            [COURT_WIDTH_DOUBLES, COURT_LENGTH],
            [0.0, COURT_LENGTH],
        ],
        dtype=np.float64,
    )


def front_service_intersections_m() -> np.ndarray:
    """Near-half front service line × doubles sidelines (calibration sanity check)."""
    y = NET_Y + FRONT_SERVICE_LINE_FROM_NET
    return np.array(
        [
            [0.0, y],
            [COURT_WIDTH_DOUBLES, y],
        ],
        dtype=np.float64,
    )


def near_half_polygon_m() -> np.ndarray:
    """The near court half (net to near baseline) — the target-player zone."""
    return np.array(
        [
            [0.0, NET_Y],
            [COURT_WIDTH_DOUBLES, NET_Y],
            [COURT_WIDTH_DOUBLES, COURT_LENGTH],
            [0.0, COURT_LENGTH],
        ],
        dtype=np.float64,
    )
