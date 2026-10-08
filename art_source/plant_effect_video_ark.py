"""Generate isolated botanical VFX, then key and assemble them with SpriteGen."""
from __future__ import annotations

import json
import base64
import argparse
import os
import shutil
import subprocess
import time
from pathlib import Path

from PIL import Image
import numpy as np

from mother_video_ark import API, MODEL, request

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "art_source/generated/plant_attack_fx_video_v2"
PUBLISH = ROOT / "assets/effects/plants"
PYTHON = Path.home() / ".codex/skills/sprite-gen/.venv/Scripts/python.exe"
RUNNER = ROOT.parent / "tools/video/sprite_video.py"
MOTIONS = {
    "vine": "A thorny emerald vine whip, with two secondary tendrils and small pointed leaves. Starts as a compact coil at the left, winds back, lashes horizontally to the right across the frame, curls its thorn tip around an invisible target, then smoothly retracts into the exact starting coil. The root origin remains at x=15%, y=50%; maximum tip at x=85%, y=50%. Clear elastic follow-through, overlapping tendrils and natural leaf drag. No plant body or pot.",
    "pollen": "A compact cluster of golden pollen grains at frame center swells, blossoms into a radial burst of warm golden seeds and tiny ivory petals, then dissipates and returns to the initial compact cluster. Clear botanical particles, sharp silhouettes, no circular graphic rings.",
    "frost": "A compact cluster of pale cyan ice crystals at frame center gathers energy, bursts into a fan of sharp icy botanical shards and frosted leaves, then dissipates and returns to the original compact cluster. Distinct crystal silhouettes, no straight laser beam or graphic circles.",
}


def save(path: Path, value: dict) -> None:
    path.write_text(json.dumps(value, indent=2), encoding="utf-8")


def run(*args: str) -> None:
    subprocess.run([str(PYTHON), str(RUNNER), *args], check=True)


