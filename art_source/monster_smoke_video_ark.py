"""Generate the monster footfall dust puff and publish sprite-gen frames."""
from __future__ import annotations

import base64
import json
import os
import subprocess
import time
import urllib.request
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "art_source/generated/monster_smoke_video_ark"
PIPELINE = ROOT / "art_source/spritegen_sequence_pipeline.py"
PUBLISH = ROOT / "assets/core/generated/monster_smoke_animation"
API = "https://ark.cn-beijing.volces.com/api/v3/contents/generations/tasks"


def request(method: str, url: str, payload: dict | None = None) -> dict:
    key = os.environ.get("ARK_API_KEY")
    if not key:
        raise RuntimeError("ARK_API_KEY is required")
    data = None if payload is None else json.dumps(payload).encode()
    req = urllib.request.Request(url, data=data, method=method, headers={
        "Authorization": "Bearer " + key, "Content-Type": "application/json",
    })
    with urllib.request.urlopen(req, timeout=120) as response:
        return json.load(response)


def make_reference() -> Path:
    OUT.mkdir(parents=True, exist_ok=True)
    ref = OUT / "input-magenta.png"
    image = Image.new("RGBA", (768, 768), (255, 0, 255, 255))
    draw = ImageDraw.Draw(image, "RGBA")
    for box, alpha in [((250, 545, 518, 665), 170), ((180, 585, 410, 695), 130), ((390, 570, 610, 690), 145)]:
        draw.ellipse(box, fill=(139, 145, 132, alpha))
    image.convert("RGB").save(ref)
    return ref


def make_video(ref: Path) -> Path:
    target = OUT / "footfall.mp4"
    task_file = OUT / "footfall.task.json"
    if not target.exists():
        if task_file.exists():
            task_id = json.loads(task_file.read_text(encoding="utf-8"))["id"]
        else:
            encoded = "data:image/png;base64," + base64.b64encode(ref.read_bytes()).decode()
            result = request("POST", API, {
                "model": "doubao-seedance-2-0-mini-260615",
                "content": [
                    {"type": "text", "text": (
                        "Fixed orthographic camera, isolated stylized grey-green dust puff at ground contact. "
                        "Solid pure magenta #FF00FF background. Animate one short footfall: dust compresses at frame 1, "
                        "puffs outward low across the ground, lifts a few soft particles, fades by 0.7 seconds, then "
                        "hold the empty magenta background. No creature, feet, floor, shadow, text, camera movement or cuts."
                    )},
                    {"type": "image_url", "image_url": {"url": encoded}, "role": "first_frame"},
                    {"type": "image_url", "image_url": {"url": encoded}, "role": "last_frame"},
                ],
                "duration": 4, "ratio": "1:1", "generate_audio": False, "watermark": False,
            })
            task_id = result["id"]
            task_file.write_text(json.dumps({"id": task_id}, indent=2), encoding="utf-8")
        for _ in range(120):
            result = request("GET", API + "/" + task_id)
            status = result.get("status")
            if status == "succeeded":
                with urllib.request.urlopen(result["content"]["video_url"], timeout=120) as response:
                    target.write_bytes(response.read())
                break
            if status in {"failed", "expired", "cancelled"}:
                raise RuntimeError("Ark task " + status)
            time.sleep(10)
        else:
            raise RuntimeError("Ark task is still pending; rerun to resume")
    return target


def publish(loop_dir: Path) -> int:
    PUBLISH.mkdir(parents=True, exist_ok=True)
    for old in PUBLISH.glob("puff-*.png"):
        old.unlink()
    meta = json.loads((loop_dir / "footfall.strip.json").read_text(encoding="utf-8"))
    strip = Image.open(loop_dir / "footfall.strip.png").convert("RGBA")
    count = min(12, int(meta["frames"]))
    for index in range(count):
        frame = strip.crop((index * int(meta["w"]), 0, (index + 1) * int(meta["w"]), int(meta["h"])))
        frame.thumbnail((96, 64), Image.Resampling.LANCZOS)
        canvas = Image.new("RGBA", (128, 80))
        canvas.alpha_composite(frame, ((128 - frame.width) // 2, 10 + (64 - frame.height) // 2))
        canvas.save(PUBLISH / f"puff-{index:02d}.png")
    (PUBLISH / "manifest.json").write_text(json.dumps({"frames": count, "fps": 24.0, "loop": False, "pipeline": "sprite-gen video-frames -> video-loop"}, indent=2), encoding="utf-8")
    return count


def main() -> None:
    ref = make_reference()
    clip = make_video(ref)
    out = ROOT / "tmp/monster-smoke-sequence"
    subprocess.run([
        str(Path.home() / ".codex/skills/sprite-gen/.venv/Scripts/python.exe"), str(PIPELINE),
        "--clip", str(clip), "--reference", str(ref), "--out", str(out), "--name", "footfall", "--fps", "24",
    ], check=True)
    print(json.dumps({"published_frames": publish(out / "loop")}, ensure_ascii=False))


if __name__ == "__main__":
    main()
