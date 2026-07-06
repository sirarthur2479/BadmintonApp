"""Module 1 — court calibration and homography.

The homography maps *pixel* coordinates to *court metres* and is only valid
for points on the court plane. The single sanctioned bbox path is
`feet_point` / `project_feet` (bbox bottom-centre): never project a bbox
centre or head through H.
"""

import json
from dataclasses import dataclass
from datetime import date
from pathlib import Path

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


@dataclass(frozen=True)
class Calibration:
    """A saved camera-setup calibration, persisted as JSON under data/."""

    name: str
    pixel_corners: np.ndarray  # (4, 2), court.corner_points_m() order
    h: np.ndarray  # (3, 3) pixels -> metres
    video_size: tuple[int, int]  # (width, height)
    created: str  # ISO date

    @classmethod
    def create(
        cls,
        name: str,
        pixel_corners: np.ndarray,
        video_size: tuple[int, int],
    ) -> "Calibration":
        pixel_corners = np.asarray(pixel_corners, dtype=np.float64)
        return cls(
            name=name,
            pixel_corners=pixel_corners,
            h=build_homography(pixel_corners),
            video_size=(int(video_size[0]), int(video_size[1])),
            created=date.today().isoformat(),
        )

    def save(self, path: Path) -> None:
        payload = {
            "name": self.name,
            "pixel_corners": self.pixel_corners.tolist(),
            "h": self.h.tolist(),
            "video_size": list(self.video_size),
            "created": self.created,
        }
        Path(path).write_text(json.dumps(payload, indent=2))

    @classmethod
    def load(cls, path: Path) -> "Calibration":
        payload = json.loads(Path(path).read_text())
        return cls(
            name=payload["name"],
            pixel_corners=np.asarray(payload["pixel_corners"], dtype=np.float64),
            h=np.asarray(payload["h"], dtype=np.float64),
            video_size=tuple(payload["video_size"]),
            created=payload["created"],
        )


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


SANITY_WARN_PX = 20.0


def sanity_check(calib: Calibration, clicked_service_pts_px: np.ndarray) -> float:
    """Max reprojection error (px) of the 2 clicked front-service points.

    The true front-service-line × sideline intersections are reprojected
    from the court model into pixel space through the inverse homography and
    compared against where the user clicked them. A large error means the
    corner clicks were bad — caught now, not as silently wrong metrics.
    """
    clicked = np.asarray(clicked_service_pts_px, dtype=np.float64).reshape(2, 2)
    h_inv = np.linalg.inv(calib.h)
    expected = project_points(h_inv, court.front_service_intersections_m())
    return float(np.linalg.norm(clicked - expected, axis=1).max())


def check_or_warn(
    calib: Calibration,
    clicked_service_pts_px: np.ndarray,
    threshold_px: float = SANITY_WARN_PX,
) -> str | None:
    """None when the calibration passes; a human-readable warning otherwise."""
    err = sanity_check(calib, clicked_service_pts_px)
    if err <= threshold_px:
        return None
    return (
        f"calibration '{calib.name}' reprojection error {err:.1f} px exceeds "
        f"{threshold_px:.0f} px — re-click the court corners"
    )


def pick_corners(video_path: Path, frame_idx: int = 0) -> np.ndarray:
    """Interactive corner picker (manual use only — not unit-tested).

    Opens the given frame in an OpenCV window; click the 4 court corners in
    the documented order (far-left, far-right, near-right, near-left), then
    press any key. Returns the clicked (4, 2) pixel array.
    """
    import cv2

    cap = cv2.VideoCapture(str(video_path))
    cap.set(cv2.CAP_PROP_POS_FRAMES, frame_idx)
    ok, frame = cap.read()
    cap.release()
    if not ok:
        raise CalibrationError(f"could not read frame {frame_idx} of {video_path}")

    clicks: list[list[float]] = []

    def on_mouse(event: int, x: int, y: int, *_args) -> None:
        if event == cv2.EVENT_LBUTTONDOWN and len(clicks) < 4:
            clicks.append([float(x), float(y)])
            cv2.circle(frame, (x, y), 6, (0, 255, 0), -1)
            cv2.imshow("pick corners", frame)

    cv2.imshow("pick corners", frame)
    cv2.setMouseCallback("pick corners", on_mouse)
    while len(clicks) < 4:
        if cv2.waitKey(50) == 27:  # Esc aborts
            break
    cv2.destroyAllWindows()
    if len(clicks) != 4:
        raise CalibrationError("corner picking aborted before 4 clicks")
    return np.asarray(clicks, dtype=np.float64)
