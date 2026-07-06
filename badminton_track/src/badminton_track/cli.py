"""`badminton-track` command line interface.

Subcommands:
    calibrate <video> --name <setup>   interactive corner picking -> JSON
    analyze <video> --mode footwork --calibration <setup>
                                        telemetry CSV + court map + summary
Exit codes: 0 success, 2 actionable user error (message on stderr).
"""

import argparse
import dataclasses
import json
import math
import sys
from pathlib import Path

import pandas as pd

from . import biomech, calibrate, coach, courtmap, footwork, metrics
from .config import TrackConfig, load_config
from .errors import ExtrasMissingError

OUTPUT_DIR = Path("output")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="badminton-track",
        description="Local CV analysis of badminton training footage",
    )
    parser.add_argument("--config", type=Path, default=None, help="config.yaml path")
    sub = parser.add_subparsers(dest="command", required=True)

    cal = sub.add_parser("calibrate", help="click court corners for a camera setup")
    cal.add_argument("video", type=Path)
    cal.add_argument("--name", required=True, help="camera-setup name")

    ana = sub.add_parser("analyze", help="run a pipeline over one video")
    ana.add_argument("video", type=Path)
    ana.add_argument("--mode", choices=["footwork", "biomech"], required=True)
    ana.add_argument(
        "--calibration",
        default=None,
        help="camera-setup name (required for footwork mode)",
    )

    rep = sub.add_parser(
        "report", help="coach report from a session's analysis outputs"
    )
    rep.add_argument("stem", help="video stem the analyses were run on")
    return parser


def _video_size(video: Path) -> tuple[int, int]:
    import cv2

    cap = cv2.VideoCapture(str(video))
    size = (
        int(cap.get(cv2.CAP_PROP_FRAME_WIDTH)),
        int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT)),
    )
    cap.release()
    return size


def _calibration_path(cfg: TrackConfig, name: str) -> Path:
    return Path(cfg.footwork.data_dir) / f"calibration-{name}.json"


def _nan_safe(obj):
    """Replace NaN floats with None so json stays standard-compliant."""
    if isinstance(obj, float) and math.isnan(obj):
        return None
    if isinstance(obj, dict):
        return {k: _nan_safe(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_nan_safe(v) for v in obj]
    return obj


def _cmd_calibrate(args: argparse.Namespace, cfg: TrackConfig) -> int:
    corners = calibrate.pick_corners(args.video)
    calib = calibrate.Calibration.create(
        name=args.name, pixel_corners=corners, video_size=_video_size(args.video)
    )
    path = _calibration_path(cfg, args.name)
    path.parent.mkdir(parents=True, exist_ok=True)
    calib.save(path)
    print(f"calibration saved to {path}")
    return 0


def _cmd_analyze_footwork(args: argparse.Namespace, cfg: TrackConfig) -> int:
    if args.calibration is None:
        print(
            "footwork mode needs --calibration <setup-name> "
            "(create one with: badminton-track calibrate <video> --name <setup-name>)",
            file=sys.stderr,
        )
        return 2
    calib_path = _calibration_path(cfg, args.calibration)
    if not calib_path.exists():
        print(
            f"no calibration '{args.calibration}' at {calib_path} — run: "
            f"badminton-track calibrate {args.video} --name {args.calibration}",
            file=sys.stderr,
        )
        return 2
    calib = calibrate.Calibration.load(calib_path)

    fw = cfg.footwork
    df = footwork.run_footwork(args.video, calib, fw)
    filled, gaps = metrics.interpolate_gaps(df, fw.max_gap_s)
    episodes = metrics.detect_episodes(filled, fw.base_point_m, fw.base_radius_m)
    stats = metrics.episode_summary(episodes)
    aggregates = metrics.session_aggregates(filled)

    stem = args.video.stem
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    courtmap.render_court_map(
        filled, episodes, fw, OUTPUT_DIR / f"{stem}-court-map.png"
    )
    summary = _nan_safe(
        {
            "episodes": dataclasses.asdict(stats),
            "session": aggregates,
            "flagged_gaps": [dataclasses.asdict(g) for g in gaps],
        }
    )
    (OUTPUT_DIR / f"{stem}-summary.json").write_text(json.dumps(summary, indent=2))
    print(
        f"footwork analysis done: {stats.count} episodes, "
        f"outputs under {OUTPUT_DIR}/"
    )
    return 0


def _cmd_analyze_biomech(args: argparse.Namespace, cfg: TrackConfig) -> int:
    summary = biomech.run_biomech(args.video, cfg.biomech)
    stem = args.video.stem
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    payload = _nan_safe({"windows": summary.to_dict(orient="records")})
    (OUTPUT_DIR / f"{stem}-biomech-summary.json").write_text(
        json.dumps(payload, indent=2)
    )
    print(
        f"biomech analysis done: {len(summary)} windows, outputs under {OUTPUT_DIR}/"
    )
    return 0


def _cmd_report(args: argparse.Namespace, cfg: TrackConfig) -> int:
    fw_path = OUTPUT_DIR / f"{args.stem}-summary.json"
    bm_path = OUTPUT_DIR / f"{args.stem}-biomech-summary.json"
    if not fw_path.exists() and not bm_path.exists():
        print(
            f"no analysis outputs for '{args.stem}' under {OUTPUT_DIR}/ — run "
            f"`badminton-track analyze <video> --mode footwork|biomech` first",
            file=sys.stderr,
        )
        return 2

    def denull(d: dict) -> dict:
        return {k: (math.nan if v is None else v) for k, v in d.items()}

    stats = aggregates = None
    if fw_path.exists():
        payload = json.loads(fw_path.read_text())
        stats = metrics.EpisodeStats(**denull(payload["episodes"]))
        aggregates = denull(payload["session"])
    biomech_rows = None
    if bm_path.exists():
        windows = json.loads(bm_path.read_text())["windows"]
        if windows:
            biomech_rows = pd.DataFrame(windows)

    summary = coach.build_summary(stats, aggregates, biomech_rows)
    md = coach.produce_report(summary, cfg.coach)
    if md == coach.metrics_only_markdown(summary):
        print(
            "coach model unavailable — wrote a metrics-only report",
            file=sys.stderr,
        )
    out = OUTPUT_DIR / f"{args.stem}-coach-report.md"
    out.write_text(md)
    print(f"coach report written to {out}")
    return 0


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    cfg = load_config(args.config)
    try:
        if args.command == "calibrate":
            return _cmd_calibrate(args, cfg)
        if args.command == "report":
            return _cmd_report(args, cfg)
        if args.mode == "biomech":
            return _cmd_analyze_biomech(args, cfg)
        return _cmd_analyze_footwork(args, cfg)
    except ExtrasMissingError as exc:
        print(str(exc), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
