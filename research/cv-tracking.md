# Research: cv-tracking

**Date:** 2026-07-05
**Triggering use-case:** [BadmintonTrack-12](../ideas/use-cases/badmintontrack-12.md) (Modules 1–2)

## Need summary

Track ONE target badminton player (a 12-year-old, filmed from a rear elevated
iPhone at 1080p60, multiple people always in frame) on a court, keep a stable
identity across frames, project the player's *feet* (bbox bottom-centre) through
a 4-corner court homography into real metres (13.4 m × 6.1 m), and feed the
resulting per-frame positions into footwork metrics. Hard constraints: fully
local/offline (footage of a minor — no cloud), modest Apple Silicon Mac,
Python 3.11+, pip-installable, pytest-friendly; permissive licences preferred.

## Candidates evaluated

Scoring: functionality fit 30% · maintenance 20% · community 20% ·
documentation 15% · licence 10% · dependency footprint 5%. Each axis 1–5.
Stars / last-activity verified 2026-07-05 by fetching the GitHub repo pages
unless marked ~ (unverified).

| # | Name | What | Stars | Last activity | Licence | Weighted | Decision |
|---|------|------|-------|--------------|---------|---------:|----------|
| 1 | OpenCV (`opencv-python`) | Homography build/apply (`getPerspectiveTransform`, `perspectiveTransform`), video I/O, drawing | 80k+ ~ | continuous | Apache-2.0 | **4.95** | **adopt** |
| 2 | [supervision](https://github.com/roboflow/supervision) (Roboflow) | CV utility belt: `Detections`, `PolygonZone`, annotators, `VideoSink` | 46.8k | 2026-06-23 (v0.29.1) | MIT | **4.65** | **adopt** (annotation/zones) |
| 3 | [ultralytics](https://github.com/ultralytics/ultralytics) | YOLO11 detection + built-in ByteTrack/BoT-SORT via `model.track()` | 59.1k | 2026-07-05 (v8.4.88) | AGPL-3.0 | **4.60** | **adopt** (core detector+tracker) |
| 4 | [roboflow/trackers](https://github.com/roboflow/trackers) | Clean-room Apache re-impls: SORT, ByteTrack, OC-SORT, BoT-SORT, C-BIoU; detector-agnostic | 3.5k | 2026-06-24 (v2.5.0) | Apache-2.0 | **4.15** | skip (fallback if leaving AGPL) |
| 5 | [boxmot](https://github.com/mikel-brostrom/boxmot) | Pluggable SOTA MOT (ByteTrack, BoT-SORT, StrongSORT, OC-SORT, BoostTrack…) + ReID | 8.2k | 2026-06-03 (v21.0.0) | AGPL-3.0 | **3.95** | skip |
| 6 | [rf-detr](https://github.com/roboflow/rf-detr) | Real-time DETR detector (Nano 30.5M params), permissive alternative to YOLO | 8.4k | 2026-06-29 (v1.8.3) | Apache-2.0 (base) / PML (XL) | **3.85** | skip (permissive detector fallback) |
| 7 | [norfair](https://github.com/tryolabs/norfair) | Lightweight Kalman point/bbox tracker for any detector | 2.7k | 2025-04-30 (v2.3.0) | BSD-3-Clause | **3.45** | skip |
| 8 | [roboflow/sports](https://github.com/roboflow/sports) | Sports CV utils: pitch keypoints, `ViewTransformer` homography wrapper (soccer/basketball only) | 5.1k | active ~ (date not shown on page) | MIT | **3.35** | skip (copy `ViewTransformer` pattern) |
| 9 | [mmtracking](https://github.com/open-mmlab/mmtracking) | OpenMMLab MOT/SOT/VID toolbox | 3.9k | 2022-10-11 (1.0.0rc1) — stale | Apache-2.0 | 2.90 | skip |
| 10 | [deep_sort_realtime](https://github.com/levan92/deep_sort_realtime) | Practical DeepSORT with built-in embedders | 245 | 2023-02-11 (v1.3.2) — stale | MIT | 2.85 | skip |
| 11 | [SoloShuttlePose](https://github.com/sunwuzhou03/SoloShuttlePose) | Badminton singles: court/net detection, player tracking, shuttle, events | 65 | recent dates not shown ~ | MIT | 2.40 | skip (reference reading) |
| 12 | [TennisCourtDetector](https://github.com/yastrebksv/TennisCourtDetector) | Heatmap CNN detecting 14 tennis-court keypoints + homography refine | 266 | dates not shown ~ | none found ⚠ | 2.10 | skip |
| 13 | [monotrack](https://github.com/jhwang7628/monotrack) | Badminton 3D shuttle trajectory + court detection (research code, mmdet/mmpose) | 53 | stale ~ | "view licence" ⚠ unverified | 1.85 | skip |

Axis scores for the top 8 (fit/maint/community/docs/licence/deps):
OpenCV 5/5/5/5/5/5 · supervision 4/5/5/5/5/4 · ultralytics 5/5/5/5/2/3 ·
trackers 4/5/3/4/5/5 · boxmot 4/5/4/4/2/3 · rf-detr 3/5/4/4/4/3 ·
norfair 3/3/3/4/5/5 · sports 2/4/4/3/5/4.

## Per-candidate notes (top 8)

**OpenCV — adopt.** Module 1 *is* OpenCV: `cv2.getPerspectiveTransform` on the
4 clicked corners → 3×3 H mapping pixels → court metres, `cv2.perspectiveTransform`
to project feet points at runtime. For exactly 4 hand-clicked correspondences,
`getPerspectiveTransform` is the right call (exact solution, deterministic —
easy to unit-test with synthetic points); `cv2.findHomography(..., cv2.RANSAC)`
only becomes preferable if we ever move to >4 auto-detected keypoints with
outliers. Already a transitive dep of ultralytics, so zero added footprint.

**supervision — adopt (helper).** MIT, huge community, very active. Its
`sv.Detections.from_ultralytics()` bridge, `PolygonZone` (clean way to express
"detections whose feet fall inside the near court half"), box/trace annotators
and `VideoSink` remove most of the boilerplate for the annotated court-map
video deliverable. Note its bundled `sv.ByteTrack` is deprecated since 0.28.0
(removal in 0.30.0) in favour of the `trackers` package — we don't need it
since tracking comes from ultralytics; use supervision only for zones and
drawing.

**ultralytics — adopt (core).** The pragmatic centre of the stack:
`YOLO("yolo11n.pt").track(persist=True, tracker="bytetrack.yaml", classes=[0])`
gives detection + stable IDs in one dependency, runs on Apple Silicon via
`device="mps"`, nano model fits the modest-hardware constraint, and the docs are
excellent (tunables: raise `track_buffer` / adjust `match_thresh` if IDs churn
during occlusion at the net). The one wart is the **AGPL-3.0 licence** — not
permissive. For a private, local, non-distributed personal tool this is a
non-issue; it only bites if BadmintonApp is ever distributed/hosted as a
product, in which case swap to RF-DETR + roboflow/trackers (both Apache-2.0) —
the pipeline seam (detector+tracker behind one function returning per-frame
`(track_id, bbox)`) should be designed so that swap is cheap.

**roboflow/trackers — skip (documented fallback).** New-ish (v2.5.0, June 2026)
Apache-2.0 clean-room ByteTrack/BoT-SORT/OC-SORT that plugs into any detector
via `supervision.Detections`. Exactly the AGPL-escape hatch: RF-DETR (or any
permissive detector) + `ByteTrackTracker` reproduces our pipeline permissively.
Not adopted now because ultralytics' built-in tracking is one less moving part
and one less association-format bug surface.

**boxmot — skip.** The most complete tracker zoo (StrongSORT, BoostTrack, ReID
models) and actively maintained, but it is *also* AGPL, so it buys no licence
freedom over ultralytics' built-in ByteTrack while adding a second heavyweight
dependency. ReID-grade appearance matching is overkill for "which of 2–3 people
is on the near court half" — the homography filter solves target lock more
robustly than embeddings would.

**rf-detr — skip (fallback detector).** Apache-2.0 base models, very active,
Nano variant exists; but benchmarks are TensorRT/GPU-oriented and Apple-Silicon
CPU/MPS throughput is unproven for 60 fps video, and it ships no tracker.
Recorded as the permissive detector to pair with roboflow/trackers if the AGPL
constraint ever materialises.

**norfair — skip.** Nice, tiny, BSD-3 Kalman tracker that would happily track a
single feet-point per person, but last release is April 2025, community is
smaller, and it duplicates what `model.track()` already gives us for free.
Would only reconsider if ultralytics' ByteTrack proved flaky on this footage.

**roboflow/sports — skip, copy the pattern.** MIT sports-CV utilities, but the
court configs are soccer/basketball only — no badminton geometry — and its
`ViewTransformer` is a thin (~30-line) wrapper around exactly the two OpenCV
calls above. Adopting the repo (install from git, unpinned) for that wrapper is
worse than writing our own `calibrate.py` with the badminton court model in
metres; its keypoint→homography design is still the reference pattern for a
future auto-calibration upgrade.

## Recommendation

Concrete stack for Modules 1–2 (all local, pip-installable):

- **Detection + tracking:** `ultralytics` with **`yolo11n.pt`** (YOLO11 nano —
  note: *not* `yolov11n.pt`), `model.track(frame, persist=True,
  tracker="bytetrack.yaml", classes=[0], device="mps", verbose=False)` frame-by-frame
  (every 3rd frame → 20 Hz effective per the use-case). If IDs churn, tune a
  copied `bytetrack.yaml` (`track_buffer` up from 30, `match_thresh` down).
- **Homography (Module 1):** plain OpenCV, written ourselves (~100 lines in
  `calibrate.py`): 4 clicked corners → `cv2.getPerspectiveTransform(px_corners,
  metre_corners)` with metre corners from the real court model (13.4 × 6.1 m);
  runtime projection with `cv2.perspectiveTransform` applied **only to feet
  points** (bbox bottom-centre) — the court-plane invariant from the use-case.
  Keep the 2-click front-service-line reprojection sanity check. No helper lib
  earns its keep here; `roboflow/sports`' `ViewTransformer` confirms the
  pattern is this small.
- **Target-player lock:** project every track's feet through H, keep the track
  ID whose projected position lies in the near half (y in [half-court, 13.4 m]
  in court coords); hysteresis so the lock survives brief near-net excursions.
- **Annotation / court map (optional but recommended):** `supervision` (MIT)
  for `Detections.from_ultralytics`, `PolygonZone`, trace/box annotators and
  `VideoSink`; do *not* use its deprecated `sv.ByteTrack`.
- **Licence posture:** ultralytics is AGPL-3.0 — acceptable for this private
  local tool; the documented permissive fallback is RF-DETR-Nano (Apache-2.0)
  + `trackers.ByteTrackTracker` (Apache-2.0). Keep the detector+tracker behind
  a single narrow interface so the swap stays a one-file change.
- **Testing:** homography + feet-projection + near-half filter + episode
  metrics are pure functions over numpy arrays — unit-test with synthetic
  correspondences and fabricated tracks; no model download needed in CI.

## Search log

Queries run (WebSearch, 2026-07-05), all returned useful results unless noted:

1. `Ultralytics YOLO11 ByteTrack model.track persist=True person tracking best practice` — rich; official docs confirm the persist pattern and tuning knobs (`track_buffer`, `match_thresh`).
2. `boxmot mikel-brostrom github multi-object tracking library 2026` — good.
3. `roboflow supervision library ByteTrack tracker github stars license` — surfaced the new `roboflow/trackers` split, which changed the shortlist.
4. `Norfair tryolabs tracking library maintained 2025 2026` — good; last release Apr 2025.
5. `roboflow sports library github homography court keypoint detection license` — confirmed soccer/basketball-only configs; no badminton.
6. `badminton court detection github homography` — thin: only small research repos (SoloShuttlePose 65★, MonoTrack 53★, pipeline-repro); no maintained badminton court library exists.
7. `tennis court detector github yastrebksv keypoints homography` — good detail but repo has no visible licence.
8. `mmtracking OpenMMLab deprecated unmaintained status` — search inconclusive; repo page fetch confirmed last release Oct 2022 (effectively dead).
9. `cv2.getPerspectiveTransform vs findHomography four points best practice sports court metres projection` — confirmed: exact-4-points → `getPerspectiveTransform`; `findHomography`+RANSAC for >4/noisy points.
10. `supervision ByteTrack deprecated moved to trackers library roboflow` — confirmed deprecation since supervision 0.28.0, removal in 0.30.0.

Verification: repo pages fetched directly (WebFetch) for ultralytics,
supervision, trackers, boxmot, norfair, mmtracking, sports, rf-detr,
TennisCourtDetector, SoloShuttlePose, monotrack, deep_sort_realtime. GitHub API
was not usable in this session (proxy-gated), so commit dates for repos whose
pages didn't render dates (sports, SoloShuttlePose, TennisCourtDetector,
monotrack) are marked ~ unverified. OpenCV metadata is common knowledge, marked ~.
