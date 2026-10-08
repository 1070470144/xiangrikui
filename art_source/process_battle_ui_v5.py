"""Derive V5 siblings offline; --recolor-only needs no generated masters."""
from __future__ import annotations
import argparse
import json
import hashlib
from pathlib import Path
import numpy as np
from PIL import Image, ImageEnhance

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "assets/ui/generated/battle_ui_v5"
SOURCE = ROOT / "art_source/generated/mm_tools/battle_ui_v5"
MANIFEST = ROOT / "art_source/manifests/battle_ui_v5.json"


def project_path(value: str) -> Path:
    return ROOT / value.removeprefix("res://")


def nine_slice(image: Image.Image, target: tuple[int, int]) -> Image.Image:
    # A single scale for corner X/Y preserves relief geometry. Only rails and
    # the deliberately quiet center stretch to fit the runtime rectangle.
    sx, sy = min(220, image.width // 3), min(180, image.height // 3)
    scale = min(16 / sx, 14 / sy)
    dx, dy = max(1, round(sx * scale)), max(1, round(sy * scale))
    xs, ys = [0, sx, image.width - sx, image.width], [0, sy, image.height - sy, image.height]
    xd, yd = [0, dx, target[0] - dx, target[0]], [0, dy, target[1] - dy, target[1]]
    result = Image.new("RGBA", target)
    for row in range(3):
        for col in range(3):
            tile = image.crop((xs[col], ys[row], xs[col + 1], ys[row + 1]))
            tile = tile.resize((xd[col + 1] - xd[col], yd[row + 1] - yd[row]), Image.Resampling.LANCZOS)
            result.alpha_composite(tile, (xd[col], yd[row]))
    return result


def clean_alpha(image: Image.Image) -> Image.Image:
    pixels = np.array(image.convert("RGBA"))
    pixels[..., :3][pixels[..., 3] == 0] = 0
    return Image.fromarray(pixels, "RGBA")


def derive_masters(available_only: bool, check: bool) -> dict:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    records, missing = [], []
    for asset in manifest["assets"]:
        if not asset["generation"]["enabled"]:
            continue
        output = project_path(asset["output"]["path"])
        report = output.with_suffix(".report.json")
        if not output.exists() or not report.exists():
            missing.append(asset["id"])
            continue
        contract = json.loads(report.read_text(encoding="utf-8"))
        if contract.get("alpha", {}).get("strategy") != "native":
            raise ValueError("Only sprite-gen native-alpha verified masters may derive")
        raw = output.with_name(output.name + ".raw.png")
        with Image.open(raw) as opened:
            if opened.mode != "RGBA":
                raise ValueError("Raw master has no native alpha")
            image = opened.copy()
        bbox = image.getchannel("A").point(lambda p: 255 if p >= 12 else 0).getbbox()
        if not bbox or image.getchannel("A").getextrema()[0] != 0:
            raise ValueError("Invalid alpha geometry")
        crop = image.crop(bbox)
        target = tuple(asset["runtime"]["size"])
        fitted_size = (target[0] - 8, target[1] - 8)
        paper_split = None
        if asset["id"] == "vertical_botanical_card":
            # Locate the actual generated quiet paper band, then fit the two
            # regions to native text slots. The model is not a layout authority.
            pixels = np.array(crop.convert("RGB"), dtype=np.float32)
            middle = pixels[:, crop.width // 4:crop.width * 3 // 4]
            median = np.median(middle, axis=1)
            paper_rows = (median[:, 0] > 110) & (median[:, 0] > median[:, 2] * 1.1)
            candidates = np.flatnonzero(paper_rows & (np.arange(crop.height) > crop.height * .3))
            if not len(candidates):
                raise ValueError("Generated card has no identifiable quiet paper band")
            paper_split = int(candidates[0])
            desired_split = int(asset["runtime"]["slots"]["paper"][1]) - 4
            fitted = Image.new("RGBA", fitted_size)
            upper = nine_slice(crop.crop((0, 0, crop.width, paper_split)), (fitted_size[0], desired_split))
            lower = nine_slice(crop.crop((0, paper_split, crop.width, crop.height)), (fitted_size[0], fitted_size[1] - desired_split))
            fitted.alpha_composite(upper, (0, 0))
            fitted.alpha_composite(lower, (0, desired_split))
        else:
            fitted = nine_slice(crop, fitted_size)
        master = Image.new("RGBA", target)
        master.alpha_composite(fitted, (4, 4))
        master = clean_alpha(master)
        runtime = asset["runtime"]
        images = {}
        if "path_pattern" in runtime:
            for state in asset["states"]:
                brightness, saturation = {"normal": (1., 1.), "hover": (1.08, 1.), "pressed": (.82, .9), "disabled": (.57, .25)}[state]
                colored = ImageEnhance.Color(master.convert("RGB")).enhance(saturation)
                colored = ImageEnhance.Brightness(colored).enhance(brightness).convert("RGBA")
                colored.putalpha(master.getchannel("A"))
                images[project_path(runtime["path_pattern"].replace("{state}", state))] = clean_alpha(colored)
        else:
            images[project_path(runtime["path"])] = master
        hashes = {hashlib.sha256(item.getchannel("A").tobytes()).hexdigest() for item in images.values()}
        if len(hashes) != 1:
            raise ValueError("State alpha silhouette mismatch")
        for path, item in images.items():
            if check:
                if not path.exists() or Image.open(path).convert("RGBA").tobytes() != item.tobytes():
                    raise ValueError(f"Stale runtime derivative: {path.name}")
            else:
                path.parent.mkdir(parents=True, exist_ok=True)
                item.save(path, optimize=True)
        records.append({"asset_id": asset["id"], "raw": str(raw.relative_to(ROOT)),
                        "raw_sha256": hashlib.sha256(raw.read_bytes()).hexdigest(),
                        "raw_size": list(image.size), "alpha_bbox": list(bbox),
                        "source_paper_split": paper_split,
                        "runtime_size": list(target), "state_alpha_sha256": hashes.pop(),
                        "method": "native raw alpha trim; uniformly scaled corners; stretch quiet rails and center; 4px exterior padding",
                        "outputs": [str(path.relative_to(ROOT)) for path in images]})
    if missing and not available_only:
        raise ValueError("Missing verified masters: " + ", ".join(missing))
    return {"manifest": "res://art_source/manifests/battle_ui_v5.json", "complete": not missing,
            "missing_verified_masters": missing, "derivatives": records}


def navy_image(image: Image.Image) -> Image.Image:
    pixels = np.array(image.convert("RGBA"), dtype=np.uint8)
    rgb = pixels[..., :3].astype(np.float32) / 255.0
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    # Same color predicate and luminance ramp as BattlePalette.map_green_to_navy.
    bronze = (r > g * 1.07) & (g > b * 1.08)
    green = (g >= r * .90) & (g >= b * 1.02) & ~bronze & (pixels[..., 3] > 0)
    light = (.2126 * r + .7152 * g + .0722 * b)[..., None]
    dark = np.array([16, 26, 41], dtype=np.float32)
    pale = np.array([101, 119, 142], dtype=np.float32)
    mapped = np.rint(dark + (pale - dark) * light).astype(np.uint8)
    pixels[..., :3][green] = mapped[green]
    pixels[..., :3][pixels[..., 3] == 0] = 0
    return Image.fromarray(pixels, "RGBA")


def recolor_existing() -> list[dict]:
    DEST.mkdir(parents=True, exist_ok=True)
    records = []
    old = ROOT / "assets/ui/generated/battle_hud_v3"
    for filename in [*(f"primary_action_{s}.png" for s in ("normal", "hover", "pressed", "disabled")), "tactical_bezel.png"]:
        source = old / filename
        with Image.open(source) as image:
            before = np.array(image.convert("RGBA"))
            result = navy_image(image)
        after = np.array(result)
        if not np.array_equal(before[..., 3], after[..., 3]):
            raise ValueError("palette derivation changed alpha geometry")
        values = before[..., :3].astype(np.float32) / 255.0
        warm = (values[..., 0] > values[..., 1] * 1.07) & (values[..., 1] > values[..., 2] * 1.08) & (before[..., 3] > 0)
        if not np.array_equal(before[..., :3][warm], after[..., :3][warm]):
            raise ValueError("palette derivation changed warm copper pixels")
        output = DEST / filename
        result.save(output)
        records.append({"source": str(source.relative_to(ROOT)), "output": str(output.relative_to(ROOT)),
                        "size": list(result.size), "alpha_identical": True,
                        "warm_copper_identical": True, "warm_copper_pixels": int(warm.sum()),
                        "changed_rgb_pixels": int(np.any(before[..., :3] != after[..., :3], axis=2).sum())})
    return records


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--recolor-only", action="store_true")
    parser.add_argument("--available-only", action="store_true", help="Derive verified partial batch without declaring completion")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    records = recolor_existing()
    if not args.recolor_only:
        derived = derive_masters(args.available_only, args.check)
        if not args.check:
            (SOURCE / "derivation_report.json").write_text(json.dumps(derived, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print("V5 derivatives verified" if args.check else "V5 verified available derivatives written")
    SOURCE.mkdir(parents=True, exist_ok=True)
    (SOURCE / "palette_derivation_report.json").write_text(json.dumps({
        "kind": "battle-ui-v5-offline-palette-derivation", "billed_requests": 0,
        "algorithm": "BattlePalette green predicate and navy luminance ramp; warm copper preserved",
        "assets": records,
    }, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
