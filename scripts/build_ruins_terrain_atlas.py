"""Pack the sprite-gen ground and existing imported terrain sheet for Godot."""
from pathlib import Path

import numpy as np
from PIL import Image, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/tilesets"
SIZE = 160


def feather(image, width=24, strength=255):
    image = image.convert("RGBA")
    y, x = np.indices((image.height, image.width))
    edge = np.minimum.reduce([x, y, image.width - 1 - x, image.height - 1 - y])
    weight = np.clip(edge / width, 0, 1)
    weight = weight * weight * (3 - 2 * weight)
    alpha = np.asarray(image.getchannel("A"), dtype=float)
    image.putalpha(Image.fromarray((alpha * weight * strength / 255).astype("uint8")))
    return image


def matched_edges(image, width=20):
    pixels = np.asarray(image.convert("RGB"), dtype=float).copy()
    # Blend paired strips to identical outer pixels, retaining interior detail.
    for axis in (1, 0):
        pixels = np.swapaxes(pixels, 0, axis)
        for i in range(width):
            a, b = pixels[i].copy(), pixels[-1 - i].copy()
            mean = (a + b) / 2
            weight = (1 - i / width) ** 2
            pixels[i] = a * (1 - weight) + mean * weight
            pixels[-1 - i] = b * (1 - weight) + mean * weight
        pixels = np.swapaxes(pixels, 0, axis)
    return Image.fromarray(np.rint(pixels).astype("uint8"))


