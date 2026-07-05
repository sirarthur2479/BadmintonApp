"""Module 2 metrics core — pure functions over telemetry, no I/O.

Telemetry contract (produced by footwork.py, consumed here):
    pd.DataFrame with columns
        t    — seconds from video start, float, strictly increasing
        x_m  — court x in metres (NaN when the player was not detected)
        y_m  — court y in metres (NaN when the player was not detected)
"""

from dataclasses import dataclass

import numpy as np
import pandas as pd


@dataclass(frozen=True)
class Gap:
    """A detection hole too long to interpolate (flagged, left NaN)."""

    start_t: float
    end_t: float


def _nan_runs(series: pd.Series) -> list[tuple[int, int]]:
    """Contiguous NaN runs as (start_idx, end_idx) inclusive positions."""
    isna = series.isna().to_numpy()
    runs: list[tuple[int, int]] = []
    start: int | None = None
    for i, missing in enumerate(isna):
        if missing and start is None:
            start = i
        elif not missing and start is not None:
            runs.append((start, i - 1))
            start = None
    if start is not None:
        runs.append((start, len(isna) - 1))
    return runs


def interpolate_gaps(
    df: pd.DataFrame, max_gap_s: float
) -> tuple[pd.DataFrame, list[Gap]]:
    """Linearly fill NaN runs shorter than `max_gap_s`; flag longer runs.

    Edge runs (no straddling samples) are never extrapolated. The returned
    frame is a copy; flagged gaps stay NaN.
    """
    out = df.copy()
    gaps: list[Gap] = []
    t = out["t"].to_numpy()

    long_runs: list[tuple[int, int]] = []
    for start, end in _nan_runs(out["x_m"]):
        duration = t[end] - t[start]
        is_edge = start == 0 or end == len(out) - 1
        if is_edge:
            long_runs.append((start, end))
            continue
        if duration >= max_gap_s:
            gaps.append(Gap(start_t=float(t[start]), end_t=float(t[end])))
            long_runs.append((start, end))

    for col in ("x_m", "y_m"):
        interpolated = out[col].interpolate(method="linear", limit_area="inside")
        for start, end in long_runs:
            interpolated.iloc[start : end + 1] = np.nan
        out[col] = interpolated
    return out, gaps


def distance_to_base(df: pd.DataFrame, base_xy: tuple[float, float]) -> pd.Series:
    """Per-sample Euclidean distance (m) to the base point; NaN passes through."""
    return np.hypot(df["x_m"] - base_xy[0], df["y_m"] - base_xy[1])


@dataclass(frozen=True)
class Episode:
    """One excursion: leaving the base radius until re-entering it.

    Recovery latency — the metric the coach report is built on — is the time
    from the excursion's farthest point back to base re-entry.
    """

    start_t: float
    end_t: float
    peak_t: float
    peak_distance_m: float

    @property
    def recovery_latency_s(self) -> float:
        return self.end_t - self.peak_t


def detect_episodes(
    df: pd.DataFrame, base_xy: tuple[float, float], radius_m: float
) -> list[Episode]:
    """Excursion episodes from telemetry.

    An episode starts on the first sample outside `radius_m` and ends on the
    first sample back inside. NaN samples are "unknown": they neither open
    nor close an episode (the last known state persists across them). An
    excursion still open when the data ends has no re-entry and is dropped.
    """
    dist = distance_to_base(df, base_xy)
    t = df["t"].to_numpy()

    episodes: list[Episode] = []
    open_start: int | None = None
    peak_idx: int | None = None
    for i, d in enumerate(dist):
        if np.isnan(d):
            continue
        if open_start is None:
            if d > radius_m:
                open_start = i
                peak_idx = i
        else:
            assert peak_idx is not None
            if d > dist.iloc[peak_idx]:
                peak_idx = i
            if d <= radius_m:
                episodes.append(
                    Episode(
                        start_t=float(t[open_start]),
                        end_t=float(t[i]),
                        peak_t=float(t[peak_idx]),
                        peak_distance_m=float(dist.iloc[peak_idx]),
                    )
                )
                open_start = None
                peak_idx = None
    return episodes
