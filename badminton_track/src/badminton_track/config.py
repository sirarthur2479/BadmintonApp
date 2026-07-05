"""Typed configuration for the analysis pipelines.

`load_config(None)` returns pure code defaults; passing a path loads YAML
over those defaults. Unknown keys are rejected (`extra="forbid"`) so typos
fail loudly instead of silently running with defaults.
"""

from pathlib import Path

import yaml
from pydantic import BaseModel, ConfigDict


class _StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class FootworkConfig(_StrictModel):
    detector_tag: str = "yolo11n.pt"
    frame_stride: int = 3
    # The T on the near half: centre line (3.05) × front service line
    # (net 6.7 + 1.98). A real base position sits slightly behind the T —
    # override per player.
    base_point_m: tuple[float, float] = (3.05, 8.68)
    base_radius_m: float = 1.0
    max_gap_s: float = 0.5
    # Target-player lock: initial near-half scoring window, and how long the
    # locked id may vanish before another near-half track can take over.
    lock_warmup_s: float = 2.0
    lock_grace_s: float = 1.0
    data_dir: Path = Path("data")


class BiomechConfig(_StrictModel):
    model_asset_path: Path = Path("pose_landmarker_full.task")
    butter_cutoff_hz: float = 6.0
    visibility_threshold: float = 0.5


class CoachConfig(_StrictModel):
    model_tag: str = "qwen3:8b"
    fallback_model_tag: str = "gemma3:4b"
    ollama_host: str = "http://localhost:11434"


class TrackConfig(_StrictModel):
    footwork: FootworkConfig = FootworkConfig()
    biomech: BiomechConfig = BiomechConfig()
    coach: CoachConfig = CoachConfig()


def load_config(path: Path | None) -> TrackConfig:
    """Load configuration; `None` means pure defaults.

    An explicit path that does not exist raises FileNotFoundError — a typo'd
    --config must never silently fall back to defaults.
    """
    if path is None:
        return TrackConfig()
    raw = yaml.safe_load(Path(path).read_text()) or {}
    return TrackConfig.model_validate(raw)