def build():
    source = Image.open(ROOT / "output/imagegen/tilesets/ruins-ground-source.png").convert("RGB")
    sheet = Image.open(ROOT / "art_source/generated/modular_terrain_overlay.png").convert("RGBA")
    # Painted cells have gutters; their measured bounds are not a 1254/4 grid.
    starts = [18, 329, 639, 949]
    cells = []
    acid = Image.new("RGBA", (640, 640))
    for row in range(4):
        line = []
        for col in range(4):
            x, y = starts[col], starts[row]
            tile = sheet.crop((x + 3, y + 3, x + 283, y + 283))
            tile = tile.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
            tile = feather(tile, 24) if row < 3 else tile
            line.append(tile)
            acid.paste(tile, (col * SIZE, row * SIZE))
        cells.append(line)
    acid.save(OUT / "battlefield_acid_overlay_tileset.png")

    # Sixteen boundary masks fade only exposed edges, never internal cell joins.
    joined = Image.new("RGBA", (2560, 1280))
    tile_entries = []
    for row in range(2):
        x, y = starts[0], starts[row]
        shared = matched_edges(sheet.crop((x + 3, y + 3, x + 283, y + 283)).resize((SIZE, SIZE), Image.Resampling.LANCZOS))
        for variant in range(4):
            x = starts[variant]
            detail = sheet.crop((x + 3, y + 3, x + 283, y + 283)).resize((SIZE, SIZE), Image.Resampling.LANCZOS)
            tile = shared.convert("RGBA")
            tile.alpha_composite(feather(detail, 32, 220))
            for mask in range(16):
                yy, xx = np.indices((SIZE, SIZE))
                weight = np.ones((SIZE, SIZE))
                for flag, distance in ((1, yy), (2, SIZE - 1 - xx), (4, SIZE - 1 - yy), (8, xx)):
                    if mask & flag:
                        weight = np.minimum(weight, np.clip(distance / 24, 0, 1))
                weight = weight * weight * (3 - 2 * weight)
                masked = tile.copy()
                masked.putalpha(Image.fromarray((255 * weight).astype("uint8")))
                col, atlas_row = variant * 4 + mask % 4, row * 4 + mask // 4
                joined.paste(masked, (col * SIZE, atlas_row * SIZE))
                tile_entries.append(f"{col}:{atlas_row}/0 = 0")
    joined.save(OUT / "battlefield_acid_joined_tileset.png")
    resource = '''[gd_resource type="TileSet" load_steps=5 format=3]

[ext_resource type="Texture2D" path="res://assets/tilesets/battlefield_acid_overlay_tileset.png" id="1_atlas"]
[ext_resource type="Texture2D" path="res://assets/tilesets/battlefield_acid_joined_tileset.png" id="2_joined"]

[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_acid"]
texture = ExtResource("1_atlas")
texture_region_size = Vector2i(160, 160)
'''
    resource += "\n".join(f"{x}:{y}/0 = 0" for y in range(4) for x in range(4))
    resource += '''

[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_joined"]
texture = ExtResource("2_joined")
texture_region_size = Vector2i(160, 160)
'''
    resource += "\n".join(tile_entries)
    resource += '''

[resource]
tile_size = Vector2i(160, 160)
physics_layer_0/collision_layer = 0
sources/0 = SubResource("TileSetAtlasSource_acid")
sources/1 = SubResource("TileSetAtlasSource_joined")
'''
    (OUT / "BattlefieldAcidOverlayTileSet.tres").write_text(resource, encoding="utf-8")

    # Use the open center of the rust material as a quiet, continuous foundation.
    calm_source = Image.open(ROOT / "output/imagegen/tilesets/ruins-rust-source.png").convert("RGB")
    w, h = calm_source.size
    calm = calm_source.crop((int(w * 0.32), int(h * 0.22), int(w * 0.68), int(h * 0.58)))
    calm = calm.resize((SIZE, SIZE), Image.Resampling.LANCZOS).filter(ImageFilter.GaussianBlur(0.6))
    calm = ImageEnhance.Contrast(calm).enhance(0.75)
    base = matched_edges(calm)
    ground = Image.new("RGBA", (1280, 320))
    for i in range(5):
        # All variants share the same boundary, avoiding seams between variants.
        x, y = (i * 173) % 700, (i * 257) % 700
        variant = calm.rotate(i * 90)
        patch = feather(variant, 38, 60)
        tile = base.convert("RGBA")
        tile.alpha_composite(patch)
        ground.paste(tile, (i * SIZE, 0))
    for i in range(3):
        ground.paste(cells[1][i], (i * SIZE, SIZE))
    ground.save(OUT / "battlefield_ground_ruins_spritegen.png")

    families = [Image.open(ROOT / f"output/imagegen/tilesets/ruins-{name}-source.png").convert("RGB")
                for name in ("concrete", "overgrowth", "rust")]
    macro = Image.new("RGBA", (7680, 640))
    yy, xx = np.indices((640, 640))
    for i in range(12):
        material = families[i // 4]
        width, height = material.size
        x, y = (i % 2) * (width - 700), ((i % 4) // 2) * (height - 700)
        tile = material.crop((x, y, x + 700, y + 700)).resize((640, 640), Image.Resampling.LANCZOS)
        tile = ImageEnhance.Brightness(tile).enhance(0.88 if i // 4 == 0 else 0.95).convert("RGBA")
        # Irregular rounded islands hide the macro cell grid and preserve quiet gaps.
        nx, ny = (xx - 320) / 310, (yy - 320) / 310
        radius = np.sqrt(nx * nx + ny * ny)
        angle = np.arctan2(ny, nx)
        boundary = 0.84 + 0.10 * np.sin(angle * 3 + i) + 0.06 * np.cos(angle * 5 - i)
        weight = np.clip((boundary - radius) / 0.25, 0, 1)
        weight = weight * weight * (3 - 2 * weight)
        tile.putalpha(Image.fromarray((weight * 165).astype("uint8")).filter(ImageFilter.GaussianBlur(5)))
        macro.paste(tile, (i * 640, 0))
    macro.save(OUT / "battlefield_macro_ruins_spritegen.png")
    print("Built ground 1280x320, twelve macro materials 7680x640, acid overlay 640x640")


if __name__ == "__main__":
    build()
