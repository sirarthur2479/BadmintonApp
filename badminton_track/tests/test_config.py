from pathlib import Path

import pytest
from pydantic import ValidationError

from badminton_track.config import TrackConfig, load_config

REPO_CONFIG = Path(__file__).parent.parent / "config.yaml"


def test_defaults_load_without_file():
    cfg = load_config(None)

    assert cfg.footwork.base_radius_m == 1.0
    assert cfg.footwork.frame_stride == 3
    assert cfg.footwork.detector_tag == "yolo11n.pt"
    # Default base point: the T on the near half (centre line × front
    # service line), per the use-case.
    assert cfg.footwork.base_point_m == (3.05, 8.68)
    assert cfg.footwork.max_gap_s == 0.5
    assert cfg.biomech.butter_cutoff_hz == 6.0
    assert cfg.biomech.visibility_threshold == 0.5
    assert cfg.coach.model_tag == "qwen3:8b"
    assert cfg.coach.fallback_model_tag == "gemma3:4b"
    assert cfg.coach.ollama_host == "http://localhost:11434"


def test_yaml_overrides_defaults(tmp_path):
    path = tmp_path / "config.yaml"
    path.write_text(
        "footwork:\n"
        "  base_radius_m: 1.4\n"
        "coach:\n"
        "  model_tag: gemma3:4b\n"
    )

    cfg = load_config(path)

    assert cfg.footwork.base_radius_m == 1.4
    assert cfg.coach.model_tag == "gemma3:4b"
    # Untouched values keep their defaults.
    assert cfg.footwork.frame_stride == 3
    assert cfg.coach.fallback_model_tag == "gemma3:4b"


def test_unknown_key_rejected(tmp_path):
    path = tmp_path / "config.yaml"
    path.write_text("footwork:\n  base_radiusmm: 5\n")

    with pytest.raises(ValidationError):
        load_config(path)


def test_missing_explicit_file_raises(tmp_path):
    with pytest.raises(FileNotFoundError):
        load_config(tmp_path / "nope.yaml")


def test_checked_in_config_yaml_parses():
    cfg = load_config(REPO_CONFIG)

    assert isinstance(cfg, TrackConfig)
    assert cfg == load_config(None), (
        "checked-in config.yaml must mirror the code defaults"
    )
