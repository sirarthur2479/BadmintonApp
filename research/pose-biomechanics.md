# Research: pose-biomechanics

**Date:** 2026-07-05 / **Triggering use-case:** ../ideas/use-cases/badmintontrack-12.md

## Need summary

From side-profile 1080p60 iPhone clips of a **12-year-old** player, extract 2D
joint angles inside manually-defined analysis windows (Module 3 of
BadmintonTrack-12):

- **Knee lunge angle** = angle at knee, from hip–knee–ankle.
- **Smash arm extension** = angle at elbow, from shoulder–elbow–wrist.

Requirements: run at **full 60 fps** (a smash swing is a 100–200 ms event — no
frame-skipping), **per-landmark visibility filtering** (drop frames where a
required joint is occluded, ~0.5 threshold) before smoothing, and **zero-phase
Butterworth** smoothing (`scipy.signal.filtfilt`, ~6 Hz cutoff at the true
60 Hz effective rate). Hard constraints: **fully local / offline** (footage of
a minor, no cloud AI), Apple Silicon Mac, Python 3.11+, pytest-friendly,
**permissive licence preferred**. 2D angles are valid only when the motion
plane is roughly parallel to the camera (sagittal side view) — the tool must
warn on oblique views.

Scoring weights: functionality fit 30% · maintenance 20% · community 20% ·
documentation 15% · licence 10% · dependency footprint 5%.

## Candidates evaluated

| Name | What | Stars | Last commit/release | Licence | Weighted | Decision |
|---|---|---|---|---|---|---|
| **MediaPipe Tasks — PoseLandmarker** | Google on-device 33-landmark pose, `mediapipe.tasks.vision` | 36k (repo) | v0.10.35, 28 Apr 2026 | Apache-2.0 | **4.95** | **adopt** |
| **Ultralytics YOLO11-pose** | COCO-17 keypoint model, already a Module-2 dep | 59.1k | v8.4.88, 5 Jul 2026 | AGPL-3.0 | **4.30** | build-on-top (fallback) |
| **Sports2D** | Turnkey 2D pose→joint-angle from side video, 6 Hz Butterworth built-in | 256 | v0.8.32, 8 Jun 2026 | BSD-3 | **4.30** | build-on-top (reference) |
| **rtmlib (RTMPose)** | Lightweight ONNX pose, no mmcv | 629 | v0.0.15, 10 Feb 2026 | Apache-2.0 | 3.75 | skip (via Sports2D) |
| MediaPipe **legacy** `solutions.pose` | Old `mp.solutions.pose.Pose` API | 36k | support ended 2023-03; removed from wheel ~0.10.31 | Apache-2.0 | 3.55 | **skip** |
| MMPose | OpenMMLab pose toolbox | 7.7k | v1.3.2, 12 Jul 2024 | Apache-2.0 | 3.55 | skip |
| Pose2Sim | Multi-cam 2D→3D OpenSim kinematics | 710 | active 2026 | BSD-3 | 3.35 | skip (overkill) |
| MoveNet | TF Hub/TFLite 17-kpt single-pose | n/a | model stable, TF-Hub aging | Apache-2.0 | 2.95 | skip |
| lightweight-openpose (Daniil-Osokin) | CPU OpenPose-lite, 18 kpts | ~2k | dormant | Apache-2.0 | 2.75 | skip |
| OpenPose (CMU) | Classic multi-person 135-kpt | 34.2k | v1.7.0, Nov 2020 | **non-commercial only** | 2.50 | skip |
| BlazePose PyTorch ports (zmurez etc.) | Hobby TFLite→PyTorch/ONNX ports | <1k | dormant | mixed | 2.10 | skip |
| **scipy.signal** (supporting, unscored) | `butter` + `filtfilt` zero-phase smoothing | — | active | BSD-3 | — | **adopt** |

## Per-candidate notes (top 8)

### 1. MediaPipe Tasks — PoseLandmarker  *(adopt)* — 4.95
The current, actively maintained Google API (`mediapipe.tasks.python.vision.PoseLandmarker`).
Verified from source (`mediapipe/tasks/python/vision/pose_landmarker.py` on
master + `.../containers/landmark.py`):
- `PoseLandmarkerResult.pose_landmarks` is `list[list[NormalizedLandmark]]`;
  **`NormalizedLandmark` carries both `visibility` and `presence` floats** —
  exactly the per-joint occlusion signal the use-case's visibility filter
  needs. 33 landmarks (BlazePose topology).
