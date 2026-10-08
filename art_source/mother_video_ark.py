"""Generate and publish a common mother-flower animation through sprite-gen.

The Ark key is read only from ARK_API_KEY. The downloaded clip is converted by
spritegen_sequence_pipeline.py; no hand-authored frame extraction is used.
"""
from __future__ import annotations

import base64
import json
import os
import subprocess
import time
import urllib.request
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/core/ART_CORE_MotherFlower_Healthy.png"
OUT = ROOT / "art_source/generated/mother_video_ark"
PIPELINE = ROOT / "art_source/spritegen_sequence_pipeline.py"
PUBLISH = ROOT / "assets/core/generated/mother_animation"
API = "https://ark.cn-beijing.volces.com/api/v3/contents/generations/tasks"
MODEL = "doubao-seedance-2-0-mini-260615"


def request(method: str, url: str, payload: dict | None = None) -> dict:
    key = os.environ.get("ARK_API_KEY")
    if not key:
        raise RuntimeError("ARK_API_KEY is required")
    data = None if payload is None else json.dumps(payload).encode()
    req = urllib.request.Request(url, data=data, method=method, headers={
        "Authorization": "Bearer " + key,
        "Content-Type": "application/json",
    })
    with urllib.request.urlopen(req, timeout=120) as response:
        return json.load(response)


def make_reference() -> Path:
    OUT.mkdir(parents=True, exist_ok=True)
    ref = OUT / "input-magenta.png"
    image = Image.open(SOURCE).convert("RGBA")
    image.thumbnail((490, 490), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (768, 768), (255, 0, 255, 255))
    canvas.alpha_composite(image, ((768 - image.width) // 2, 640 - image.height))
    canvas.convert("RGB").save(ref)
    return ref


def generate(ref: Path) -> Path:
    target = OUT / "common.mp4"
    task_file = OUT / "common.task.json"
    if target.exists():
        return target
    if task_file.exists():
        task_id = json.loads(task_file.read_text(encoding="utf-8"))["id"]
    else:
        prompt = (
            "Fixed locked orthographic 3/4 overhead camera. Animate this exact rooted mother flower. "
            "Preserve silhouette, petals, leaves, roots, colors and proportions. "
            "Solid pure magenta #FF00FF background on every frame. No floor, shadow, scenery or text. "
            "Roots stay anchored. Four-second seamless common animation: seconds 0-1 gentle breathing and petal sway; "
            "seconds 1-2 a soft golden energy pulse expands from the center; seconds 2-3 recover with one small leaf sway; "
            "seconds 3-4 return exactly to the starting pose. No camera movement, cuts, morphing or extra objects."
        )
        encoded = "data:image/png;base64," + base64.b64encode(ref.read_bytes()).decode()
        result = request("POST", API, {
            "model": MODEL,
            "content": [
                {"type": "text", "text": prompt},
                {"type": "image_url", "image_url": {"url": encoded}, "role": "first_frame"},
                {"type": "image_url", "image_url": {"url": encoded}, "role": "last_frame"},
            ],
            "duration": 4,
            "ratio": "1:1",
            "generate_audio": False,
            "watermark": False,
        })
        task_id = result["id"]
        task_file.write_text(json.dumps({"id": task_id, "model": MODEL}, indent=2), encoding="utf-8")
    for _ in range(120):
        result = request("GET", API + "/" + task_id)
        status = result.get("status")
        if status == "succeeded":
            with urllib.request.urlopen(result["content"]["video_url"], timeout=120) as response:
                data = response.read()
            target.write_bytes(data)
            return target
        if status in {"failed", "expired", "cancelled"}:
            raise RuntimeError("Ark task " + status)
        time.sleep(10)
    raise RuntimeError("Ark task is still pending; rerun to resume")


def publish_frames(loop_dir: Path) -> int:
    PUBLISH.mkdir(parents=True, exist_ok=True)
    for old in PUBLISH.glob("common-*.png"):
        old.unlink()
    meta = json.loads((loop_dir / "common.strip.json").read_text(encoding="utf-8"))
    strip = Image.open(loop_dir / "common.strip.png").convert("RGBA")
    frame_count = int(meta["frames"])
    frame_width = int(meta["w"])
    frame_height = int(meta["h"])
    for index in range(frame_count):
        frame = strip.crop((index * frame_width, 0, (index + 1) * frame_width, frame_height))
        frame.thumbnail((210, 210), Image.Resampling.LANCZOS)
        canvas = Image.new("RGBA", (256, 256))
        # Keep a visible top margin; the source loop's flower touches its upper edge.
        canvas.alpha_composite(frame, ((256 - frame.width) // 2, 18))
        canvas.save(PUBLISH / f"common-{index:03d}.png")
    (PUBLISH / "manifest.json").write_text(json.dumps({
        "frames": frame_count, "fps": 12.0, "loop": True,
        "source": "art_source/generated/mother_video_ark/common.mp4",
        "pipeline": "sprite-gen video-frames -> video-loop",
    }, indent=2), encoding="utf-8")
    return frame_count


def main() -> None:
    ref = make_reference()
    clip = generate(ref)
    out = ROOT / "tmp/mother-common-sequence"
    subprocess.run([
        str(Path.home() / ".codex/skills/sprite-gen/.venv/Scripts/python.exe"),
        str(PIPELINE), "--clip", str(clip), "--reference", str(ref),
        "--out", str(out), "--name", "common", "--fps", "12",
    ], check=True)
    print(json.dumps({"published_frames": publish_frames(out / "loop")}, ensure_ascii=False))


if __name__ == "__main__":
    main()
