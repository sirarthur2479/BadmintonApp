# Research: shuttle-tracking

**Date:** 2026-07-12
**Triggering use-case:** [Match-point analysis & opponent profiling](../ideas/use-cases/match-point-analysis.md) (Phase 2 — shuttle tracking, explicitly gated on this doc)

## Need summary

Automatically extract per-point records from junior singles match footage:
detect the shuttlecock frame-by-frame, segment the video into rallies (point
boundaries + `videoTimestampMs`), infer rally length (hit count), the ending
shot type, and the landing zone — emitting the same `PointRecord` contract
phase 1 fills by hand. Hard constraints: 1080p60 iPhone footage from a rear
elevated view (footage of a minor — fully local, no cloud), modest Apple
Silicon Mac, Python 3.11+, pip-installable, pytest-friendly, must fit the
existing `badminton_track` stack (ultralytics YOLO11 + ByteTrack, OpenCV
homography, MediaPipe pose). Permissive licences preferred; AGPL tolerated.
Repo invariant: only court-plane points may be projected through the court
homography — a flying shuttle is **not** on the court plane, so landing-zone
inference needs explicit geometric care.

## Candidates evaluated

Scoring: functionality fit 30% · maintenance 20% · community 20% ·
documentation 15% · licence 10% · dependency footprint 5%. Each axis 1–5.
Stars verified 2026-07-12 via the GitHub API (MCP); last-activity dates from
repo pushed_at or the commits page; values marked ~ are unverified.