- `RunningMode.VIDEO` + `detect_for_video(image, timestamp_ms)` is purpose-built
  for frame-accurate 60 fps decode with monotonic timestamps.
- Options: `num_poses` (default 1 — perfect, side clips have one subject),
  `min_pose_detection_confidence`, `min_pose_presence_confidence`,
  `min_tracking_confidence` (all default 0.5).
- Model is a downloadable `.task` file (lite/full/heavy) — ships offline, no
  network at inference. Apache-2.0. `pip install mediapipe`; latest **0.10.35
  (28 Apr 2026)**, macOS arm64 wheel published
  (`mediapipe-0.10.35-py3-none-macosx_11_0_arm64.whl`), tested on Python
  3.9–3.12. **Best fit by far**: gives z-coordinate spread for the oblique-view
  warning and native visibility scores that no COCO-keypoint model provides.
- Minor risk: past arm64 wheel-tag mislabelling (issue #6112) — pin a known-good
  version in `pyproject.toml` and CI-test the import on macOS arm64.

### 2. Ultralytics YOLO11-pose  *(build-on-top, fallback)* — 4.30
Already the Module-2 dependency (`yolo11n.pt`), so `yolo11n-pose.pt` adds no new
stack. Outputs **COCO-17** keypoints with per-keypoint confidence; the 17 points
include shoulder/elbow/wrist/hip/knee/ankle, enough for both angles. Downsides
vs MediaPipe for *this* module: (a) confidence is not a true occlusion
`visibility` score, (b) 2D only — no z, so the oblique-view sanity check must be
done differently, (c) **AGPL-3.0** copyleft. AGPL is tolerable for a private,
never-distributed personal tool but is a real constraint if the tool is ever
shared. Keep as the fallback if a MediaPipe arm64 wheel problem recurs.

### 3. Sports2D  *(build-on-top / reference)* — 4.30
Remarkably on-target: computes exactly the joint angles we need (**knee, hip,
elbow, shoulder** + segment angles) from a single side-view video, and its
**default filter is a 6 Hz Butterworth** — the same choice the use-case
specifies, independent confirmation that 6 Hz is the right cutoff for human
movement. Explicitly documents the same planar/sagittal constraint. BSD-3,
Python 3.11–3.13, active (v0.8.32, Jun 2026), JOSS paper. It uses **RTMPose (via
rtmlib)** as its backend, not MediaPipe. Decision is *build-on-top / reference*
rather than adopt: pulling Sports2D in wholesale drags the full rtmlib +
onnxruntime + OpenSim-oriented stack and its own I/O conventions (.trc/.mot/.c3d)
into a project that only needs two angles inside config-defined windows. Mine it
for its angle-definition and filtering conventions; don't take it as the runtime
dependency.

### 4. rtmlib (RTMPose)  *(skip — reachable via Sports2D if needed)* — 3.75
Clean, lightweight (numpy + opencv + onnxruntime, **no mmcv/torch**), Apache-2.0,
returns keypoints + scores, supports 17/26/133-kpt models and `mps` device on
macOS. Genuinely good and license-clean. Skipped as a *direct* dependency
because it still requires you to build the angle + visibility + windowing layer
yourself, and for that MediaPipe gives more out of the box (native visibility,
z-spread, VIDEO mode). It's the engine inside Sports2D, so it's available
indirectly if MediaPipe is ever ruled out.

### 5. MediaPipe legacy `solutions.pose`  *(skip)* — 3.55
The old `mp.solutions.pose.Pose(...)` API most tutorials still show. **Do not
build on it.** Google ended legacy-solutions support on 2023-03-01, and — per
issue #6192 (Dec 2025) — the `mediapipe.solutions` module has been **dropped
from the Python wheel around 0.10.31** (package shrank 35.6 MB → 10.3 MB; only
`mediapipe.Image`, `ImageFormat`, `tasks` remain). Pinning an old wheel to keep
it is a dead end on a new project. Use Tasks PoseLandmarker instead. *(Exact
removal version not called out in release notes 0.10.30–0.10.35; inferred from
the issue report — mark as unverified-to-the-version.)*

### 6. MMPose  *(skip)* — 3.55
Powerful and accurate, Apache-2.0, but last release **v1.3.2 (Jul 2024)** —
stagnating — and the **mmcv/mmengine dependency chain** is notoriously painful
to install on Apple Silicon. Too heavy for two angles.

### 7. Pose2Sim  *(skip — overkill)* — 3.35
Multi-camera 2D→3D markerless kinematics for OpenSim. Its own docs redirect
single-camera users to Sports2D. Wrong tool for single-view planar 2D angles.

### 8. MoveNet  *(skip)* — 2.95
Fast 17-kpt single-pose model, Apache-2.0. But it ties you to the TensorFlow /
TF-Hub / TFLite ecosystem (heavier and more fragile on macOS arm64 than a single
`pip install mediapipe`), gives only 2D + confidence (no visibility, no z), and
the TF-Hub distribution channel is aging. No advantage over MediaPipe here.

*(Below the top 8: lightweight-openpose 2.75, OpenPose 2.50 — non-commercial
licence + a 2020 build-from-source with no arm64 story, BlazePose hobby ports
2.10 — unmaintained. All skip.)*

## Recommendation

**Adopt MediaPipe Tasks `PoseLandmarker` (package `mediapipe`, ≥ 0.10.35) with
`scipy.signal` for smoothing.** It is the correct, actively-maintained API — the
legacy `mp.solutions.pose` path is deprecated and no longer ships in the wheel,
so any tutorial using it must be ignored. PoseLandmarker is the only strong
candidate that natively provides a per-landmark **`visibility`** score (needed
for the occlusion filter) *and* a z-coordinate (needed for the oblique-view
warning), plus a first-class `RunningMode.VIDEO` / `detect_for_video(...)` path
for frame-accurate 60 fps. Keep **YOLO11-pose as the documented fallback** (it's
already a Module-2 dep) if a macOS arm64 wheel issue blocks MediaPipe.

**Exact API:**
```python
from mediapipe.tasks.python import vision, BaseOptions
from mediapipe.tasks.python.vision import RunningMode

options = vision.PoseLandmarkerOptions(
    base_options=BaseOptions(model_asset_path="pose_landmarker_full.task"),
    running_mode=RunningMode.VIDEO,
    num_poses=1,
    min_pose_detection_confidence=0.5,
    min_pose_presence_confidence=0.5,
    min_tracking_confidence=0.5,
)
landmarker = vision.PoseLandmarker.create_from_options(options)
# per frame: result = landmarker.detect_for_video(mp_image, timestamp_ms)
# result.pose_landmarks[0][idx].{x, y, z, visibility}
```
Ship the `.task` model file with the repo (offline). Use the **`full`** model
(better accuracy than `lite` for angle precision; `heavy` only if throughput
allows).

**Landmark indices** (MediaPipe 33-point BlazePose topology; pick the side facing
the camera — right side shown for a right-hander filmed from their right):

| Angle | Vertex | Triplet (indices) |
|---|---|---|
| Smash arm extension | elbow | shoulder **12** – elbow **14** – wrist **16** |
| Knee lunge | knee | hip **24** – knee **26** – ankle **28** |

Left-side equivalents: shoulder 11 / elbow 13 / wrist 15; hip 23 / knee 25 /
ankle 27. Make the side a config field (the report already records camera side).

**Angle computation:** 2D only — use x,y (ignore z for the angle itself):
`θ = atan2(|(a−b) × (c−b)|, (a−b)·(c−b))` for triplet a–b–c, converted to
degrees.

**Visibility threshold:** drop a frame's angle if *any* of the three landmarks
in that triplet has `visibility < 0.5`. Emit NaN for dropped frames;
interpolate gaps shorter than ~0.5 s (per the Module-2 convention) before
filtering, flag longer gaps.

**Oblique-view guard:** compute z-spread across the triplet's landmarks
(`pose_world_landmarks` z is metric-ish); warn if it exceeds a threshold,
signalling the plane is not parallel to the camera and 2D angles are unreliable.

**Filtering (scipy, supporting lib — BSD-3):** zero-phase Butterworth, applied
to the per-frame angle series *after* NaN interpolation:
```python
from scipy.signal import butter, filtfilt
b, a = butter(N=4, Wn=6.0, btype="low", fs=60.0)   # 6 Hz cutoff, fs = EFFECTIVE rate
angle_smooth = filtfilt(b, a, angle_series)         # zero-phase, no lag
```
Critical: `fs` must be the **effective** sample rate (60 Hz here — no skipping
in this module; 20 Hz in Module 2 if smoothing there). `filtfilt` is mandatory
over `lfilter` — a causal filter adds phase lag that shifts every measured angle
and corrupts peak-timing metrics. Sports2D independently defaults to the same
6 Hz Butterworth, corroborating the cutoff choice.

## Search log

- WebSearch: "mediapipe python package 2026 maintenance status deprecated legacy solutions PoseLandmarker" → PyPI, GitHub releases, issue #6192, #5155.
- WebSearch: "mediapipe pypi macos arm64 python 3.12 wheel 2025 2026" → PyPI, mediapipe-silicon, build docs, issue #6112 (arm64 tag mislabelling).
- WebSearch: "Sports2D joint angles video python 2026" → GitHub, PyPI, JOSS paper.
- WebSearch: "rtmlib RTMPose lightweight pose estimation python onnxruntime 2026" → GitHub Tau-J/rtmlib, PyPI.
- WebSearch: "mediapipe.solutions removed 0.10.31 legacy pose migrate tasks PoseLandmarker" → issue #6192, #5155, dev docs.
- WebSearch: "MoveNet thunder python local inference 2026" → TF Hub, GitHub ports.
- WebSearch: "BlazePose port pytorch onnx standalone github" → zmurez/MediaPipePyTorch, tf-blazepose, lightweight-openpose, others.
- WebFetch: pypi.org/project/mediapipe/ → 0.10.35 (28 Apr 2026), Py 3.9–3.12, macOS arm64 wheel, Apache-2.0, legacy support ended 2023-03.
- WebFetch: github.com/google-ai-edge/mediapipe → 36k stars, Apache-2.0, active, focus shifted to Tasks/Solutions.
- WebFetch: github.com/google-ai-edge/mediapipe/issues/6192 → `mediapipe.solutions` gone in 0.10.31 (wheel 35.6→10.3 MB); only tasks/Image/ImageFormat remain (initial report; no maintainer reply captured — unverified maintainer stance).
- WebFetch: raw pose_landmarker.py (master) → VIDEO mode, detect_for_video, num_poses/min_*_confidence options, result structure.
- WebFetch: raw landmark.py (master) → **confirmed** NormalizedLandmark has `visibility` and `presence` float fields.
- WebFetch: github.com/davidpagnon/Sports2D → 256 stars, BSD-3, v0.8.32 (Jun 2026), RTMPose backend, default 6 Hz Butterworth, Py 3.11–3.13.
- WebFetch: github.com/Tau-J/rtmlib → 629 stars, Apache-2.0, v0.0.15 (Feb 2026), numpy/opencv/onnxruntime, mps device, keypoints+scores.
- WebFetch: github.com/ultralytics/ultralytics → 59.1k stars, AGPL-3.0, v8.4.88 (5 Jul 2026), COCO-Pose keypoints.
- WebFetch: github.com/open-mmlab/mmpose → 7.7k stars, Apache-2.0, v1.3.2 (Jul 2024, stagnating), needs mmcv/mmengine.
- WebFetch: github.com/CMU-Perceptual-Computing-Lab/openpose → 34.2k stars, v1.7.0 (Nov 2020), non-commercial licence.
- WebFetch: github.com/perfanalytics/pose2sim → 710 stars, BSD-3, multi-cam 3D, redirects single-cam users to Sports2D.
- WebFetch: developers.google.com PoseLandmarker guide → **403 Forbidden** (both URLs); details recovered from source files instead.

Search quality: **good** — 12 candidates evaluated, key facts (MediaPipe status,
arm64 wheels, visibility field, licences, stars/recency) verified against
primary sources (PyPI, GitHub repos/source). One unverified point flagged: the
exact wheel version that dropped `mediapipe.solutions` (from the issue report,
not confirmed in release notes) and the absence of a captured maintainer reply.
