"""Module 2 — rear-view player tracking to court-metre telemetry.

Detector + tracker live behind `iter_tracks` (the ONLY ultralytics import —
the AGPL containment and the RF-DETR escape hatch both hang on this seam).
Everything downstream is pure and testable with fabricated tracks.

A frame is `(t_seconds, list[RawTrack])` — carrying the timestamp on the
frame (not the track) so frames with zero detections still exist in the
telemetry as NaN rows.
"""

from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Iterator

import numpy as np
import pandas as pd

from . import calibrate, court
from .config import FootworkConfig

Frame = tuple[float, list["RawTrack"]]


class ExtrasMissingError(Exception):
    """A pipeline extra is not installed; message carries the pip command."""


@dataclass(frozen=True)
class RawTrack:
    """One tracked person in one frame."""

    track_id: int
    bbox_xyxy: np.ndarray


def _near_half_positions(
    tracks: list[RawTrack], calib: calibrate.Calibration
) -> dict[int, tuple[float, float]]:
    """track_id -> projected feet (metres), for tracks on the near half only."""
    if not tracks:
        return {}
    bboxes = np.stack([tr.bbox_xyxy for tr in tracks])
    feet = calibrate.project_feet(calib.h, bboxes)
    poly = court.near_half_polygon_m()
    x_min, x_max = poly[:, 0].min(), poly[:, 0].max()
    y_min, y_max = poly[:, 1].min(), poly[:, 1].max()
    return {
        tr.track_id: (float(x), float(y))
        for tr, (x, y) in zip(tracks, feet)
        if x_min <= x <= x_max and y_min <= y <= y_max
    }


def lock_target(
    frames: Iterable[Frame],
    calib: calibrate.Calibration,
    cfg: FootworkConfig,
) -> pd.DataFrame:
    """Follow ONE player: the track that lives on the near court half.

    Warmup: score every track id by frames spent on the near half during the
    first `lock_warmup_s`; lock the best. Hysteresis: the lock survives
    disappearances up to `lock_grace_s` (frames in between are NaN); after a
    longer absence the next near-half track takes over (ByteTrack id churn).
    Far-half tracks (opponent, coach) can never fill in for the player.
    """
    frames = list(frames)
    if not frames:
        return pd.DataFrame(columns=["t", "x_m", "y_m"]).astype(float)

    near_by_frame = [_near_half_positions(tracks, calib) for _, tracks in frames]

    t0 = frames[0][0]
    scores: Counter[int] = Counter()
    for (t, _), near in zip(frames, near_by_frame):
        if t - t0 > cfg.lock_warmup_s:
            break
        scores.update(near.keys())
    locked: int | None = scores.most_common(1)[0][0] if scores else None

    rows: list[tuple[float, float, float]] = []
    last_seen_t: float | None = None
    for (t, _), near in zip(frames, near_by_frame):
        if locked is not None and locked in near:
            x, y = near[locked]
            last_seen_t = t
            rows.append((t, x, y))
            continue
        absent_long = last_seen_t is None or (t - last_seen_t) > cfg.lock_grace_s
        if near and (locked is None or absent_long):
            locked = next(iter(near))
            x, y = near[locked]
            last_seen_t = t
            rows.append((t, x, y))
        else:
            rows.append((t, np.nan, np.nan))

    return pd.DataFrame(rows, columns=["t", "x_m", "y_m"]).astype(float)
