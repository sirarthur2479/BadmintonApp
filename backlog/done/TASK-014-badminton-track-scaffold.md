# TASK-014 - badminton_track scaffold: package, court model, config

**Use case:** [ideas/use-cases/badmintontrack-12.md](../../ideas/use-cases/badmintontrack-12.md)
**Research:** [research/cv-tracking.md](../../research/cv-tracking.md), [research/local-llm.md](../../research/local-llm.md)
**Depends on:** -
**Effort:** S
**Risk:** low

**Status:** done

## Goal

Stand up the `badminton_track/` Python project so every later task lands in a
tested, installable package: `pyproject.toml` with a src layout, the badminton
court geometry model in metres (the single source of truth for Modules 1–2),
a typed `config.yaml` loader with the researched defaults, and the privacy
gitignores. Heavy ML dependencies (ultralytics, mediapipe, ollama) are
declared as **optional extras** so `pytest` runs headless in CI/containers
with only the core scientific stack; model-touching code (later tasks) stays
behind narrow interfaces.

## Acceptance criteria

- `badminton_track/pyproject.toml`: package `badminton-track`, Python
  `>=3.11`, src layout (`src/badminton_track/`); core deps `numpy`, `pandas`,
  `scipy`, `opencv-python-headless`, `pyyaml`, `pydantic`; extras
  `footwork = [ultralytics, supervision]`, `biomech = [mediapipe]`,
  `coach = [ollama]`, `full = [all of the above]`; dev extra `pytest`.
- `pip install -e .` + `pytest` pass in this container WITHOUT any extras.
- `src/badminton_track/court.py`: constants in metres —
  `COURT_LENGTH = 13.4`, `COURT_WIDTH_DOUBLES = 6.1`,
  `COURT_WIDTH_SINGLES = 5.18`, `NET_Y = 6.7`,
  `FRONT_SERVICE_LINE_FROM_NET = 1.98`; `corner_points_m()` returning the
  4 doubles corners in a documented, fixed order (clockwise from far-left);
  `front_service_intersections_m()` for the calibration sanity check;
  `near_half_polygon_m()` for the target-player lock.
- `src/badminton_track/config.py`: pydantic `TrackConfig` loaded from
  `config.yaml` — base point (default = T-position on the near half),
  `base_radius_m: 1.0`, `frame_stride: 3`, `butter_cutoff_hz: 6.0`,
  `visibility_threshold: 0.5`, `max_gap_s: 0.5`, detector tag `yolo11n.pt`,
  pose model asset path, coach `model_tag: qwen3:8b`,
  `fallback_model_tag: gemma3:4b`, `ollama_host`; unknown keys rejected;
  missing file → documented defaults.
- `badminton_track/config.yaml` checked in with those defaults;
  `badminton_track/.gitignore` covers `videos/`, `data/`, `output/`, model
  weights (`*.pt`, `*.task`).
- Root `CLAUDE.md` table row for `badminton_track/` stays accurate
  (PROJECT_TYPE python-cli, tests `pytest`) — no edit expected, just verified.

## Test plan

RED first in `badminton_track/tests/`:

- `test_court.py::test_court_constants_match_bwf_dimensions`
- `test_court.py::test_corner_points_order_and_units`
- `test_court.py::test_front_service_intersections_positions`
- `test_court.py::test_near_half_polygon_covers_near_court_only`
- `test_config.py::test_defaults_load_without_file`
- `test_config.py::test_yaml_overrides_defaults`
- `test_config.py::test_unknown_key_rejected`
- `test_config.py::test_checked_in_config_yaml_parses`

## Implementation plan

1. `badminton_track/pyproject.toml` (setuptools or hatchling; hatchling
   preferred, zero config for src layout) + `badminton_track/.gitignore`.
2. `src/badminton_track/__init__.py` (version string only).
3. `src/badminton_track/court.py` — constants + the three pure geometry
   functions returning `np.ndarray` (float64, shape (N, 2)).
4. `src/badminton_track/config.py` —
   `class TrackConfig(BaseModel, extra="forbid")` with nested
   `FootworkConfig` / `BiomechConfig` / `CoachConfig`;
   `load_config(path: Path | None) -> TrackConfig`.
5. `badminton_track/config.yaml` mirroring the defaults.
6. Create a venv in the container, `pip install -e badminton_track[dev]`,
   run `pytest badminton_track/tests` green.
