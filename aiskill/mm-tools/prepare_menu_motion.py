"""Opaque background route: sprite-gen extraction + loop seam + paged atlases.

Full-scene backgrounds are intentionally not chroma keyed or union-cropped.
sprite-gen owns ffprobe/extraction, distance measurement and atomic publication.
This project adapter owns background resampling, crossfade and Godot page layout.
"""
import argparse
import json
import os
import subprocess
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
from sprite_gen.video.frames import probe, extract
from sprite_gen.video.loop import distance_matrix
from sprite_gen.spec.runio import atomic_save_image, atomic_write_text

FPS = 12
SIZE = (864, 486)
COLS, ROWS = 4, 3
OVERLAP = 8


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--run-dir", required=True, type=Path)
    parser.add_argument("--out-dir", required=True, type=Path)
    parser.add_argument("--tools", required=True, type=Path)
    args = parser.parse_args()
    directories = sorted({str(p.parent) for p in args.tools.rglob("*.exe")
                          if p.name in ("ffmpeg.exe", "ffprobe.exe")})
    os.environ["PATH"] = os.pathsep.join(directories) + os.pathsep + os.environ["PATH"]
    source = args.run_dir / "main_menu.mp4"
    source_meta = probe(source)
    runtime = args.run_dir / "runtime12fps.mp4"
    import shutil
    result = subprocess.run([shutil.which("ffmpeg"), "-v", "error", "-y", "-i", str(source),
                             "-vf", f"fps={FPS},scale={SIZE[0]}:{SIZE[1]}",
                             "-c:v", "libx264", "-crf", "12", "-an", str(runtime)], capture_output=True)
    if result.returncode: raise SystemExit("Background video resampling failed")
    # Canonical sprite-gen frame extraction; no keying on an opaque scene.
    raw_files = extract(runtime, args.run_dir / "raw")
    # Ignore the terminal duplicated/pinned endpoint at t=duration.
    count = min(len(raw_files), round(float(source_meta["duration"]) * FPS))
    raw = [Image.open(p).convert("RGB") for p in raw_files[:count]]
    if len(raw) < 3 * OVERLAP: raise SystemExit("Clip too short for background loop")
    # Tail approaches the first eight frames, then wraps to frame eight.
    # This preserves forward-only environmental movement without ping-pong.
    cycle = raw[OVERLAP:-OVERLAP]
    for i in range(OVERLAP):
        cycle.append(Image.blend(raw[-OVERLAP + i], raw[i], (i + 1) / OVERLAP))
    args.out_dir.mkdir(parents=True, exist_ok=True)
    preview_dir = args.run_dir / "cycle"
    preview_dir.mkdir(exist_ok=True)
    for i, frame in enumerate(cycle):
        atomic_save_image(frame, preview_dir / f"frame-{i:04d}.png")
    matrix = distance_matrix(sorted(preview_dir.glob("frame-*.png")))
    adjacent = np.array([matrix[i, i + 1] for i in range(len(cycle) - 1)])
    seam_ratio = float(matrix[-1, 0]) / max(1e-9, float(adjacent.mean()))
    # Refuse a material discontinuity rather than publishing a flashing loop.
    if seam_ratio > 2.0: raise SystemExit(f"Background seam failed: ratio {seam_ratio:.3f}")
    frames, pages = [], []
    for page_index, start in enumerate(range(0, len(cycle), COLS * ROWS)):
        batch = cycle[start:start + COLS * ROWS]
        rows = (len(batch) + COLS - 1) // COLS
        page = Image.new("RGB", (SIZE[0] * COLS, SIZE[1] * rows))
        for local, frame in enumerate(batch):
            x, y = (local % COLS) * SIZE[0], (local // COLS) * SIZE[1]
            page.paste(frame, (x, y))
            frames.append({"page":page_index, "x":x, "y":y, "w":SIZE[0], "h":SIZE[1]})
        name = f"page-{page_index:02d}.png"
        atomic_save_image(page, args.out_dir / name)
        pages.append("res://assets/backgrounds/menu_motion/" + name)
    metadata = {"kind":"opaque-background-animation", "fps":FPS, "loop":True,
                "frame_count":len(cycle), "duration_seconds":len(cycle)/FPS,
                "frame_size":list(SIZE), "pages":pages, "frames":frames}
    atomic_write_text(args.out_dir / "animation.json", json.dumps(metadata, indent=2))
    report = {"source":str(source), "source_probe":source_meta,
              "engine_extraction":"sprite_gen.video.frames.extract", "opaque":True,
              "runtime_probe":probe(runtime), "crossfade_frames":OVERLAP,
              "crossfade_seconds":OVERLAP/FPS, "frame_count":len(cycle),
              "seam_ratio":round(seam_ratio, 4), "seam_gate":2.0,
              "fps":FPS, "duration_seconds":len(cycle)/FPS, "pages":len(pages),
              "decoded_texture_mib":round(sum(Image.open(args.out_dir/p.split('/')[-1]).width * Image.open(args.out_dir/p.split('/')[-1]).height * 4 for p in pages)/1024**2, 1),
              "output":str(args.out_dir), "status":"passed"}
    atomic_write_text(args.run_dir / "animation.report.json", json.dumps(report, indent=2))
    # A standalone visual review file, never loaded by the game.
    cycle[0].save(args.run_dir / "poster.png")
    cycle[0].resize((576,324)).save(args.run_dir / "preview.gif", save_all=True,
        append_images=[im.resize((576,324)) for im in cycle[1::2]], duration=round(2000/FPS), loop=0)
    print(json.dumps(report, indent=2))


if __name__ == "__main__": main()
