"""Deterministically derive tightly cropped Battle HUD runtime textures.

The approved generated PNGs remain immutable audit sources. Runtime button states
all derive from the approved normal image so geometry and alpha are identical.
"""
from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter, ImageChops


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art_source/generated/mm_tools/battle_hud"
OUTPUT = ROOT / "assets/ui/generated/battle_hud"
PAD = 8


def tight_crop(image: Image.Image, pad: int = PAD) -> Image.Image:
    image = image.convert("RGBA")
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("cannot crop a fully transparent image")
    left, top, right, bottom = bbox
    box = (max(0, left - pad), max(0, top - pad), min(image.width, right + pad), min(image.height, bottom + pad))
    return image.crop(box)


def recolor(base: Image.Image, brightness: float, saturation: float, contrast: float) -> Image.Image:
    alpha = base.getchannel("A")
    rgb = Image.new("RGB", base.size)
    rgb.paste(base.convert("RGB"))
    rgb = ImageEnhance.Color(rgb).enhance(saturation)
    rgb = ImageEnhance.Brightness(rgb).enhance(brightness)
    rgb = ImageEnhance.Contrast(rgb).enhance(contrast)
    result = rgb.convert("RGBA")
    result.putalpha(alpha)
    return result


def pressed(base: Image.Image) -> Image.Image:
    result = recolor(base, 0.82, 0.92, 1.05)
    alpha = base.getchannel("A")
    inset = ImageChops.subtract(alpha, alpha.filter(ImageFilter.GaussianBlur(5)))
    shade = Image.new("RGBA", base.size, (5, 10, 12, 0))
    shade.putalpha(inset.point(lambda value: min(110, value)))
    result.alpha_composite(shade)
    result.putalpha(alpha)
    return result


def derive() -> dict[Path, Image.Image]:
    normal = tight_crop(Image.open(SOURCE / "primary_action_button_normal.png"), 4)
    return {
        OUTPUT / "runtime_primary_action_normal_v2.png": normal,
        OUTPUT / "runtime_primary_action_hover_v2.png": recolor(normal, 1.14, 1.08, 1.04),
        OUTPUT / "runtime_primary_action_pressed_v2.png": pressed(normal),
        OUTPUT / "runtime_primary_action_disabled_v2.png": recolor(normal, 0.64, 0.28, 0.88),
        OUTPUT / "runtime_phase_action_tray_v2.png": tight_crop(Image.open(SOURCE / "phase_action_tray.png")),
        OUTPUT / "runtime_compact_status_frame_v2.png": tight_crop(Image.open(SOURCE / "compact_status_frame.png")),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="verify checked-in derivatives are reproducible")
    args = parser.parse_args()
    expected = derive()
    if args.check:
        stale = [path for path, image in expected.items() if not path.exists() or Image.open(path).convert("RGBA").tobytes() != image.tobytes()]
        if stale:
            raise SystemExit("missing or stale runtime derivatives: " + ", ".join(str(path.relative_to(ROOT)) for path in stale))
        return 0
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for path, image in expected.items():
        image.save(path, optimize=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
