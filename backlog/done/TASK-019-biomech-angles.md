# TASK-019 - Biomechanics: joint angles from PoseLandmarker, smoothing, windows

**Use case:** [ideas/use-cases/badmintontrack-12.md](../../ideas/use-cases/badmintontrack-12.md)
**Research:** [research/pose-biomechanics.md](../../research/pose-biomechanics.md)
**Depends on:** TASK-014, TASK-018
**Effort:** M
**Risk:** medium

**Status:** done

## Goal

Module 3: extract knee-lunge (hip–knee–ankle) and smash-extension
(shoulder–elbow–wrist) 2D angles from side-profile clips at the FULL 60 fps
inside config-defined analysis windows, using MediaPipe **Tasks
`PoseLandmarker`** (`RunningMode.VIDEO` — the legacy `mp.solutions.pose` API
is dead per research and must not appear anywhere). Frames where any triplet
landmark has `visibility < 0.5` become NaN; short gaps interpolate, then
zero-phase Butterworth (`filtfilt`, 6 Hz, fs = 60) smooths the series. A
z-spread oblique-view warning guards the 2D-validity assumption. The
mediapipe import is confined to one wrapper function; angle math, filtering,
and windowing are pure and fully tested. Wires into the CLI's
`--mode biomech`.

## Acceptance criteria

- `src/badminton_track/biomech.py` with:
  - `LANDMARKS` table: right side shoulder 12 / elbow 14 / wrist 16, hip 24 /
    knee 26 / ankle 28; left-side equivalents (11/13/15, 23/25/27); side
    chosen via `BiomechConfig.camera_side`.
  - `triplet_angle(a, b, c) -> float` — degrees at vertex b via
    `atan2(|cross|, dot)`; pure 2D.
  - `angle_series(landmark_frames, triplet, visibility_threshold)
    -> pd.DataFrame` (`t`, `angle_deg` with NaN where any of the three
    landmarks is below threshold or the frame has no pose).
  - `smooth_series(series, fs, cutoff_hz) -> np.ndarray` — reuses
    `metrics.interpolate_gaps` policy for NaNs, then
    `scipy.signal.butter(4, cutoff, fs=fs)` + `filtfilt`; a documented test
    proves the peak sample index is unchanged (zero phase).
  - `oblique_view_warning(landmark_frames, triplet, threshold) -> str | None`
    from world-landmark z-spread across the triplet.
  - `AnalysisWindow(name, start_s, end_s, angle: "knee_lunge" |
    "smash_extension")` — parsed from `BiomechConfig.windows`.
  - `iter_pose_frames(video_path, cfg) -> Iterator[PoseFrame]` — the ONLY
    mediapipe import (lazy); `PoseLandmarkerOptions(...,
    running_mode=RunningMode.VIDEO, num_poses=1)` +
    `detect_for_video(image, timestamp_ms)` on EVERY frame (no striding —
    this module runs at 60 fps by design); `ExtrasMissingError` if the
    `biomech` extra is absent; `PoseFrame` carries normalized + world
    landmarks with visibility.
  - `run_biomech(video_path, cfg) -> pd.DataFrame` — per window: raw +
    smoothed series, min/max/range per rep window, oblique warning; CSV to
    `data/`, per-window summary rows returned.
- CLI `analyze <video> --mode biomech` (replacing the TASK-018 placeholder)
  writes the angle CSV + `<stem>-biomech-summary.json`.
- `pytest` green without mediapipe installed (fabricated `PoseFrame`s).

## Test plan

RED first in `badminton_track/tests/test_biomech.py`:

- `test_triplet_angle_right_angle_is_90`
- `test_triplet_angle_straight_line_is_180`
- `test_angle_series_nan_when_any_landmark_below_visibility`
- `test_angle_series_uses_configured_camera_side_indices`
- `test_smooth_series_zero_phase_peak_position_unchanged`
- `test_smooth_series_uses_effective_fs_60`
- `test_oblique_warning_triggers_on_large_z_spread`
- `test_windows_slice_series_by_time`
- `test_iter_pose_frames_raises_extras_missing_without_mediapipe`
- `test_run_biomech_summary_min_max_per_window` (mocked pose frames)
- `test_cli_analyze_biomech_writes_csv_and_summary` (in `test_cli.py`,
  mocked `run_biomech`)

## Implementation plan

1. `biomech.py`: landmark tables + `PoseFrame` dataclass
   (`t`, `landmarks: np.ndarray (33,4) [x,y,z,visibility]`,
   `world_landmarks` same shape or None).
2. Pure functions first (angle, series, smoothing, windows, oblique guard) —
   smoothing guards series shorter than `3 * max(len(a), len(b))` padlen
   (filtfilt constraint) by returning the input with a warning.
3. `iter_pose_frames`: lazy `from mediapipe.tasks.python import vision`;
   model asset path from config (`pose_landmarker_full.task`), timestamps
   `int(frame_idx / fps * 1000)`.
4. `run_biomech` + `BiomechConfig` additions (`camera_side`, `windows`,
   `oblique_z_spread_threshold`, `model_asset_path`).
5. Replace the CLI placeholder with `_cmd_analyze_biomech`.
6. Full `pytest` run.
