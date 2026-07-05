import numpy as np
import pytest

from badminton_track import calibrate, court


def synthetic_camera_corners() -> np.ndarray:
    """Pixel corners of a plausible rear-elevated 1920x1080 view.

    Trapezoid: far baseline appears narrow and high, near baseline wide
    and low — same clockwise-from-far-left order as court.corner_points_m().
    """
    return np.array(
        [
            [760.0, 260.0],   # far-left
            [1160.0, 260.0],  # far-right
            [1700.0, 1000.0], # near-right
            [220.0, 1000.0],  # near-left
        ],
        dtype=np.float64,
    )


def test_identity_homography_round_trip():
    # Pixel corners identical to the metre corners -> H must act as identity.
    h = calibrate.build_homography(court.corner_points_m())

    pts = np.array([[3.05, 8.68], [0.0, 0.0], [6.1, 13.4]])
    np.testing.assert_allclose(calibrate.project_points(h, pts), pts, atol=1e-9)


def test_synthetic_perspective_round_trip_metres_to_pixels_and_back():
    px_corners = synthetic_camera_corners()
    h = calibrate.build_homography(px_corners)

    # Corners themselves must land exactly on the court model.
    np.testing.assert_allclose(
        calibrate.project_points(h, px_corners),
        court.corner_points_m(),
        atol=1e-6,
    )

    # And arbitrary pixels must round-trip via the inverse homography.
    h_inv = np.linalg.inv(h)
    pts_px = np.array([[960.0, 700.0], [500.0, 900.0], [1400.0, 500.0]])
    metres = calibrate.project_points(h, pts_px)
    back = calibrate.project_points(h_inv, metres)
    np.testing.assert_allclose(back, pts_px, atol=1e-6)


def test_degenerate_corners_raise_calibration_error():
    collinear = np.array(
        [[0.0, 0.0], [1.0, 0.0], [2.0, 0.0], [3.0, 0.0]], dtype=np.float64
    )
    with pytest.raises(calibrate.CalibrationError):
        calibrate.build_homography(collinear)

    with pytest.raises(calibrate.CalibrationError):
        calibrate.build_homography(np.zeros((3, 2)))  # wrong shape


def test_feet_point_is_bbox_bottom_centre():
    bbox = np.array([100.0, 200.0, 300.0, 600.0])  # x1, y1, x2, y2

    np.testing.assert_allclose(calibrate.feet_point(bbox), [200.0, 600.0])


def test_project_feet_projects_only_feet_points():
    px_corners = synthetic_camera_corners()
    h = calibrate.build_homography(px_corners)

    # A bbox whose bottom-centre is exactly the near-left court corner must
    # project to that corner in metres — proving the feet point (not the
    # centre or any other point) is what goes through H.
    bbox = np.array([[120.0, 500.0, 320.0, 1000.0]])  # bottom-centre (220, 1000)
    metres = calibrate.project_feet(h, bbox)

    np.testing.assert_allclose(metres, [[0.0, 13.4]], atol=1e-6)
