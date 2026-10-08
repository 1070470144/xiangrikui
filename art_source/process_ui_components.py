from pathlib import Path
from PIL import Image, ImageDraw
from collections import deque

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art_source" / "generated"
OUT = ROOT / "assets" / "ui" / "generated"
PREVIEW = ROOT / "art_source" / "ui_components_preview.png"

def crop_grid(path: Path, cols: int, rows: int):
    image = Image.open(path).convert("RGBA")
    cells = []
    for row in range(rows):
        for col in range(cols):
            box = (round(image.width * col / cols), round(image.height * row / rows),
                   round(image.width * (col + 1) / cols), round(image.height * (row + 1) / rows))
            cell = image.crop(box)
            if path.name == "ui_components_frames.png":
                px = cell.load()
                seen = set()
                queue = deque()
                for x in range(cell.width):
                    queue.extend(((x, 0), (x, cell.height - 1)))
                for y in range(cell.height):
                    queue.extend(((0, y), (cell.width - 1, y)))
                while queue:
                    x, y = queue.popleft()
                    if (x, y) in seen or not (0 <= x < cell.width and 0 <= y < cell.height):
                        continue
                    seen.add((x, y))
                    r, g, b, a = px[x, y]
                    if max(r, g, b) > 18:
                        continue
                    px[x, y] = (0, 0, 0, 0)
                    queue.extend(((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)))
            alpha = cell.getchannel("A")
            bbox = alpha.getbbox()
            if bbox:
                cell = cell.crop(bbox)
            cells.append(cell)
    return cells

def crop_items(path: Path, boxes, checker=False):
    source = Image.open(path).convert("RGBA")
    result = []
    for box in boxes:
        cell = source.crop(box)
        if checker:
            pixels = cell.load()
            for y in range(cell.height):
                for x in range(cell.width):
                    r, g, b, _ = pixels[x, y]
                    if min(r, g, b) >= 175 and max(r, g, b) - min(r, g, b) <= 8:
                        pixels[x, y] = (0, 0, 0, 0)
        result.append(cell)
    return result

def fit(cell: Image.Image, size, margin=12):
    cell = cell.convert("RGBA")
    scale = min((size[0] - margin * 2) / max(1, cell.width), (size[1] - margin * 2) / max(1, cell.height))
    resized = cell.resize((max(1, round(cell.width * scale)), max(1, round(cell.height * scale))), Image.Resampling.LANCZOS)
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    out.alpha_composite(resized, ((size[0] - resized.width) // 2, (size[1] - resized.height) // 2))
    return out

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    frames = crop_items(SOURCE / "ui_components_frames.png", [
        (0, 289, 315, 515), (315, 292, 635, 515),
        (623, 344, 947, 515), (930, 332, 1254, 515),
        (0, 700, 316, 855), (315, 697, 620, 855),
        (620, 612, 878, 930), (878, 602, 1254, 930),
    ])
    frame_names = ["Panel_Top", "Panel_Action", "Button_Normal", "Button_Hover", "Button_Pressed", "Button_Disabled", "Card", "Modal"]
    frame_sizes = [(320, 96), (320, 96), (240, 72), (240, 72), (240, 72), (240, 72), (280, 180), (360, 240)]
    exported = []
    for name, cell, size in zip(frame_names, frames, frame_sizes):
        path = OUT / f"UI_{name}.png"
        fit(cell, size).save(path, "PNG", optimize=True)
        exported.append((path, fit(cell, size)))
    icons = crop_items(SOURCE / "ui_components_icons.png", [
        (42, 266, 609, 472), (666, 266, 1222, 472),
        (100, 530, 568, 702), (673, 530, 1160, 702),
        (44, 748, 350, 1060), (343, 748, 646, 1060),
        (665, 747, 910, 1060), (914, 747, 1200, 1060),
    ], checker=True)
    icon_names = ["Bar_Health", "Bar_Energy", "Tab_Selected", "Tab_Normal", "Status_Healthy", "Status_Warning", "Status_Corrupted", "Marker_Threat"]
    icon_sizes = [(320, 48), (320, 48), (180, 56), (180, 56), (96, 96), (96, 96), (96, 96), (96, 96)]
    for name, cell, size in zip(icon_names, icons, icon_sizes):
        image = fit(cell, size, 8)
        path = OUT / f"UI_{name}.png"
        image.save(path, "PNG", optimize=True)
        exported.append((path, image))
    preview = Image.new("RGBA", (900, 760), (17, 24, 39, 255))
    draw = ImageDraw.Draw(preview)
    x = y = 20
    for path, image in exported:
        if x + image.width > 880:
            x = 20; y += 120
        preview.alpha_composite(image, (x, y))
        draw.text((x, y + image.height + 4), path.stem, fill=(255, 240, 176, 255))
        x += image.width + 24
    preview.convert("RGB").save(PREVIEW, "PNG")

if __name__ == "__main__":
    main()