| # | Name | What | Stars | Last activity | Licence | Weighted | Decision |
|---|------|------|-------|--------------|---------|---------:|----------|
| 1 | YOLO11 fine-tune (ultralytics + Roboflow shuttle datasets) | Custom shuttle detector trained on OUR footage with the already-adopted stack | 59k+ (ultralytics) | continuous | AGPL-3.0 (accepted) | **4.10** | **build-on-top** (domain-gap insurance) |
| 2 | [qaz812345/TrackNetV3](https://github.com/qaz812345/TrackNetV3) | MMAsia'23 TrackNetV3: heatmap shuttle detection + trajectory-inpainting rectification, PyTorch, pretrained badminton weights | 272 | 2025-04-15 (pushed) | MIT | **3.95** | **adopt** (vendored; primary shuttle detector) |
| 3 | [alenzenx/TrackNetV3](https://github.com/alenzenx/TrackNetV3) | Unrelated "TrackNetV3": attention TrackNet, PyTorch, weights, bundled `event_detection.py` | 158 | 2025-06-02 (commit) | MIT | **3.45** | skip (mine hit-detection heuristics) |
| 4 | [SoloShuttlePose](https://github.com/sunwuzhou03/SoloShuttlePose) | Badminton singles full pipeline: court/net/players/shuttle, hit events, auto rally clipping; gdrive weights | 65 | 2024-11-05 (commit) | MIT | **3.35** | skip (reference for rally/hit logic) |
| 5 | [nttcom/WASB-SBDT](https://github.com/nttcom/WASB-SBDT) | BMVC'23 sports-ball detection baseline; badminton pretrained weights for WASB + 6 baselines (model zoo) | 178 | 2023-11-23 (pushed) — stale | MIT | **3.25** | skip (fallback detector + weights zoo) |
| 6 | [AnInsomniacy/tracknet-series-pytorch](https://github.com/AnInsomniacy/tracknet-series-pytorch) | TrackNet V1–V5 in one clean PyTorch pipeline, Python 3.11, checkpoints released 2026-05 | 26 | 2026-05-13 (commit) | none found ⚠ | **3.10** | skip (no licence — watch) |
| 7 | [TrackNetV4](https://github.com/TrackNetV4/TrackNetV4) | ICASSP'25 motion-attention TrackNet, tennis+badminton weights — TensorFlow | 76 | 2025-05-28 (commit) | MIT | **3.05** | skip (TF on Apple Silicon) |
| 8 | [CoachAI-Projects](https://github.com/wywyWang/CoachAI-Projects) | NYCU research suite; **ShuttleSet** (KDD-23) stroke-level singles dataset, stroke classification/forecasting | 261 | 2024-08-10 (commit) | MIT | **2.95** | **adopt** (shot-type vocabulary + dataset reference, not code) |
| 9 | [yastrebksv/TrackNet](https://github.com/yastrebksv/TrackNet) | Unofficial PyTorch TrackNet — tennis | 226 | ~ | ~none ⚠ | 2.40 | skip |
| 10 | [ChgygLin/TrackNetV2-pytorch](https://github.com/ChgygLin/TrackNetV2-pytorch) | TrackNetV2 TF→PyTorch port (+ncnn C++) | 61 | ~ | ~ | 2.30 | skip |
| 11 | [ToanNguyenKhanh/Badminton-Analysis](https://github.com/ToanNguyenKhanh/Badminton-Analysis) | YOLOv8 players+shuttle demo | 58 | ~2024 | ~ | 2.20 | skip |
| 12 | [Chang-Chia-Chi/TrackNet-Badminton-Tracking-tensorflow2](https://github.com/Chang-Chia-Chi/TrackNet-Badminton-Tracking-tensorflow2) | TrackNet TF2 (2020-era) | 253 | ~2021 stale | ~ | 2.20 | skip |
| 13 | [monotrack](https://github.com/jhwang7628/monotrack) | CVPRW'22 end-to-end: shuttle 2D/3D trajectory, hit + court detection (mmdet/mmpose) | 54 | 2023-01-05 (commit) — dead | Adobe Research (non-commercial) ⚠ | 2.15 | skip (paper is the reference) |
| 14 | [wish44165/A-New-Perspective…](https://github.com/wish44165/A-New-Perspective-for-Shuttlecock-Hitting-Event-Detection) | IJCAI'23 workshop hit-event detection (CoachAI challenge) | 27 | ~ | ~ | 1.80 | skip |
| 15 | [arthur900530/Automated-Hit-frame-Detection…](https://github.com/arthur900530/Automated-Hit-frame-Detection-for-Badminton-Match-Analysis) | Hit-frame detection; rally trimming via broadcast shot-angle changes | 31 | ~ | ~ | 1.75 | skip (broadcast-specific) |

Axis scores for the top 8 (fit/maint/community/docs/licence/deps):
YOLO11-fine-tune 3/5/5/5/2/5 · qaz-TrackNetV3 5/3/3/4/5/3 ·
alenzenx-TrackNetV3 4/3/3/3/5/2 · SoloShuttlePose 5/2/2/3/5/2 ·
WASB 4/1/3/4/5/3 · tracknet-series-pytorch 4/4/1/4/1/4 ·
TrackNetV4 4/2/2/3/5/2 · CoachAI 3/2/3/3/5/2.

## Per-candidate notes (top 8)

**YOLO11 fine-tune — build-on-top (domain-gap insurance).** Zero new
dependencies: `yolo11n` fine-tuned on a few hundred labelled frames of *our
own* footage (Roboflow Universe hosts several shuttlecock datasets — ~1.1k–4.5k
images — to warm-start; export → train locally, no cloud requirement).
Single-frame YOLO is known to underperform temporal heatmap models on
broadcast shuttle benchmarks (TrackNetV3 paper reports YOLOv7 at 57.8% vs
TrackNetV3 97.5%), so fit is capped — but training on our exact domain
sidesteps the pro-broadcast domain gap entirely, and a junior's shuttle is
slower (less motion blur) than the pro footage those benchmarks use. This is
the fallback if pretrained TrackNet transfers badly, not the first choice.

**qaz812345/TrackNetV3 — adopt (vendored, primary detector).** The
best-documented badminton-specific tracker: PyTorch, MIT, downloadable
`TrackNet_best.pt` + `InpaintNet_best.pt`, clean
`predict.py --video_file …` workflow producing per-frame (visibility, x, y)
CSV — exactly the trajectory stream every downstream step needs. 97.5%
accuracy on the (professional broadcast) Shuttlecock Trajectory Dataset;
~25 fps on the authors' CUDA GPU at reduced resolution. Not pip-installable —
vendor the model + inference code behind a narrow
`detect_shuttle(video) -> [(t, x, y, vis)]` seam, port `device` to `mps`
(plain conv/U-Net ops, no exotic layers — MPS-safe). Trained on broadcast pro
matches: our rear-elevated iPhone angle is geometrically similar to the
broadcast angle (that is the standard badminton camera position), but gym
lighting/background differ — transfer must be piloted, not assumed.

**alenzenx/TrackNetV3 — skip, mine the heuristics.** Confusingly *not* the
MMAsia'23 TrackNetV3 — an independent attention-TrackNet (90.5% on its own
small dataset). Weights exist but requirements mix PyTorch *and*
tensorflow-gpu. Its value is the post-processing scripts (`denoise.py`,
`show_trajectory.py`, `event_detection.py`) — a worked example of deriving
hit events from a raw trajectory CSV, which is exactly our rally-length step.

**SoloShuttlePose — skip as a dependency, adopt as the blueprint.** The
closest existing thing to phase 2 end-to-end: court/net detection, player
tracking, shuttle tracking (TrackNetV2/V3-based), hit-event detection, and
automatic clipping of a match video into rallies. MIT, weights on Google
Drive. But it is a student research pipeline (79% Jupyter, Python 3.9 +
CUDA 11.7 pins, yt-dlp coupling, last touched Nov 2024) — running it as-is on
Apple Silicon would cost more than reimplementing its logic on our own
detector output. Its rally-segmentation and hit-detection logic is the design
reference for our `badminton_track` module.

**WASB-SBDT — skip (fallback weights zoo).** NTT's BMVC'23 baseline
deliberately built to generalise across sports; MIT; badminton pretrained
weights for WASB *and* re-trained TrackNetV2/MonoTrack/BallSeg baselines in
one model zoo — the richest source of alternative shuttle weights if
TrackNetV3 transfers poorly. Repo is effectively frozen (6 commits, Nov 2023)
and hydra/docker-shaped, so treat it as a weights source + paper, not a
dependency.

**tracknet-series-pytorch — skip (no licence).** The freshest TrackNet work
anywhere (active May 2026, Python 3.11, clean V1–V5 PyTorch pipeline,
checkpoints, synthetic tests — and its dataset split even includes an
*Amateur* category). But there is **no licence file**, so we cannot legally
vendor or depend on it. Watch the repo; if a licence appears it likely
replaces the vendored qaz812345 code.

**TrackNetV4 — skip.** ICASSP'25 motion-attention refinement with badminton
weights, MIT — but official code is TensorFlow, and TF-on-Apple-Silicon
(tensorflow-metal) is a second ML runtime we refuse to add for a marginal
accuracy delta. Revisit only via third-party PyTorch ports.

**CoachAI-Projects / ShuttleSet — adopt the vocabulary, not the code.**
ShuttleSet (KDD-23): 44 pro singles matches, 3.7k rallies, 36.5k shots with
stroke-level labels — the de-facto shot-type taxonomy. Our `endingShot` enum
(serve/clear/drop/smash/net/drive/lift/push/block/other) should stay mapped
to ShuttleSet's type list so any future learned stroke classifier (e.g. BST,
TemPose — pose+trajectory transformers trained on ShuttleSet) can be dropped
in. The repo itself is models-over-CSV research code, not a video pipeline.

## Recommendation

Build phase 2 as a **thin pipeline over a vendored TrackNetV3 detector**, all
local, staged so each stage is independently testable pure-Python:

- **Shuttle detection:** vendor qaz812345/TrackNetV3 (MIT) inference +
  pretrained weights behind `detect_shuttle(video) -> TrajectoryFrame[]`
  (per-frame `t, x, y, visibility`), `device="mps"`, batch/offline. Process at
  30 fps (skip every other frame) — shuttle kinematics survive that easily.
  Fallback path if the pilot fails: fine-tune `yolo11n` on ~300–500 labelled
  frames of own footage (label with CVAT/Roboflow-local; warm-start from a
  Roboflow Universe shuttlecock dataset), same output contract.
- **Rally segmentation:** on a *fixed* camera this is far easier than the
  broadcast problem (no scene cuts): shuttle-visibility gaps + sustained
  motionless intervals + players-both-in-ready-position (already have player
  tracks + pose) delimit rallies. Pure function over the trajectory stream —
  unit-test with fabricated trajectories. Emits `videoTimestampMs` per point.
- **Rally length (hit count):** hit events = direction reversals /
  discontinuities in the smoothed trajectory (vertical-velocity sign flips +
  proximity to a player). Literature (monotrack; PMC hit-detection fusion
  paper) reports ~90% per-hit F1 on pro footage — expect counts to be ±1–2 on
  long rallies; store as suggestion, human-confirmable.
- **Landing zone (coarse 6-zone):** honour the court-plane invariant — never
  project a *flying* shuttle through H. Only the terminal trajectory point
  (after the last hit, when the shuttle reaches floor level / trajectory
  ends) may be treated as approximately on the court plane and projected;
  even then parallax from the elevated view biases the point toward the
  camera, so emit only the coarse 6-zone label plus a confidence, never
  centimetres. Zone from projected terminal point + which side of the net.
- **Ending shot type:** do NOT attempt a learned classifier now (pro-domain
  training data only, junior technique differs). Optionally emit a cheap
  kinematic guess (smash = steep fast descent; net = short low arc near net;
  clear/lift = high deep arc) marked low-confidence; otherwise leave for the
  human — the schema's nullable `endingShot` already allows this.
- **Emit `PointRecord`-shaped JSON** with an `auto=true` flag; the phase-1
  tagging UI becomes the review/confirm surface (per the use-case's
  implementation sketch).
- **Licence posture:** everything adopted is MIT except ultralytics
  (AGPL, already accepted). monotrack is Adobe Research non-commercial —
  read the paper, don't vendor the code. tracknet-series-pytorch has no
  licence — don't copy from it.

## Phase-2 gate verdict

**MARGINAL** — parked pending a cheap pilot; a *scoped subset* is realistic,
full automatic point extraction is not.

- **Model availability:** good. Pretrained badminton shuttle detectors exist
  with weights (qaz812345/TrackNetV3 MIT + WASB model zoo MIT), PyTorch,
  MPS-portable. This axis alone would be GO.
- **Expected accuracy on amateur iPhone footage:** the open risk. Every
  pretrained model above is trained on professional *broadcast* footage
  (Shuttlecock Trajectory Dataset, ShuttleSet matches). Our rear elevated
  angle closely matches the broadcast camera geometry (helpful) and a junior
  shuttle is slower (less blur, helpful), but gym lighting, background
  clutter, and a white shuttle against white walls/lines are exactly the
  conditions the literature flags as high-variance. Published results do not
  transfer as-is; nobody has validated this domain. Until a pilot on real
  footage shows the detector holding up, feasibility is unproven — hence not
  GO.
- **Compute feasibility (Apple Silicon):** acceptable because analysis is an
  offline background job. TrackNetV3 does ~25 fps on a CUDA GPU; assume
  5–15 fps on MPS. A 30-minute match at 30 fps effective ≈ 54k frames ≈ 1–3 h
  batch — fine overnight on the home server, not fine interactively.
- **Sub-capability scoping:**
  - Shuttle detection — **feasible** (pretrained now, fine-tune fallback).
  - Rally segmentation + `videoTimestampMs` — **feasible**, and *easier* than
    published broadcast work because the camera is fixed (no scene cuts);
    mostly pure-function logic over trajectories + existing player tracks.
  - Rally length — **feasible with error bars** (±1–2 hits); suggestion-grade.
  - Landing zone — **coarse 6-zone only**, terminal-point projection with the
    court-plane caveat; suggestion-grade.
  - Ending shot type — **not feasible** as a learned classifier under these
    constraints (pro-only training data, no local labelled corpus); at most a
    low-confidence kinematic heuristic. Stays human.
  - Full per-shot `shots` lists with shot types — **not feasible** now;
    the reserved schema field stays empty in any phase-2 v1.
- **Gate condition to upgrade to partial GO:** a half-day pilot — run vendored
  TrackNetV3 pretrained weights over 2–3 rallies of real match footage and
  eyeball/hand-score detection visibility ≥ ~80% of in-flight frames with a
  usable trajectory. Pass → build the scoped subset (rally boundaries +
  timestamps + rally-length + coarse landing zone, all human-confirmed in the
  phase-1 UI). Fail → try WASB weights, then the YOLO11 fine-tune route; if
  that also fails the effort budget, phase 2 stays parked and phase 1 remains
  the data path — the feature is complete without it.

## Search log

Queries run (WebSearch, 2026-07-12):

1. `TrackNetV3 github shuttlecock tracking badminton qaz812345` — rich; paper (MMAsia'23) + repo + 97.5% benchmark numbers.
2. `WASB sports ball detection github nttcom shuttlecock` — good; confirmed badminton support + model zoo.
3. `badminton rally segmentation shot classification github CoachAI ShuttleSet` — good; ShuttleSet stats, BST/TemPose stroke classifiers, CoachAI+ environment.
4. `YOLO shuttlecock detection badminton github 2025` — good; Roboflow datasets, YO-CSA(-T) arXiv 2501.06472, small YOLO demos.
5. `TrackNetV2 badminton github pytorch shuttlecock heatmap` — good; surfaced ChgygLin port, tracknet-series-pytorch (V1–V5), TrackNetV5 arXiv 2512.02789.
6. `alenzenx TrackNetV3 github yolo shuttlecock` — good; disambiguated the two unrelated "TrackNetV3" repos.
7. `TrackNetV4 motion attention ball tracking 2024 github` — good; ICASSP'25, TF implementation, vball-net derivative.
8. `badminton hit detection rally boundary detection amateur video shuttle trajectory hit point github` — good; monotrack, arthur900530 hit-frame, PMC hit-detection fusion paper (~90% F1).
9. `TrackNet generalization non-broadcast amateur badminton footage fine-tune domain gap` — confirmed broadcast-training bias and background-dependent variance; doubles-transfer paper (arXiv 2508.13507).
10. `roboflow shuttlecock dataset universe badminton annotated images train` — several usable datasets (~1.1k–4.5k images) for the fine-tune fallback.

Verification: stars/licence/pushed_at for qaz812345/TrackNetV3 and
nttcom/WASB-SBDT from the GitHub API (full objects); stars for all other
repos from GitHub API search (2026-07-12); last-commit dates from repo
commits pages (alenzenx, CoachAI, SoloShuttlePose, TrackNetV4, monotrack,
tracknet-series-pytorch); licences from repo pages, and monotrack's LICENSE
file fetched directly (Adobe Research License — supersedes the "unverified"
note in `research/cv-tracking.md`). Repos marked ~ were not individually
fetched. GitHub `gh` CLI and raw api.github.com were proxy-gated this
session; the GitHub MCP search API was used instead.
