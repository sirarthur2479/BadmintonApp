# TASK-015 - Court calibration: homography build, feet-only projection, sanity check

**Use case:** [ideas/use-cases/badmintontrack-12.md](../../ideas/use-cases/badmintontrack-12.md)
**Research:** [research/cv-tracking.md](../../research/cv-tracking.md)
**Depends on:** TASK-014
**Effort:** M
**Risk:** medium

**Status:** todo

## Goal

Module 1: map the 4 hand-clicked court corners in a video frame to the real
court model in metres via `cv2.getPerspectiveTransform`, persist calibrations
as JSON keyed by camera setup, project points at runtime with
`cv2.perspectiveTransform`, and enforce the court-plane invariant — only feet
points (bbox bottom-centre) ever go through the homography. Includes the
2-click front-service-line reprojection sanity check that catches bad corner
clicks immediately. The interactive corner-clicking OpenCV window is a thin
untested shell; all math and persistence is pure and unit-tested with
synthetic correspondences.

## Acceptance criteria

- `src/badminton_track/calibrate.py` with:
  - `build_homography(pixel_corners: np.ndarray) -> np.ndarray` — 4 pixel
    corners (same fixed order as `court.corner_points_m()`) → 3×3 H mapping
    pixels → metres; validates shape/order (raises `CalibrationError` on
    degenerate input).
  - `project_points(h: np.ndarray, pts_px: np.ndarray) -> np.ndarray` —
    wraps `cv2.perspectiveTransform` for (N, 2) float arrays.
  - `feet_point(bbox_xyxy: np.ndarray) -> np.ndarray` — bottom-centre of a
    bbox; `project_feet(h, bboxes) -> np.ndarray` composes the two. No other
    bbox→court path exists (the invariant lives here).
  - `Calibration` dataclass/pydantic model: name, pixel corners, H, video
    size, created date; `save(path)` / `load(path)` JSON round-trip.
  - `sanity_check(calib, clicked_service_pts_px) -> float` — reprojection
    error in px against `court.front_service_intersections_m()`;
    `check_or_warn(...)` returns a warning string when error > 20 px.
- `pick_corners(video_path) -> np.ndarray` interactive helper (cv2 window,
  click 4 corners on a paused frame, keys documented) — excluded from
  coverage, guarded so importing the module never opens a window.
- A synthetic full-loop test proves metres-in → pixels → metres-out
  round-trips to < 1e-6 with an exact synthetic camera.
- `pytest` green without ultralytics/mediapipe installed.

## Test plan

RED first in `badminton_track/tests/test_calibrate.py`:

- `test_identity_homography_round_trip`
- `test_synthetic_perspective_round_trip_metres_to_pixels_and_back`
- `test_degenerate_corners_raise_calibration_error`
- `test_feet_point_is_bbox_bottom_centre`
- `test_project_feet_projects_only_feet_points`
- `test_calibration_json_round_trip_preserves_h_exactly`
- `test_sanity_check_zero_error_for_perfect_clicks`
- `test_sanity_check_warns_beyond_20px`

## Implementation plan

1. `calibrate.py`: `CalibrationError(Exception)`; `build_homography` using
   `cv2.getPerspectiveTransform(px.astype(np.float32),
   court.corner_points_m().astype(np.float32))` (exact 4-point solution per
   research; `findHomography`+RANSAC deliberately not used).
2. `project_points`: reshape to `(N, 1, 2)` float64 →
   `cv2.perspectiveTransform` → back to `(N, 2)`.
3. `feet_point` / `project_feet` as the single sanctioned bbox path.
4. `Calibration` (pydantic) with `to_json`/`from_json`; H stored as nested
   lists, restored with `np.asarray`.
5. `sanity_check`: project clicked px points to metres, compare against the
   court-model intersections **in pixel space** (inverse H) so the threshold
   is in px as specced.
6. `pick_corners` behind `if __name__ == "__main__"`-style lazy cv2 usage;
   docstring documents click order.
7. Full `pytest` run.
