"""Bake existing original materials into a continuous, world-sized terrain surface.

No API credentials or generation calls are needed. Logical terrain cells and
weather overlays remain independent of this static visual composition.
"""
from pathlib import Path
import sys

import numpy as np
from PIL import Image, ImageEnhance

sys.dont_write_bytecode = True
from build_ruins_terrain_atlas import matched_edges

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "output/imagegen/tilesets"
OUTPUT = ROOT / "assets/tilesets/battlefield_continuous_ground.png"
SIZE = 4096


def smoothstep(low, high, value):
    t = np.clip((value - low) / (high - low), 0, 1)
    return t * t * (3 - 2 * t)


def noise(size, seed, grid):
    rng = np.random.default_rng(seed)
    small = Image.fromarray((rng.random((grid, grid)) * 255).astype("uint8"))
    return np.asarray(small.resize((size, size), Image.Resampling.BICUBIC), dtype=np.float32) / 255


def material(name, period, crop=None, contrast=0.82):
    source = "continuous-soil-source.png" if name == "soil" else f"ruins-{name}-source.png"
    image = Image.open(SOURCE / source).convert("RGB")
    if crop:
        w, h = image.size
        image = image.crop(tuple(int(v * (w if i % 2 == 0 else h)) for i, v in enumerate(crop)))
    image = image.resize((period, period), Image.Resampling.LANCZOS)
    image = ImageEnhance.Contrast(image).enhance(contrast)
    return np.asarray(matched_edges(image, width=period // 10), dtype=np.float32)


def build():
    soil = material("soil", 1100, contrast=0.80)
    concrete = material("concrete", 1500, contrast=0.72)
    vegetation = material("overgrowth", 1280, contrast=0.72)
    # Compute masks once, in map coordinates, rather than per tile. Connected
    # broad bands and large lobes replace isolated 4-cell decorative islands.
    field = noise(SIZE, 43019, 5)
    edge_noise = noise(SIZE, 731, 38) - 0.5
    yy, xx = np.indices((SIZE, SIZE), dtype=np.float32)
    x, y = xx / SIZE, yy / SIZE
    center_distance = np.sqrt((x - 0.5) ** 2 + (y - 0.5) ** 2)
    # Meandering old apron crosses the map and skirts the central planting bed.
    road_center = 0.49 + 0.055 * np.sin(y * 8.0 + 1.2)
    road = 1 - smoothstep(0.065, 0.10, np.abs(x - road_center) + edge_noise * 0.009)
    apron = 1 - smoothstep(0.17, 0.25, np.sqrt(((x - 0.69) * 0.85) ** 2 + ((y - 0.35) * 1.3) ** 2) + edge_noise * 0.018)
    concrete_mask = np.maximum(road, apron) * smoothstep(0.045, 0.115, center_distance)
    outer = smoothstep(0.13, 0.32, center_distance)
    left_bank = 0.20 + 0.055 * np.sin(y * 9.0) + (field - 0.5) * 0.12 - x
    right_bank = x - (0.79 + 0.065 * np.sin(y * 7.0 + 1.8) + (field - 0.5) * 0.10)
    green_mask = smoothstep(-0.035, 0.03, np.maximum(left_bank, right_bank) + edge_noise * 0.016) * outer
    green_mask *= 1 - concrete_mask * 0.90
    # A broad, quiet soil clearing around the mother flower, with no drawn ring.
    light = 0.95 + noise(SIZE, 519, 7) * 0.10
    image = np.empty((SIZE, SIZE, 3), dtype="uint8")
    columns = np.arange(SIZE)
    for start in range(0, SIZE, 128):
        end = min(start + 128, SIZE)
        rows = np.arange(start, end)
        base = soil[rows[:, None] % len(soil), columns[None, :] % len(soil)]
        # Two phase-shifted samples prevent one recognizable soil crop from
        # forming a repeated small-stone lattice across the whole battlefield.
        second = soil[(rows[:, None] + 317) % len(soil), (columns[None, :] + 419) % len(soil)]
        blend = smoothstep(0.25, 0.75, field[start:end])[..., None]
        base = base * (1 - blend * 0.65) + second * blend * 0.65
        stone = concrete[(rows[:, None] + 170) % len(concrete), (columns[None, :] + 380) % len(concrete)]
        green = vegetation[(rows[:, None] + 470) % len(vegetation), (columns[None, :] + 130) % len(vegetation)]
        a, b = concrete_mask[start:end, :, None], green_mask[start:end, :, None]
        pixels = base * (1 - a) + stone * a
        pixels = pixels * (1 - b) + green * b
        image[start:end] = np.clip(pixels * light[start:end, :, None], 0, 255).astype("uint8")
    result = Image.fromarray(image)
    result.save(OUTPUT)
    result.resize((1024, 1024), Image.Resampling.LANCZOS).save(SOURCE / "continuous-ground-layout.png")
    print(f"Baked {OUTPUT.name}: {SIZE}x{SIZE}; static connected regions, no per-frame placement")


if __name__ == "__main__":
    build()
