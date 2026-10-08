"""Make a contact sheet and rough layout from the approved A-F outputs."""
from __future__ import annotations

import importlib.util
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps

SPEC = importlib.util.spec_from_file_location("mm_batch", Path(__file__).with_name("generate_main_menu.py"))
batch = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(batch)
OUT = batch.OUT
thumb_w, thumb_h = 320, 236
columns = 4
rows = (len(batch.ITEMS) + columns - 1) // columns
sheet = Image.new("RGB", (columns * thumb_w, rows * (thumb_h + 36)), "#20262b")
draw = ImageDraw.Draw(sheet)
for index, (group, name, _size, _opaque, _prompt) in enumerate(batch.ITEMS):
    image = Image.open(OUT / f"{name}.png").convert("RGBA")
    tile = Image.new("RGBA", (thumb_w, thumb_h), "#3b4545")
    contained = ImageOps.contain(image, (thumb_w - 16, thumb_h - 12))
    tile.alpha_composite(contained, ((thumb_w - contained.width) // 2, (thumb_h - contained.height) // 2))
    x, y = (index % columns) * thumb_w, (index // columns) * (thumb_h + 36)
    sheet.paste(tile.convert("RGB"), (x, y))
    draw.text((x + 8, y + thumb_h + 8), f"{group} {name}", fill="#f1e5bd")
sheet.save(OUT / "contact-sheet.jpg", quality=88)

bg = Image.open(OUT / "main_menu_greenhouse_background.png").convert("RGBA")
flower = Image.open(OUT / "main_menu_mother_flower.png").convert("RGBA")
flower.thumbnail((700, 950))
bg.alpha_composite(flower, (170, 80))
panel = Image.open(OUT / "menu_record_panel.png").convert("RGBA")
panel.thumbnail((560, 900))
bg.alpha_composite(panel, (1240, 90))
bg.convert("RGB").save(OUT / "layout-preview.jpg", quality=90)
