# Research: pose-biomechanics

**Date:** 2026-07-05
**Triggering use-case:** ../ideas/use-cases/badmintontrack-12.md (Module 3 — biomechanics, side profile view)

## Need summary

From side-profile 1080p60 iPhone clips of a junior player, extract 2D joint
angles — knee lunge angle (hip–knee–ankle) and smash arm extension
(shoulder–elbow–wrist) — inside manually-defined analysis windows, at the full
60 fps (no frame skipping: a smash swing is a 100–200 ms event). Per-frame
landmark **visibility filtering** (~0.5 threshold) before smoothing, then
zero-phase Butterworth (`scipy.signal.filtfilt`, ≈6 Hz cutoff, fs = 60 Hz).

Hard constraints: fully local/offline (footage of a minor — no cloud), Apple
Silicon Mac, Python 3.11+, pytest-friendly modular code, permissive licences
strongly preferred. The pipeline already depends on `ultralytics` (Module 2)
and `scipy`/`pandas`.

**Headline risk investigated:** the `mediapipe` PyPI package's mid-2026 state.
Verdict up front: the package is alive and healthy (0.10.35, released
2026-04-27/28, Apache-2.0, macOS arm64 wheels tagged `py3-none` so they cover
3.11/3.12), **but the legacy `mp.solutions.pose` API the use-case doc
implicitly assumed has been physically removed from the wheels** — from
0.10.31 (late 2025) the package ships only `mediapipe.tasks` (+`Image`,
`ImageFormat`); verified via [issue #6192](https://github.com/google-ai-edge/mediapipe/issues/6192).
Legacy Solutions were EOL'd back in March 2023; the C-API/"API3" migration in
0.10.32 completed the switch. **Module 3 must be written against the Tasks
`PoseLandmarker` API, not `mp.solutions.pose.Pose`.** Any tutorial code using
`mp.solutions` only runs on wheels pinned ≤0.10.21 — do not do that.

## Candidates evaluated

Weights: functionality fit 30% · maintenance 20% · community 20% ·
documentation 15% · licence 10% · dependency footprint 5%. Stars/dates
verified by fetching repo/PyPI pages on 2026-07-05 unless marked (unverified).

| Name | What | Stars | Last activity | Licence | Weighted | Decision |
|---|---|---|---|---|---|---|
| mediapipe — **Tasks `PoseLandmarker`** | 33-landmark BlazePose w/ per-landmark visibility+presence, VIDEO mode | 36k | v0.10.35, 2026-04-28 | Apache-2.0 | **4.60** | **adopt** |
| ultralytics YOLO11-pose | COCO-17 keypoint pose head on YOLO11; already a Module-2 dep | 59.1k | v8.4.88, 2026-07-05 | AGPL-3.0 | 4.30 | skip (for this module; keep as documented fallback) |
| Sports2D | Turnkey video → 2D joint/segment angles CLI (RTMPose backend, Butterworth 6 Hz default) | 256¹ | v0.8.32, 2026-06-08 | BSD-3-Clause | 4.05 | skip as dep — use as **cross-validation reference** |
| rtmlib (RTMPose) | RTMPose/DWPose/RTMO via ONNX Runtime, no mm* deps | 629 | v0.0.15, 2026-02-10 | Apache-2.0 | 3.80 | skip (backup backend if mediapipe wheel breaks) |
| Pose2Sim | Multi-camera 2D→3D OpenSim k