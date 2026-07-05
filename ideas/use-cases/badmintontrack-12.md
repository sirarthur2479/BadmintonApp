# Use case: BadmintonTrack-12

**Status:** done (TASK-014 → TASK-020, completed 2026-07-05)
**Created:** 2026-07-05
**Owner idea:** CV + local-LLM analysis of training/match footage of a 12-year-old
regional-level badminton player.

This document is the owner's original spec **reviewed and corrected** by a CV
engineering pass. Sections marked ⚠ are deliberate changes from the original
prompt — read those before planning.

---

## Problem

Training sessions and matches are recorded on an iPhone (1080p / 60fps) but the
footage is only reviewed by eye. Footwork quality (recovery to base after each
shot) and stroke biomechanics (lunge depth, smash arm extension) are invisible
without measurement. Coaching feedback is generic because there's no telemetry.

## Target users

- The player's parent/coach (runs the tool, reads the report)
- The player (12 y/o — consumes the LLM "coach narrative" directly, so tone and
  safety constraints matter)

## Desired outcome

From one video file, produce:
1. A metrics CSV/Parquet (per-frame telemetry + per-episode aggregates)
2. A top-down court movement map (annotated image/video)
3. A Markdown coach report written by a **local** LLM in an encouraging,
   age-appropriate voice, with concrete drills — never raw stat tables

Success = owner can run `analyze <video>` on a Mac and get all three artefacts
without any cloud upload.

## Constraints

- **Privacy is hard requirement:** footage of a minor. Everything runs locally
  (Ollama). `/videos` and `/output` must be gitignored. No cloud APIs.
- Modest hardware: nano-class models, frame skipping where accuracy allows.
- Python 3.11+, type-hinted, modular; pytest-testable (workflow uses /tdd).
- Lives in `badminton_track/` beside the existing `badminton_flutter/` app.

---

## Architecture (revised)

### Module 1 — Court calibration & homography (rear high view)

As specced: click the 4 court corners in a paused frame, build a homography with
`cv2.getPerspectiveTransform`, save to a calibration JSON keyed by camera setup.

⚠ Corrections to the original spec:
- Map to **real court dimensions in metres** (13.4 m × 6.1 m doubles, 5.18 m
  singles width), not arbitrary pixel canvas — so distance/speed outputs are in
  metres and m/s, which the LLM report needs.
- The homography is only valid for points **on the court plane**. Only the
  player's *feet* (bbox bottom-centre) may be projected — never bbox centre or
  head. This must be an explicit invariant in the tracker.
- Add an optional 2-click sanity check (front service line intersections):
  reproject and warn if error > ~20 px. Catches bad corner clicks immediately
  instead of producing silently wrong metrics.
- Point projection at runtime uses `cv2.perspectiveTransform` (the original
  prompt only mentioned building the matrix, not applying it).

### Module 2 — Player tracking & footwork metrics (rear view)

⚠ Corrections:
- **Model name:** Ultralytics' current model is `yolo11n.pt` (YOLO11), not
  `yolov11n.pt` — the literal name in the original prompt 404s.
- **Multiple people are always in frame** (opponent across the net, sometimes a
  coach). Plain per-frame detection will jump between people. Use
  `model.track(persist=True)` (ByteTrack) for stable IDs, then lock onto the
  target player by filtering to detections whose projected feet fall in the
  **near court half** (via the Module-1 homography).
