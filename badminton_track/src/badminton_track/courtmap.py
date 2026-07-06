"""Top-down court movement map rendered from telemetry (OpenCV, no display)."""

from pathlib import Path

import cv2
import numpy as np
import pandas as pd

from . import court
from .config import FootworkConfig
from .metrics import Episode

MARGIN_PX = 40
_BG = (34, 60, 24)  # court green (BGR)
_LINE = (255, 255, 255)
_BASE = (200, 200, 60)
_PEAK = (60, 60, 230)


def _to_px(pts_m: np.ndarray, px_per_m: float) -> np.ndarray:
    return (np.asarray(pts_m, dtype=np.float64) * px_per_m + MARGIN_PX).astype(int)


def render_blank_court(cfg: FootworkConfig, px_per_m: float = 60) -> np.ndarray:
    """The empty court canvas — lines from the court model, nothing else."""
    w = int(court.COURT_WIDTH_DOUBLES * px_per_m) + 2 * MARGIN_PX
    h = int(court.COURT_LENGTH * px_per_m) + 2 * MARGIN_PX
    img = np.full((h, w, 3), _BG, dtype=np.uint8)

    def line(p1_m, p2_m, thickness=2):
        p1, p2 = _to_px(np.array([p1_m, p2_m]), px_per_m)
        cv2.line(img, tuple(p1), tuple(p2), _LINE, thickness)

    wd, ln = court.COURT_WIDTH_DOUBLES, court.COURT_LENGTH
    ws = court.COURT_WIDTH_SINGLES
    side = (wd - ws) / 2
    fsl = court.FRONT_SERVICE_LINE_FROM_NET
    # Outer boundary
    line((0, 0), (wd, 0))
    line((wd, 0), (wd, ln))
    line((wd, ln), (0, ln))
    line((0, ln), (0, 0))
    # Singles sidelines
    line((side, 0), (side, ln), 1)
    line((wd - side, 0), (wd - side, ln), 1)
    # Net and front service lines
    line((0, court.NET_Y), (wd, court.NET_Y), 3)
    line((0, court.NET_Y - fsl), (wd, court.NET_Y - fsl), 1)
    line((0, court.NET_Y + fsl), (wd, court.NET_Y + fsl), 1)
    # Centre lines (baseline to front service line, both halves)
    line((wd / 2, 0), (wd / 2, court.NET_Y - fsl), 1)
    line((wd / 2, court.NET_Y + fsl), (wd / 2, ln), 1)
    return img


def render_court_map(
    df: pd.DataFrame,
    episodes: list[Episode],
    cfg: FootworkConfig,
    out_path: Path,
    px_per_m: float = 60,
) -> Path:
    """Telemetry -> annotated top-down PNG.

    Trajectory segments are coloured by time (early = cool, late = warm) so
    fatigue patterns read at a glance; NaN samples simply break the trace.
    """
    img = render_blank_court(cfg, px_per_m)

    valid = df.dropna(subset=["x_m", "y_m"])
    if len(valid) >= 2:
        t = valid["t"].to_numpy()
        span = (t[-1] - t[0]) or 1.0
        pts = _to_px(valid[["x_m", "y_m"]].to_numpy(), px_per_m)
        # A colour ramp indexed by normalized time.
        ramp = cv2.applyColorMap(
            (255 * (t - t[0]) / span).astype(np.uint8).reshape(-1, 1),
            cv2.COLORMAP_TURBO,
        ).reshape(-1, 3)
        prev_idx = valid.index.to_numpy()
        for i in range(1, len(pts)):
            # Consecutive telemetry rows only — a NaN row between them
            # breaks the trace instead of drawing through the hole.
            if prev_idx[i] - prev_idx[i - 1] == 1:
                cv2.line(
                    img,
                    tuple(pts[i - 1]),
                    tuple(pts[i]),
                    tuple(int(c) for c in ramp[i]),
                    2,
                )

    base_px = _to_px(np.array([cfg.base_point_m]), px_per_m)[0]
    cv2.circle(img, tuple(base_px), int(cfg.base_radius_m * px_per_m), _BASE, 1)

    for ep in episodes:
        row = df.loc[(df["t"] - ep.peak_t).abs().idxmin()]
        if np.isnan(row["x_m"]):
            continue
        peak_px = _to_px(np.array([[row["x_m"], row["y_m"]]]), px_per_m)[0]
        cv2.drawMarker(img, tuple(peak_px), _PEAK, cv2.MARKER_TILTED_CROSS, 14, 2)

    out_path = Path(out_path)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    cv2.imwrite(str(out_path), img)
    return out_path
