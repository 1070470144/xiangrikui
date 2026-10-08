"""Turn a downloaded Seedance clip into the Godot thunderstorm manifest."""
import argparse
import json
import shutil
import subprocess
import sys
import os
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--clip", type=Path, required=True)
    parser.add_argument("--frames-dir", type=Path,
                        help="Use an already QA-checked SpriteGen frames directory")
    parser.add_argument("--run-dir", type=Path, required=True)
    parser.add_argument("--project-root", type=Path, required=True)
    parser.add_argument("--video-tools", type=Path,
                        help="Directory containing ffmpeg/ffprobe/img2webp")
    parser.add_argument("--sprite-gen-root", type=Path, required=True)
    args = parser.parse_args()
    if not args.clip.is_file():
        raise SystemExit(f"Missing clip: {args.clip}")
    py = args.sprite_gen_root / ".venv" / "Scripts" / "python.exe"
    if not py.is_file():
        raise SystemExit(f"sprite-gen interpreter missing: {py}")
    args.run_dir.mkdir(parents=True, exist_ok=True)
    frames_dir = args.frames_dir or (args.run_dir / "frames")
    if args.frames_dir is None:
        video_tools = args.video_tools or (args.project_root.parent / "tools" / "video")
        tool_bins = [video_tools, args.project_root.parent / "ffmpeg-bin",
                     video_tools / "libwebp-1.5.0-windows-x64" / "bin"]
        child_env = os.environ.copy()
        child_env["PATH"] = os.pathsep.join(str(path) for path in tool_bins) + os.pathsep + child_env.get("PATH", "")
        subprocess.run([str(py), "-m", "sprite_gen.cli", "video-frames",
                        "--clip", str(args.clip), "--out-dir", str(frames_dir),
                        "--key", "magenta", "--allow-subject-edge-contact",
                        "--report", str(frames_dir / "frames.report.json")],
                       check=True, env=child_env)
        os.environ["PATH"] = child_env["PATH"]
    frame_report = json.loads((frames_dir / "frames.report.json").read_text(encoding="utf-8"))
    keyed = frames_dir / "keyed"
    paths = sorted(keyed.glob("*.png"))
    if not paths or len(paths) != int(frame_report.get("frames", 0)):
        raise SystemExit("Frame extraction did not produce a complete keyed sequence")
    loop_dir = args.run_dir / "loop"
    loop_env = os.environ.copy()
    video_tools = args.video_tools or (args.project_root.parent / "tools" / "video")
    tool_bins = [video_tools, args.project_root.parent / "ffmpeg-bin",
                 video_tools / "libwebp-1.5.0-windows-x64" / "bin",
                 args.project_root.parent / "tools" / "video" / "libwebp-1.5.0-windows-x64" / "bin"]
    loop_env["PATH"] = os.pathsep.join(str(path) for path in tool_bins) + os.pathsep + loop_env.get("PATH", "")
    subprocess.run([str(py), "-m", "sprite_gen.cli", "video-loop",
                    "--frames-dir", str(keyed), "--out-dir", str(loop_dir),
                    "--fps", str(frame_report.get("fps", 12)), "--cycle", "one-shot",
                    "--name", "lightning", "--report", str(loop_dir / "loop.report.json")], check=True,
                    env=loop_env)
    loop_report = json.loads((loop_dir / "loop.report.json").read_text(encoding="utf-8"))
    if loop_report.get("status") != "passed":
        raise SystemExit("SpriteGen loop QA failed; project assets were not changed")
    from PIL import Image
    with Image.open(paths[0]) as image:
        width, height = image.size
    destination = args.project_root / "assets" / "effects" / "weather" / "thunderstorm_realism_v1"
    staging = args.run_dir / "publish"
    publish_frames = staging / "frames"
    if staging.exists():
        shutil.rmtree(staging)
    publish_frames.mkdir(parents=True)
    for index, source in enumerate(paths):
        target = publish_frames / f"frame-{index:02d}.png"
        with Image.open(source) as image:
            if image.mode != "RGBA" or image.size != (width, height):
                raise SystemExit(f"invalid keyed frame: {source}")
            alpha = image.getchannel("A")
            if alpha.getbbox() is None:
                raise SystemExit(f"empty keyed frame: {source}")
            image.save(target, format="PNG")
    manifest = {
        "frames": len(paths), "frame_paths": [
            f"res://assets/effects/weather/thunderstorm_realism_v1/frames/frame-{i:02d}.png"
            for i in range(len(paths))],
        "w": width, "h": height, "source_fps": frame_report.get("fps", 12),
        "delivery_fps": 12, "trigger_seconds": 0.35, "cycle_seconds": 0.35,
        "loop": False, "qa_passed": True, "qa_status": "passed",
        "fallback": "procedural_forked_lightning",
        "source_report": str((args.run_dir / "frames.report.json").resolve()),
        "loop_report": str((loop_dir / "loop.report.json").resolve()),
    }
    (staging / "lightning.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    destination.mkdir(parents=True, exist_ok=True)
    target_frames = destination / "frames"
    if target_frames.exists():
        shutil.rmtree(target_frames)
    shutil.copytree(publish_frames, target_frames)
    shutil.copy2(staging / "lightning.json", destination / "lightning.json")
    print(json.dumps({"frames": len(paths), "size": [width, height], "manifest": str(destination / "lightning.json")}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