- **"Footwork Recovery Latency" needs a real definition.** Raw per-frame
  distance-to-T is the signal, not the metric. Define an *excursion episode*:
  player leaves a base radius (default 1.0 m around a configurable base point —
  default the T, but a real base position is slightly behind the T), episode
  ends when they re-enter the radius. Recovery latency = time from the
  episode's maximum-distance frame back to base re-entry. Report per-episode
  latencies and their trend across the session ("dropped 400 ms after the 5th
  rally" falls out of this trend).
- Frame skipping (every 3rd frame → 20 Hz effective) is fine **for this module
  only** — footwork dynamics survive 20 Hz. See Module 3 for why it can't be
  global.
- Missed detections produce NaN rows; interpolate short gaps (< 0.5 s) before
  smoothing, flag longer gaps in the output.

### Module 3 — Biomechanics (side profile view)

⚠ Corrections:
- **No global frame skipping here.** A smash arm swing is a 100–200 ms event;
  at every-3rd-frame you get 2–4 samples of it. Run MediaPipe Pose at the full
  60 fps, but only inside *analysis windows* — for MVP these are manually
  trimmed clips (or start/end timestamps in a config), auto-detection of
  swing/lunge windows is a later task.
- Angles as specced: knee lunge angle (hip–knee–ankle) and smash extension
  (shoulder–elbow–wrist), 2D. This is valid **only when the movement plane is
  roughly parallel to the camera** — the report must record camera side and the
  tool should warn when landmark z-spread suggests an oblique view.
- Drop frames where MediaPipe landmark `visibility` is below threshold (~0.5)
  instead of feeding occluded garbage into the filter.
- **Butterworth (SciPy) done right:** zero-phase `scipy.signal.filtfilt`
  (a causal filter adds lag that shifts every measured angle), cutoff ≈ 6 Hz
  for human movement, and the sample rate passed to the filter design must be
  the *effective* rate (60 Hz here; 20 Hz in Module 2 if smoothing there too).

### Module 4 — Local LLM coach narrative

⚠ Corrections:
- **The LLM never sees raw per-frame CSV.** 7B–8B models do arithmetic badly
  and a session of frames blows the context. All statistics are computed
  deterministically in pandas; the LLM receives a compact JSON summary:
  per-episode recovery latencies + trend, angle mins/maxes per rep, flagged
  anomalies (each pre-worded as a plain-English fact).
- Ollama chat API via the `ollama` Python package (skip LiteLLM unless a second
  backend is actually needed — fewer deps). Default model `qwen3:8b` with
  `think=False`; `gemma3:4b` as the documented 8 GB-Mac fallback (per
  `research/local-llm.md` 2026-07-05 — the originally specced `llama3.1:8b` and
  `qwen2.5:7b` are two generations old). Fail gracefully with the metrics
  report intact if Ollama isn't running; refuse `-cloud` model tags.
- Persona guardrails beyond "encouraging coach": growth-mindset framing, no
  body commentary, injury-safety wording for joint-angle findings
  ("check this with your coach before changing technique"), 2–3 concrete drills
  per finding, reading level ~12 y/o.

### ⚠ Structural corrections (whole-system)

1. **Two views = two runs, not one pipeline.** Rear-view footwork and
   side-view biomechanics come from different recordings. The CLI takes
   `--mode footwork|biomech` per video; the report merger combines whatever
   telemetry exists for a session. The original spec's single
   `tracker_engine.py` doing YOLO + MediaPipe + both views in one loop should
   be split.
2. **Integration with the existing app:** `badminton_flutter` match logs
   reference video files and the docs plan a "Markdown export for AI analysis".
   The coach report should use a compatible Markdown structure so it can be
   attached to a match log. Writing metrics into the app's DB and in-app
   WiFi upload to a home analysis server are explicitly phase 2 — tracked as
   pool idea #6 ("BadmintonTrack-12 in-app integration"), out of scope here.
3. **Original "Deliverables to Generate Now" (scaffold + 3 complete scripts) is
   superseded** — implementation goes through /plan → /tdd task-by-task, tests
   first, instead of one big generated scaffold.

## Proposed layout

```
badminton_track/
  pyproject.toml            # deps pinned; ultralytics, mediapipe, opencv-python,
                            # numpy, pandas, scipy, ollama
  config.yaml               # base point, radii, filter cutoffs, model tags
  videos/    (gitignored)
  data/      (gitignored)   # calibration JSONs, telemetry parquet/csv
  output/    (gitignored)   # court maps, coach reports
  src/badminton_track/
    calibrate.py            # Module 1
    footwork.py             # Module 2 (rear view)
    biomech.py              # Module 3 (side view)
    metrics.py              # episode detection, aggregation (pure, no I/O — most testable code)
    coach.py                # Module 4
    cli.py
  tests/
```

## Relevant domains (for /research)

- `cv-tracking` — YOLO11 + ByteTrack person tracking, court homography practice
- `pose-biomechanics` — MediaPipe Pose for sport joint angles, smoothing practice
- `local-llm` — Ollama model choice for structured-summary → narrative on 8–16 GB RAM

## Open questions

1. **Who is Alister?** The owner referenced knowledge of "Alister" — presumed to
   be the player, but the repo contains no profile data (the app's
   PlayerProfile is an empty template). Any personalisation (name, goals,
   playing style) for the coach narrative needs owner input or a filled app profile.
2. What machine runs analysis — Apple Silicon Mac (Ollama comfortable) or
   something weaker? Affects default model tag and frame-skip defaults.
3. Are recordings pre-trimmed to rallies, or full sessions? (Full sessions make
   rally segmentation a required task rather than a nice-to-have.)
4. One iPhone re-used across rear/side recordings (assumed), or two phones
   simultaneously?

None of these block Stage 1 (calibration + footwork) — defaults are stated above.

## Implementation sketch (staging for /plan)

- **Stage 1:** calibration + footwork pipeline + metrics (episodes, latency) → CSV + court map
- **Stage 2:** biomechanics pipeline (windows from config) → angle telemetry
- **Stage 3:** aggregation + coach narrative + Markdown report
- Each stage independently shippable and testable; `metrics.py` logic is pure
  functions — ideal first /tdd targets.
