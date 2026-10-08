#!/usr/bin/env python3
"""Normalize approved greenhouse-menu generations into one asset per output."""
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "assets" / "ui" / "generated"


def fit_crop(image: Image.Image, box: tuple[int, int, int, int], size: tuple[int, int]) -> Image.Image:
    return image.crop(box).resize(size, Image.Resampling.LANCZOS).convert("RGB")


def normalize_button(path: Path, size: tuple[int, int], state_index: int) -> None:
    with Image.open(path.with_name(path.name + ".raw.png")) as source:
        source = source.convert("RGB")
        width, height = source.size
        target_ratio = size[0] / size[1]
        # Wide provider canvases contain one button; square canvases contain the
        # common four vertically stacked alternatives.
        if width / height >= 1.5:
            crop_height = min(height, round(width / target_ratio))
            top = max(0, (height - crop_height) // 2)
        else:
            band_height = height / 4
            center = (state_index + 0.5) * band_height
            crop_height = min(round(width / target_ratio), round(band_height))
            top = max(0, min(height - crop_height, round(center - crop_height / 2)))
        margin_x = round(width * 0.035)
        output = fit_crop(source, (margin_x, top, width - margin_x, top + crop_height), size)
        output.save(path, format="PNG")


def main() -> None:
    states = ("normal", "hover", "pressed", "disabled")
    for index, state in enumerate(states):
        normalize_button(ASSETS / f"mm_greenhouse_primary_{state}.png", (650, 118), index)
        normalize_button(ASSETS / f"mm_greenhouse_secondary_{state}.png", (650, 96), index)

    account = ASSETS / "mm_greenhouse_account_plate.png"
    with Image.open(account.with_name(account.name + ".raw.png")) as source:
        width, height = source.size
        output = fit_crop(
            source.convert("RGB"),
            (round(width * 0.115), round(height * 0.405), round(width * 0.89), round(height * 0.56)),
            (560, 116),
        )
        output.save(account, format="PNG")


if __name__ == "__main__":
    main()
