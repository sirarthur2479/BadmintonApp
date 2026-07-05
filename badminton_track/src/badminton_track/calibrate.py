"""Module 1 — court calibration and homography.

The homography maps *pixel* coordinates to *court metres* and is only valid
for points on the court plane. The single sanctioned bbox path is
`feet_point` / `project_feet` (bbox bottom-centre): never project a bbox
centre or head through H.
"""

import numpy as np

from . import court


class CalibrationError(Exception):
    """Bad calibration input (wrong shape, degenerate corner geometry)."""


def build_homography(pixel_corners: np.ndarray) -> np.ndarray:
    """3x3 homography from the 4 clicked pixel corners to court metres.

    Corners must follow `court.corner_points_m()` order: far-left,
    far-right, near-right, near-left (clockwise from far-left).
    Exactly 4 correspondences -> `cv2.getPerspectiveTransform` (exact,
    deterministic); RANSAC/`findHomography` is deliberately not used.
    """
    import cv2

    pixel_corners = np.asarray(pixel_corners, dtype=np.float64)
    if pixel_corners.shape != (4, 2):
        raise CalibrationError(
            f"expected 4 corner points of shape (4, 2), got {pixel_corners.shape}"
        )
    # Degenerate check: any three corners collinear -> no valid perspective.
    for skip in range(4):
        pts = np.delete(pixel_corners, skip, axis=0)
        v1, v2 = pts[1] - pts[0], pts[2] - pts[0]
        area = 0.5 * abs(v1[0] * v2[1] - v1[1] * v2[0])
        if area < 1.0:  # px^2 — clicks this close to collinear are a misclick
            raise CalibrationError("corner points are (nearly) collinear")

    h = cv2.getPerspectiveTransform(
        pixel_corners.astype(np.float32),
        court.corner_points_m().astype(np.float32),
    )
    return np.asarray(h, dtype=np.float64)


def project_points(h: np.ndarray, pts: np.ndarray) -> np.ndarray:
    """Apply a homography to (N, 2) points."""
    import cv2

    pts = np.asarray(pts, dtype=np.float64).reshape(-1, 1, 2)
    out = cv2.perspectiveTransform(pts, np.asarray(h, dtype=np.float64))
    return out.reshape(-1, 2)


def feet_point(bbox_xyxy: np.ndarray) -> np.ndarray:
    """Bottom-centre of an (x1, y1, x2, y2) bbox — the only court-plane point."""
    bbox = np.asarray(bbox_xyxy, dtype=np.float64)
    return np.array([(bbox[0] + bbox[2]) / 2.0, bbox[3]])


def project_feet(h: np.ndarray, bboxes_xyxy: np.ndarray) -> np.ndarray:
    """Project the feet points of (N, 4) bboxes into court metres."""
    bboxes = np.asarray(bboxes_xyxy, dtype=np.float64).reshape(-1, 4)
    feet = np.stack([feet_point(b) for b in bboxes])
    return project_points(h, feet)
