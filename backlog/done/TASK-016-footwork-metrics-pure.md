# TASK-016 - Footwork metrics: excursion episodes, recovery latency, gaps, trend

**Use case:** [ideas/use-cases/badmintontrack-12.md](../../ideas/use-cases/badmintontrack-12.md)
**Research:** [research/cv-tracking.md](../../research/cv-tracking.md)
**Depends on:** TASK-014
**Effort:** M
**Risk:** low

**Status:** done

## Goal

The most testable core of Module 2, written before any video I/O exists:
pure functions over a timestamped court-coordinates telemetry frame that
implement the use-case's real metric definitions — excursion episodes
(leave/re-enter a base radius), recovery latency (time from an episode's
maximum-distance frame back to base re-entry), per-episode aggregates and a
session trend, plus the NaN policy (interpolate gaps < 0.5 s, flag longer
ones). This module defines the telemetry DataFrame contract that TASK-017's
tracker must produce.

## Acceptance criteria

- `src/badminton_track/metrics.py`, no I/O, no cv2/ultralytics imports:
  - Telemetry contract documented: `pd.DataFrame` with columns
    `t` (seconds, float), `x_m`, `y_m` (court metres, NaN when the player
    was not detected).
  - `interpolate_gaps(df, max_gap_s) -> tuple[pd.DataFrame, list[Gap]]` —
    linear interpolation for NaN runs shorter than `max_gap_s`; longer runs
    stay NaN and are returned as flagged `Gap(start_t, end_t)` records.
  - `distance_to_base(df, base_xy) -> pd.Series` (metres).
  - `detect_episodes(df, base_xy, radius_m) -> list[Episode]` — an episode
    starts on the first sample outside `radius_m` and ends on re-entry;
    `Episode` carries `start_t`, `end_t`, `peak_t` (max distance),
    `peak_distance_m`, `recovery_latency_s = end_t - peak_t`. An excursion
    still open at the end of the data is dropped (no re-entry → no latency).
  - `episode_summary(episodes) -> EpisodeStats` — count, mean/median/max
    latency, and `trend_slope_s_per_episode` from a least-squares fit of
    latency against episode index (the "dropped 400 ms after the 5th rally"
    signal).
  - `session_aggregates(df) -> dict` — total distance covered (metres,
    NaN-safe), duration, detection coverage %.
- All functions handle empty and all-NaN input without raising.
- `pytest` green with only core deps.

## Test plan

RED first in `badminton_track/tests/test_metrics.py`:

- `test_interpolate_fills_short_gap_linearly`
- `test_interpolate_leaves_long_gap_nan_and_flags_it`
- `test_distance_to_base_simple_geometry`
- `test_no_episode_when_player_stays_inside_radius`
- `test_episode_boundaries_on_leave_and_reenter`
- `test_recovery_latency_is_peak_to_reentry_time`
- `test_open_ended_excursion_is_dropped`
- `test_multiple_episodes_in_sequence`
- `test_summary_trend_slope_detects_slowing_recovery`
- `test_session_aggregates_total_distance_and_coverage`
- `test_empty_and_all_nan_input_safe`

## Implementation plan

1. `metrics.py`: `@dataclass Gap`, `@dataclass Episode`,
   `@dataclass EpisodeStats` (all frozen).
2. `interpolate_gaps`: identify NaN runs via boolean segmentation on `x_m`;
   `df.interpolate(method="linear", limit_area="inside")` applied only to
   short runs (mask-restore long runs), gaps measured in seconds via `t`.
3. `detect_episodes`: boolean `outside = distance > radius`; edges via
   `outside.astype(int).diff()`; NaN samples treated as "unknown" — they
   neither open nor close an episode (document this).
4. `episode_summary`: `np.polyfit(range(n), latencies, 1)` for the slope;
   guard n < 2 → slope NaN.
5. `session_aggregates`: `np.hypot(dx, dy)` over interpolated rows only.
6. Full `pytest` run.
