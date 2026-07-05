import numpy as np
import pandas as pd

from badminton_track import metrics


def telemetry(rows: list[tuple[float, float | None, float | None]]) -> pd.DataFrame:
    """Build a telemetry frame from (t, x_m, y_m); None becomes NaN."""
    return pd.DataFrame(rows, columns=["t", "x_m", "y_m"]).astype(float)


def test_interpolate_fills_short_gap_linearly():
    df = telemetry(
        [
            (0.0, 0.0, 0.0),
            (0.1, None, None),
            (0.2, None, None),
            (0.3, 3.0, 6.0),
        ]
    )

    filled, gaps = metrics.interpolate_gaps(df, max_gap_s=0.5)

    assert gaps == []
    np.testing.assert_allclose(filled["x_m"], [0.0, 1.0, 2.0, 3.0])
    np.testing.assert_allclose(filled["y_m"], [0.0, 2.0, 4.0, 6.0])


def test_interpolate_leaves_long_gap_nan_and_flags_it():
    rows = [(0.0, 0.0, 0.0)]
    # 0.1..0.9 missing -> a 0.8 s hole, longer than max_gap_s
    rows += [(round(0.1 * i, 1), None, None) for i in range(1, 10)]
    rows += [(1.0, 5.0, 5.0)]
    df = telemetry(rows)

    filled, gaps = metrics.interpolate_gaps(df, max_gap_s=0.5)

    assert filled["x_m"].isna().sum() == 9
    assert len(gaps) == 1
    assert gaps[0].start_t == 0.1
    assert gaps[0].end_t == 0.9


def test_interpolate_does_not_extrapolate_edges():
    df = telemetry(
        [
            (0.0, None, None),
            (0.1, 1.0, 1.0),
            (0.2, None, None),
        ]
    )

    filled, _gaps = metrics.interpolate_gaps(df, max_gap_s=0.5)

    # Leading/trailing NaNs have no straddling samples — they must stay NaN.
    assert np.isnan(filled["x_m"].iloc[0])
    assert np.isnan(filled["x_m"].iloc[2])


def test_distance_to_base_simple_geometry():
    df = telemetry(
        [
            (0.0, 3.0, 4.0),
            (0.1, 0.0, 0.0),
            (0.2, None, None),
        ]
    )

    dist = metrics.distance_to_base(df, base_xy=(0.0, 0.0))

    np.testing.assert_allclose(dist.iloc[:2], [5.0, 0.0])
    assert np.isnan(dist.iloc[2])
