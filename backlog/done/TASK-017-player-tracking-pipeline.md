# TASK-017 - Player tracking pipeline: YOLO11+ByteTrack wrapper, target lock, telemetry

**Use case:** [ideas/use-cases/badmintontrack-12.md](../../ideas/use-cases/badmintontrack-12.md)
**Research:** [research/cv-tracking.md](../../research/cv-tracking.md)
**Depends on:** TASK-014, TASK-015, TASK-016
**Effort:** M
**Risk:** medium

**Status:** done

## Goal

Module 2's video pipeline: read a rear-view video at every 3rd frame
(≈20 Hz), run ultralytics YOLO11-nano with built-in ByteTrack behind a
**narrow, mockable interface**, lock onto the target player by projecting
every track's feet through the TASK-015 homography and keeping the track on
the near court half (with hysteresis so the lock survives brief near-net
excursions), and emit the TASK-016 telemetry DataFrame (NaN rows for missed
detections) persisted to `data/` as CSV. The ultralytics import lives inside
one function so the whole pipeline is testable with fabricated tracker
output and no model download; AGPL containment and the RF-DETR escape hatch
both hang on this seam.

## Acceptance criteria

- `src/badminton_track/footwork.py` with:
  - `RawTrack` record: `frame_idx`, `t`, `track_id`, `bbox_xyxy` (np array).
  - `iter_tracks(video_path, cfg) -> Iterator[list[RawTrack]]` — the ONLY
    place ultralytics is imported (lazy, inside the function); uses
    `YOLO(cfg.detector_tag).track(frame, persist=True,
    tracker="bytetrack.yaml", classes=[0], verbose=False)` on every
    `cfg.frame_stride`-th frame; missing extra → `ExtrasMissingError` with
    the pip command in the message.
  - `lock_target(frames: Iterable[list[RawTrack]], calib, cfg)
    -> pd.DataFrame` — pure: projects feet via
    `calibrate.project_feet`, scores each track id by time spent inside
    `court.near_half_polygon_m()`, locks the best id, keeps it while it
    reappears within `cfg.lock_grace_s` (hysteresis), switches only after
    sustained absence; emits telemetry rows (`t`, `x_m`, `y_m`) with NaN
    when the locked player is undetected.
  - `run_footwork(video_path, calib, cfg) -> pd.DataFrame` — composition +
    `data/<video-stem>-telemetry.csv` write (dir from config, gitignored).
- Telemetry passes straight into `metrics.detect_episodes` (contract test).
- `pytest` green without ultralytics installed (mocked frames); the
  ultralytics-touching path is import-guarded and covered by a
  `pytest.mark.skipif(not has_ultralytics)` smoke test only.

## Test plan

RED first in `badminton_track/tests/test_footwork.py` (all with fabricated
`RawTrack` frames):

- `test_lock_target_picks_track_on_near_half`
- `test_lock_survives_brief_disappearance_within_grace`
- `test_lock_ignores_opponent_on_far_half`
- `test_lock_switches_after_sustained_absence`
- `test_missing_frames_become_nan_rows`
- `test_telemetry_time_axis_uses_frame_stride`
- `test_telemetry_feeds_metrics_detect_episodes` (contract)
- `test_iter_tracks_raises_extras_missing_without_ultralytics`
- `test_run_footwork_writes_csv` (tmp_path, mocked iter_tracks)

## Implementation plan

1. `errors.py` (or in `footwork.py`): `ExtrasMissingError`.
2. `iter_tracks`: `cv2.VideoCapture` loop, stride from config,
   `t = frame_idx / fps`; convert ultralytics `results[0].boxes` (id, xyxy)
   to `RawTrack`s; lazy `from ultralytics import YOLO` inside, wrapped in
   try/except ImportError.
3. `lock_target`: two passes — (a) warmup scoring window
   (`cfg.lock_warmup_s`, default ~2 s) to pick the initial id via
   point-in-polygon (matplotlib.path or shapely-free manual test) on
   projected feet; (b) sweep emitting telemetry with grace-window hysteresis
   (`cfg.lock_grace_s`, default 1.0 s).
4. `run_footwork`: compose, ensure `data/` exists, write CSV via
   `df.to_csv`.
5. Add `lock_warmup_s` / `lock_grace_s` / `data_dir` to `FootworkConfig`
   (TASK-014's model, `extra="forbid"` keeps this an explicit change).
6. Full `pytest` run.
