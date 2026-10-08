from pathlib import Path

from PIL import Image, ImageEnhance


ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art_source"
OUTPUT = ROOT / "assets" / "ui" / "generated"
OUTPUT.mkdir(parents=True, exist_ok=True)


def trim(name: str) -> Image.Image:
    image = Image.open(SOURCE / f"main_menu_{name}_v2.cutout.png").convert("RGBA")
    bounds = image.getchannel("A").getbbox()
    if bounds is None:
        raise RuntimeError(f"{name}: cutout has no visible pixels")
    return image.crop(bounds)


def fit_with_protected_ends(image: Image.Image, size: tuple[int, int], end_fraction: float) -> Image.Image:
    target_width, target_height = size
    scaled_width = round(image.width * target_height / image.height)
    scaled = image.resize((scaled_width, target_height), Image.Resampling.LANCZOS)
    cap = max(1, round(scaled.width * end_fraction))
    if cap * 2 >= target_width:
        cap = max(1, target_width // 4)
    left = scaled.crop((0, 0, cap, target_height))
    center = scaled.crop((cap, 0, scaled.width - cap, target_height))
    right = scaled.crop((scaled.width - cap, 0, scaled.width, target_height))
    center_width = target_width - cap * 2
    center = center.resize((center_width, target_height), Image.Resampling.LANCZOS)
    result = Image.new("RGBA", size)
    result.alpha_composite(left, (0, 0))
    result.alpha_composite(center, (cap, 0))
    result.alpha_composite(right, (target_width - cap, 0))
    return result


def grade(image: Image.Image, brightness: float, saturation: float, alpha_scale: float = 1.0) -> Image.Image:
    alpha = image.getchannel("A")
    rgb = Image.new("RGB", image.size)
    rgb.paste(image, mask=alpha)
    rgb = ImageEnhance.Color(rgb).enhance(saturation)
    rgb = ImageEnhance.Brightness(rgb).enhance(brightness)
    result = rgb.convert("RGBA")
    if alpha_scale != 1.0:
        alpha = alpha.point(lambda value: round(value * alpha_scale))
    result.putalpha(alpha)
    return result


STATES = {
    "normal": (0.92, 0.92, 1.0),
    "hover": (1.10, 1.05, 1.0),
    "pressed": (0.74, 0.88, 1.0),
    "disabled": (0.52, 0.55, 0.72),
}


for family, size, end_fraction in (
    ("primary", (580, 128), 0.13),
    ("secondary", (580, 104), 0.10),
):
    base = fit_with_protected_ends(trim(family), size, end_fraction)
    for state, values in STATES.items():
        grade(base, *values).save(OUTPUT / f"mm_greenhouse_{family}_v2_{state}.png")


panel = fit_with_protected_ends(trim("panel"), (692, 1012), 0.12)
panel.save(OUTPUT / "mm_greenhouse_record_panel_v2.png")

account = fit_with_protected_ends(trim("account"), (556, 116), 0.17)
account.save(OUTPUT / "mm_greenhouse_account_plate_v2.png")
