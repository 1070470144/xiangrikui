"""Bake sprite-gen video effects into exported monster animation frames."""
import json
import math
import io
import subprocess
from pathlib import Path
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
ANIM = ROOT / "assets/enemies/animations"
SMOKE = ROOT / "assets/core/generated/monster_smoke_animation"
NAMES = ["shadow_beast", "erosion_bug", "husk_ram", "spore_moth", "shell_scarab"]


def frame_paths(folder: Path, state: str):
    return sorted(folder.glob(f"{state}-frame-*.png"), key=lambda p: int(p.stem.rsplit("-", 1)[1]))


def smoke_image(index: int, size: tuple[int, int], scale: float) -> Image.Image:
    source = Image.open(SMOKE / f"puff-{index % 12:02d}.png").convert("RGBA")
    source = source.resize((max(1, round(source.width * scale)), max(1, round(source.height * scale))), Image.Resampling.LANCZOS)
    return source


def bake_smoke(image: Image.Image, ground_y: float, index: int, scale: float) -> Image.Image:
    """Build a soft, grounded smoke layer behind the keyed character."""
    underlay = Image.new("RGBA", image.size, (0, 0, 0, 0))
    # A soft contact shadow keeps the puff attached to the ground plane.
    shadow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    cx = image.width * 0.50 + math.sin(index * 0.35) * 4
    shadow_draw.ellipse((cx - image.width * 0.22, ground_y - 3, cx + image.width * 0.22, ground_y + 8), fill=(48, 47, 43, 72))
    underlay.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(4.0)))
    for offset, opacity, blur in ((-0.14, 122, 1.5), (0.10, 92, 2.5)):
        smoke = smoke_image(index + (index // 3) + (1 if offset > 0 else 0), image.size, scale * (0.82 if offset < 0 else 0.66))
        alpha = smoke.getchannel("A").point(lambda a: round(a * opacity / 255.0))
        smoke.putalpha(alpha)
        smoke = smoke.filter(ImageFilter.GaussianBlur(blur))
        x = round((image.width - smoke.width) * (0.5 + offset))
        y = round(ground_y - smoke.height * 0.78 - (index % 5) * 0.7)
        underlay.alpha_composite(smoke, (x, y))
    underlay.alpha_composite(image)
    return underlay


def pristine_walk_frame(path: Path) -> Image.Image:
    """Read the tracked sprite-gen frame so repeated bakes never stack effects."""
    repo_path = path.relative_to(ROOT).as_posix()
    try:
        raw = subprocess.check_output(["git", "show", "HEAD:" + repo_path], cwd=ROOT)
        return Image.open(io.BytesIO(raw)).convert("RGBA")
    except (OSError, subprocess.CalledProcessError):
        return Image.open(path).convert("RGBA")


def bake_airflow(image: Image.Image, index: int) -> None:
    overlay = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    cx, cy = image.width // 2, round(image.height * 0.52)
    phase = index * 0.24
    for side in (-1, 1):
        for ring in range(2):
            rx = 34 + ring * 12
            ry = 18 + ring * 7
            box = (cx - rx, cy - ry, cx + rx, cy + ry)
            start = 205 if side < 0 else -25
            start += math.sin(phase) * 8
            end = 320 if side < 0 else 95
            end += math.sin(phase) * 8
            draw.arc(box, start, end, fill=(151, 224, 224, 120 - ring * 30), width=3)
    image.alpha_composite(overlay)


def make_spawn_and_death(folder: Path, manifest: dict) -> None:
    source = Image.open(frame_paths(folder, "walk")[0]).convert("RGBA")
    width, height = source.size
    runtime = manifest["runtime"]
    ground_y = manifest["animation"]["rows"]["walk"].get("ground_y", height - 14)
    for state in ("spawn", "death"):
        for old in folder.glob(f"{state}-frame-*.png"):
            old.unlink()
    spawn_count, death_count = 12, 16
    for i in range(spawn_count):
        progress = i / (spawn_count - 1)
        frame = source.resize((round(width * (0.55 + 0.45 * progress)), round(height * (0.55 + 0.45 * progress))), Image.Resampling.LANCZOS)
        frame.putalpha(frame.getchannel("A").point(lambda a: round(a * progress)))
        canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        canvas.alpha_composite(frame, ((width - frame.width) // 2, height - frame.height))
        glow = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        ImageDraw.Draw(glow).ellipse((width * .25, ground_y - 10, width * .75, ground_y + 8), fill=(244, 206, 112, round(70 * (1 - progress))))
        canvas.alpha_composite(glow)
        canvas.save(folder / f"spawn-frame-{i}.png")
    for i in range(death_count):
        progress = i / (death_count - 1)
        frame = source.rotate(-10 + progress * 35, resample=Image.Resampling.BICUBIC, expand=False)
        frame = ImageEnhance.Color(frame).enhance(0.45)
        frame = ImageEnhance.Brightness(frame).enhance(1.0 + progress * 0.35)
        frame.putalpha(frame.getchannel("A").point(lambda a: round(a * (1.0 - progress))))
        canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        canvas.alpha_composite(frame, (0, round(progress * 12)))
        ring = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        ImageDraw.Draw(ring).ellipse((width * .18, ground_y - 7, width * .82, ground_y + 9), outline=(212, 90, 88, round(160 * (1 - progress))), width=3)
        canvas.alpha_composite(ring)
        canvas.save(folder / f"death-frame-{i}.png")
    rows = manifest["animation"]["rows"]
    base = dict(rows["walk"])
    for state, count, loop, fps in (("spawn", spawn_count, False, 24.0), ("death", death_count, False, 24.0)):
        spec = dict(base)
        spec.update({"frames": count, "fps": fps, "loop": loop,
                     "durations_ms": [1000.0 / fps] * count,
                     "source": f"art_source/generated/monster_video_batch/{folder.name}/walk.mp4",
                     "baked_effect": state})
        rows[state] = spec


def main() -> None:
    for name in NAMES:
        folder = ANIM / name
        manifest_path = folder / "manifest.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        walk = frame_paths(folder, "walk")
        if not walk:
            continue
        row = manifest["animation"]["rows"]["walk"]
        ground_y = float(row.get("ground_y", Image.open(walk[0]).height - 14))
        for index, path in enumerate(walk):
            image = pristine_walk_frame(path)
            if name == "spore_moth":
                bake_airflow(image, index)
            else:
                image = bake_smoke(image, ground_y, index, 0.72 if name in ("shadow_beast", "erosion_bug") else 0.62)
            image.save(path)
        make_spawn_and_death(folder, manifest)
        manifest["engine"] = "sprite-gen-video-baked-effects"
        manifest["video_frame_extract"] = {
            "tool": "sprite-gen video-frames",
            "clip": f"art_source/generated/monster_video_batch/{name}/walk.mp4",
            "keyed_frames": f"art_source/generated/monster_video_batch/{name}/walk-frames-spritegen/keyed",
            "status": "extracted",
        }
        manifest["baked_effects"] = {"walk": "footfall_smoke" if name != "spore_moth" else "wing_airflow", "spawn": "roar_entry", "death": "collapse_burst"}
        manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
