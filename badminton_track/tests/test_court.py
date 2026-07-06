import numpy as np

from badminton_track import court


def test_court_constants_match_bwf_dimensions():
    assert court.COURT_LENGTH == 13.4
    assert court.COURT_WIDTH_DOUBLES == 6.1
    assert court.COURT_WIDTH_SINGLES == 5.18
    assert court.NET_Y == 6.7
    assert court.FRONT_SERVICE_LINE_FROM_NET == 1.98


def test_corner_points_order_and_units():
    corners = court.corner_points_m()

    assert isinstance(corners, np.ndarray)
    assert corners.shape == (4, 2)
    assert corners.dtype == np.float64
    # Documented order: clockwise from far-left —
    # (0, 0), (W, 0), (W, L), (0, L) with x across the court, y down it
    # (y = 0 is the far baseline, y = 13.4 the near baseline).
    expected = np.array(
        [
            [0.0, 0.0],
            [6.1, 0.0],
            [6.1, 13.4],
            [0.0, 13.4],
        ]
    )
    np.testing.assert_allclose(corners, expected)


def test_front_service_intersections_positions():
    pts = court.front_service_intersections_m()

    assert pts.shape == (2, 2)
    # Near-half front service line: 1.98 m nearer than the net line (y = 6.7),
    # crossing both doubles sidelines.
    np.testing.assert_allclose(pts[:, 1], 6.7 + 1.98)
    np.testing.assert_allclose(sorted(pts[:, 0]), [0.0, 6.1])


def test_near_half_polygon_covers_near_court_only():
    poly = court.near_half_polygon_m()

    assert poly.shape == (4, 2)
    # The near half spans from the net (y = 6.7) to the near baseline (13.4)
    # across the full doubles width.
    assert poly[:, 1].min() == 6.7
    assert poly[:, 1].max() == 13.4
    assert poly[:, 0].min() == 0.0
    assert poly[:, 0].max() == 6.1
