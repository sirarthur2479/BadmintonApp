# TASK-018 - Court map rendering + `analyze` CLI (footwork mode)

**Use case:** [ideas/use-cases/badmintontrack-12.md](../../ideas/use-cases/badmintontrack-12.md)
**Research:** [research/cv-tracking.md](../../research/cv-tracking.md)
**Depends on:** TASK-015, TASK-016, TASK-017
**Effort:** M
**Risk:** low

**Status:** done

## Goal

Make Stage 1 shippable: a top-down court movement map rendered from
telemetry (court lines to scale, movement trace coloured by time, base
circle, episode peak markers) written to `output/`, and the `badminton-track`
CLI whose `analyze <video> --mode footwork` wires
calibrate → track → metrics → CSV + court map + a small metrics summary
JSON. Also the `calibrate` subcommand wrapping TASK-015's interactive corner
picker. Errors are actionable: missing extras name the pip command, missing
calibration names the `calibrate` command.

## Acceptance criteria

- `src/badminton_track/courtmap.py`:
  `render_court_map(df, episodes, cfg, out_path) -> Path` — draws the court
  from `court.py` geometry (no hardcoded dimensions), the trajectory
  (interpolated rows only), base-radius circle, episode peak markers;
  written via OpenCV drawing into a numpy canvas (no matplotlib dep) as PNG;
  configurable px-per-metre scale.
- `src/badminton_track/cli.py` (stdlib argparse, console script
  `badminton-track`):
  - `badminton-track calibrate <video> --name <setup>` → runs corner picker
    + sanity check, saves calibration JSON under `data/`.
  - `badminton-track analyze <video> --mode footwork --calibration <name>`
    → telemetry CSV, court map PNG, `<stem>-summary.json`
    (EpisodeStats + session aggregates) under `output/`.
  - `--mode biomech` parses but exits with "arrives in TASK-019" message
    (placeholder wired for the next task).
  - Missing calibration file / missing extras exit code 2 with the
    actionable message; happy path exit code 0.
- `pyproject.toml` gains the `[project.scripts]` entry.
- `pytest` green without extras (analyze tested with mocked
  `footwork.run_footwork`).

## Test plan

RED first in `badminton_track/tests/test_courtmap.py` and `test_cli.py`:

- `test_render_court_map_writes_png_with_expected_canvas_size`
- `test_render_court_map_draws_trajectory_pixels` (canvas not blank along
  a known synthetic path)
- `test_render_handles_all_nan_telemetry`
- `test_cli_analyze_footwork_produces_csv_map_and_summary` (mocked pipeline)
- `test_cli_analyze_missing_calibration_exits_2_with_hint`
- `test_cli_analyze_biomech_placeholder_message`
- `test_cli_calibrate_saves_json` (mocked `pick_corners`)
- `test_summary_json_contains_episode_stats_and_aggregates`

## Implementation plan

1. `courtmap.py`: canvas `int(px_per_m * width) × int(px_per_m * length)`
   (+margin); helper `m_to_px(pts)`; `cv2.polylines` for court lines from
   `court.py`, trace segments coloured by normalized time
   (`cv2.applyColorMap` on a ramp), `cv2.circle` for base + peaks;
   `cv2.imwrite`.
2. `cli.py`: `build_parser() -> argparse.ArgumentParser` (pure, testable),
   `main(argv=None) -> int`; subcommands dispatch to small `_cmd_*`
   functions; all heavy imports stay inside the pipeline modules.
3. Summary JSON: `dataclasses.asdict(EpisodeStats)` + aggregates dict via
   `json.dump` (NaN → null via a tiny sanitizer).
4. `[project.scripts] badminton-track = "badminton_track.cli:main"`;
   re-`pip install -e` in the venv.
5. Full `pytest` run.
