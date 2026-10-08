"""Run the canonical sprite-gen video -> keyed frames -> loop pipeline.

The game-specific Ark adapter owns generation; this utility owns only the
downstream sequence conversion so effect clips and mother clips use identical
chroma-key, boundary and loop checks.
"""
from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPRITE_GEN = Path.home() / ".codex/skills/sprite-gen"
PYTHON = SPRITE_GEN / ".venv/Scripts/python.exe"
RUNNER = ROOT.parent / "tools/video/sprite_video.py"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--clip", type=Path, required=True)
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--name", default="effect")
    parser.add_argument("--fps", type=float, default=12.0)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    frames = args.out / "frames"
    loop = args.out / "loop"
    extract = ["video-frames", "--clip", str(args.clip), "--out-dir", str(frames),
               "--key", "magenta", "--spill", "auto", "--reference", str(args.reference), "--decontam", "auto"]
    subprocess.run([str(PYTHON), str(RUNNER), *extract], check=True)
    # --fps on video-loop describes the input, not a delivery-rate conversion.
    # Passing 12 for a 24fps source doubled its playback duration.
    ffprobe = next((ROOT.parent / "tools/video").glob("ffmpeg-*/bin/ffprobe.exe"))
    probe = subprocess.run([str(ffprobe), "-v", "error", "-select_streams", "v:0",
                            "-show_entries", "stream=r_frame_rate", "-of", "json", str(args.clip)],
                           capture_output=True, text=True, check=True)
    rate = json.loads(probe.stdout)["streams"][0]["r_frame_rate"]
    numerator, denominator = map(float, rate.split("/"))
    source_fps = numerator / denominator
    commands = [["video-loop", "--frames-dir", str(frames / "keyed"), "--out-dir", str(loop),
                 "--fps", str(source_fps), "--gif-fps", str(args.fps), "--state", "idle",
                 "--cycle", "pinned", "--anchor", "none", "--name", args.name]]
    for command in commands:
        result = subprocess.run([str(PYTHON), str(RUNNER), *command], text=True)
        if result.returncode:
            raise SystemExit(result.returncode)
    report = json.loads((loop / f"{args.name}.loop.report.json").read_text(encoding="utf-8"))
    if report.get("status") != "passed":
        raise SystemExit("sprite-gen loop QA failed")
    cycle_dir = loop / "cycle"
    frame_count = len(tuple(cycle_dir.glob("frame-*.png")))
    print(json.dumps({"status": "passed", "frames": frame_count, "out": str(args.out)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