def effect_folder(name: str) -> Path:
    return OUT / (name + "-reframed")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--process-only", action="store_true")
    parser.add_argument("--effects", nargs="+", choices=tuple(MOTIONS), default=list(MOTIONS))
    args = parser.parse_args()
    if not args.process_only and not os.environ.get("ARK_API_KEY"):
        raise RuntimeError("ARK_API_KEY is required")
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / ".gdignore").touch()
    tasks = {}
    for name in args.effects:
        motion = MOTIONS[name]
        folder = effect_folder(name)
        folder.mkdir(exist_ok=True)
        if args.process_only:
            if not (folder / "clip.mp4").exists():
                raise RuntimeError("Missing clip for " + name)
            continue
        reference = folder / "reference.png"
        if not reference.exists():
            still = folder / "reference-rgba.png"
            previous = OUT / name / "reference-rgba.png"
            if not still.exists() and previous.exists():
                shutil.copy2(previous, still)
            if not still.exists():
                subjects = {
                    "vine": "a compact emerald green thorny vine coil with small leaves, rooted at the left quarter of the image; three quarters of the image on the right are empty",
                    "pollen": "a small compact cluster of distinct luminous golden pollen seeds and two ivory petals centered in the image",
                    "frost": "a small compact cluster of pale cyan botanical ice crystals centered in the image",
                }
                subprocess.run([str(PYTHON), str(ROOT / "art_source/spritegen_image_api.py"),
                    "gen", "--provider", "openai", "--model", "gpt-image-2", "--transparent",
                    "--alpha-mode", "native", "--aspect-ratio", "16:9" if name == "vine" else "1:1",
                    "--prompt", "Isolated hand-painted fantasy game attack VFX asset: " + subjects[name] +
                    ". Transparent background. No character, floor, shadow, scenery, glow haze, text or UI. Generous empty margins.",
                    "--out", str(still)], check=True)
            image = Image.open(still).convert("RGBA")
            image.thumbnail((500, 282) if name == "vine" else (200, 200), Image.Resampling.LANCZOS)
            canvas = Image.new("RGBA", (960, 540) if name == "vine" else (640, 640), (255, 0, 255, 255))
            canvas.alpha_composite(image, (64, 100) if name == "vine" else ((640-image.width)//2, (640-image.height)//2))
            canvas.convert("RGB").save(reference)
        prompt = (
            "Isolated hand-painted fantasy game attack visual effect only. Fixed orthographic camera. "
            "Uniform solid pure magenta #FF00FF background throughout, no scene, ground, shadows, character, text or UI. "
            "Keep all visible elements inside the frame with at least 10% empty margin. Crisp edges, no motion blur. "
            "One single four-second action: 0-0.4 seconds anticipation, 0.4-1.6 strike, 1.6-2.2 impact, "
            "2.2-3.6 recovery, 3.6-4 hold the exact initial shape and placement. " + motion
        )
        if name == "vine":
            prompt += " Preserve the exact reference root position. Maximum reach only 65% of the canvas width. All three complete curved thorn tips remain visible. No speed lines, no luminous streaks, no extra roots. Camera must stay fixed and the background remains exactly flat magenta."
        else:
            prompt += " The whole burst occupies only the central half of the image. Maximum cloud diameter is 320 pixels on this 640 pixel reference. Keep the surrounding 160 pixel margin absolutely empty magenta. Small particles only. No zoom or camera movement."
        (folder / "prompt.txt").write_text(prompt, encoding="utf-8")
        if (folder / "clip.mp4").exists():
            continue
        task_file = folder / "task.json"
        if task_file.exists():
            tasks[name] = json.loads(task_file.read_text())["id"]
            continue
        intent = folder / "intent.json"
        if intent.exists():
            raise RuntimeError("Unresolved creation intent for " + name + "; inspect before retrying")
        save(intent, {"model": MODEL, "prompt": prompt})
        encoded = "data:image/png;base64," + base64.b64encode(reference.read_bytes()).decode()
        result = request("POST", API, {
            "model": MODEL, "content": [{"type": "text", "text": prompt},
                {"type": "image_url", "image_url": {"url": encoded}, "role": "first_frame"},
                {"type": "image_url", "image_url": {"url": encoded}, "role": "last_frame"}],
            "duration": 4, "ratio": "16:9" if name == "vine" else "1:1",
            "generate_audio": False, "watermark": False,
        })
        save(task_file, {"id": result["id"], "model": MODEL})
        tasks[name] = result["id"]
        print(name + " submitted", flush=True)
    import urllib.request
    for attempt in range(120):
        for name, task_id in list(tasks.items()):
            result = request("GET", API + "/" + task_id)
            status = result.get("status")
            save(effect_folder(name) / "status.json", {"status": status, "id": task_id})
            if status == "succeeded":
                with urllib.request.urlopen(result["content"]["video_url"], timeout=120) as response:
                    (effect_folder(name) / "clip.mp4").write_bytes(response.read())
                del tasks[name]
                print(name + " downloaded", flush=True)
            elif status in {"failed", "expired", "cancelled"}:
                raise RuntimeError(name + " task " + str(status) + ": " + str(result.get("error", {})))
        if not tasks:
            break
        time.sleep(10)
    if tasks:
        raise RuntimeError("Tasks pending; rerun to resume")
    PUBLISH.mkdir(parents=True, exist_ok=True)
    for name in args.effects:
        folder = effect_folder(name)
        frames = folder / "frames"
        loop = folder / "sequence"
        if not (frames / "frames.report.json").exists():
            run("video-frames", "--clip", str(folder / "clip.mp4"), "--out-dir", str(frames),
                "--key", "magenta", "--spill", "full", "--decontam", "auto",
                "--allow-subject-edge-contact")
        report = json.loads((frames / "frames.report.json").read_text())
        if float(report.get("alpha_zero_pct_min", 0)) <= 0:
            raise RuntimeError(name + " frame QA failed")
        fps = float(report.get("fps", 24))
        qa_path = loop / (name + ".loop.report.json")
        if not qa_path.exists() or json.loads(qa_path.read_text()).get("status") != "passed":
            run("video-loop", "--frames-dir", str(frames / "keyed"), "--out-dir", str(loop),
                "--fps", str(fps), "--state", "attack", "--cycle", "pinned", "--anchor", "none",
                "--strip-height", "192", "--name", name)
        qa = json.loads((loop / (name + ".loop.report.json")).read_text())
        if qa.get("status") != "passed":
            raise RuntimeError(name + " sequence QA failed")
        shutil.copy2(loop / (name + ".strip.json"), PUBLISH / (name + ".strip.json"))
        # Runtime coordinates describe SpriteGen's canonical union-cropped strip.
        meta = json.loads((loop / (name + ".strip.json")).read_text())
        # Pack canonical strip cells into a Godot texture below GPU width limits.
        columns = min(8, int(meta["frames"]))
        rows = (int(meta["frames"]) + columns - 1) // columns
        strip = Image.open(loop / (name + ".strip.png")).convert("RGBA")
        atlas = Image.new("RGBA", (int(meta["w"]) * columns, int(meta["h"]) * rows))
        for index in range(int(meta["frames"])):
            cell = strip.crop((index * meta["w"], 0, (index + 1) * meta["w"], meta["h"]))
            atlas.alpha_composite(cell, ((index % columns) * meta["w"], (index // columns) * meta["h"]))
        atlas.save(PUBLISH / (name + ".atlas.png"))
        old_strip = PUBLISH / (name + ".strip.png")
        if old_strip.exists():
            old_strip.unlink()
        paths = sorted((loop / "cycle").glob("frame-*.png"))
        boxes = [Image.open(path).getchannel("A").point(lambda a: 255 if a >= 8 else 0).getbbox() for path in paths]
        nonempty = [box for box in boxes if box]
        first = next(box for box in boxes if box)
        left = min(box[0] for box in nonempty) - 8
        top = max(0, min(box[1] for box in nonempty) - 8)
        scale = float(meta["scale"])
        anchor = [((first[0] + first[2]) * 0.5 - left) * scale,
                  ((first[1] + first[3]) * 0.5 - top) * scale]
        reach_vector = [max(1, meta["w"] - 8 * scale - anchor[0]), 0.0]
        if name == "vine":
            first_index = next(index for index, box in enumerate(boxes) if box)
            alpha = np.asarray(Image.open(paths[first_index]).getchannel("A"))
            root_top = first[3] - max(8, round((first[3] - first[1]) * 0.12))
            root_right = first[0] + round((first[2] - first[0]) * 0.6)
            ys, xs = np.nonzero(alpha[root_top:first[3], first[0]:root_right] >= 8)
            if len(xs):
                anchor = [(float(xs.mean()) + first[0] - left) * scale,
                          (float(ys.mean()) + root_top - top) * scale]
            tip_index = max((i for i, box in enumerate(boxes) if box), key=lambda i: boxes[i][2])
            tip_box = boxes[tip_index]
            alpha = np.asarray(Image.open(paths[tip_index]).getchannel("A"))
            tip_left = max(tip_box[0], tip_box[2] - 12)
            ys, xs = np.nonzero(alpha[:, tip_left:tip_box[2]] >= 8)
            reach_vector = [(float(xs.mean()) + tip_left - left) * scale - anchor[0],
                            (float(ys.mean()) - top) * scale - anchor[1]]
        save(PUBLISH / (name + ".runtime.json"), {
            "anchor": anchor if name == "vine" else [meta["w"] * 0.5, meta["h"] * 0.5],
            "reach": max(1, meta["w"] - 8 * scale - anchor[0]),
            "reach_vector": reach_vector,
            "duration": 0.72 if name == "vine" else 0.64,
            "columns": columns, "rows": rows,
            "source": str((folder / "clip.mp4").relative_to(ROOT)),
            "pipeline": "SpriteGen video-frames -> video-loop (attack)", "loop": False,
        })
        print(name + " published", flush=True)


if __name__ == "__main__":
    main()
