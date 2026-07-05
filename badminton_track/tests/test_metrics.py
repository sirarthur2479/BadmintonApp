import numpy as np
import pandas as pd
import pytest

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


BASE = (3.05, 8.68)


def walk(distances: list[float | None], dt: float = 0.1) -> pd.DataFrame:
    """Telemetry moving straight out along +y from the base point.

    Each entry is the distance from base at successive timesteps, so episode
    tests can be written in terms of distance directly.
    """
    rows = []
    for i, d in enumerate(distances):
        if d is None:
            rows.append((round(i * dt, 3), None, None))
        else:
            rows.append((round(i * dt, 3), BASE[0], BASE[1] + d))
    return telemetry(rows)


def test_no_episode_when_player_stays_inside_radius():
    df = walk([0.0, 0.5, 0.9, 0.3, 0.0])

    episodes = metrics.detect_episodes(df, base_xy=BASE, radius_m=1.0)

    assert episodes == []


def test_episode_boundaries_on_leave_and_reenter():
    #        in   out  out  out  in
    df = walk([0.5, 1.5, 2.5, 1.5, 0.5])

    episodes = metrics.detect_episodes(df, base_xy=BASE, radius_m=1.0)

    assert len(episodes) == 1
    ep = episodes[0]
    assert ep.start_t == 0.1  # first sample outside
    assert ep.end_t == 0.4  # re-entry sample
    assert ep.peak_t == 0.2
    assert ep.peak_distance_m == 2.5


def test_recovery_latency_is_peak_to_reentry_time():
    df = walk([0.5, 1.5, 2.5, 2.0, 1.5, 1.2, 0.5])

    ep = metrics.detect_episodes(df, base_xy=BASE, radius_m=1.0)[0]

    # peak at t=0.2, re-entry at t=0.6
    assert ep.recovery_latency_s == pytest.approx(0.4)


def test_open_ended_excursion_is_dropped():
    df = walk([0.5, 1.5, 2.5, 3.0])  # never comes back

    episodes = metrics.detect_episodes(df, base_xy=BASE, radius_m=1.0)

    assert episodes == []


def test_multiple_episodes_in_sequence():
    df = walk([0.5, 2.0, 0.5, 0.5, 3.0, 2.0, 0.5])

    episodes = metrics.detect_episodes(df, base_xy=BASE, radius_m=1.0)

    assert len(episodes) == 2
    assert episodes[0].end_t < episodes[1].start_t


def test_nan_samples_do_not_open_or_close_episodes():
    # NaN in the middle of an excursion: episode continues across it.
    df = walk([0.5, 2.0, None, 2.5, 0.5])

    episodes = metrics.detect_episodes(df, base_xy=BASE, radius_m=1.0)

    assert len(episodes) == 1
    assert episodes[0].peak_distance_m == 2.5


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
