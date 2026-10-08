from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art_source"
ASSETS = ROOT / "assets"


def ensure_dirs() -> None:
    for name in ("backgrounds", "core", "plants", "enemies", "nodes", "effects", "ui"):
        (ASSETS / name).mkdir(parents=True, exist_ok=True)


def clean_alpha(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            if a < 48:
                pixels[x, y] = (0, 0, 0, 0)
            elif a < 112:
                na = int((a - 48) / 64 * 112)
                pixels[x, y] = (r, g, b, na)
    return rgba


def alpha_bbox(image: Image.Image):
    return image.getchannel("A").getbbox()


def fit_transparent(image: Image.Image, size: tuple[int, int], margin: int, anchor_y: float = 0.92) -> Image.Image:
    image = clean_alpha(image)
    bbox = alpha_bbox(image)
    if bbox:
        image = image.crop(bbox)
    max_w = size[0] - margin * 2
    max_h = size[1] - margin * 2
    scale = min(max_w / image.width, max_h / image.height)
    resized = image.resize((max(1, round(image.width * scale)), max(1, round(image.height * scale))), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    x = (size[0] - resized.width) // 2
    ground_y = round(size[1] * anchor_y)
    y = min(size[1] - resized.height, ground_y - resized.height)
    y = max(0, y)
    canvas.alpha_composite(resized, (x, y))
    return canvas


def crop_grid(source: Image.Image, columns: int, rows: int, col: int, row: int) -> Image.Image:
    x0 = round(source.width * col / columns)
    x1 = round(source.width * (col + 1) / columns)
    y0 = round(source.height * row / rows)
    y1 = round(source.height * (row + 1) / rows)
    return source.crop((x0, y0, x1, y1))


def save(image: Image.Image, relative: str) -> None:
    path = ASSETS / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, "PNG", optimize=True)


def process_background() -> None:
    bg = Image.open(SOURCE / "background_draft.png").convert("RGB")
    bg = bg.resize((1152, 648), Image.Resampling.LANCZOS)
    save(bg.convert("RGBA"), "backgrounds/ART_BG_GreenhouseGarden_Base.png")

    # Reuse the painterly edge detail as a soft foreground frame while keeping the battlefield clear.
    rgba = bg.convert("RGBA").filter(ImageFilter.GaussianBlur(1.2))
    mask = Image.new("L", rgba.size, 0)
    mp = mask.load()
    for y in range(mask.height):
        for x in range(mask.width):
            edge = min(x, y, mask.width - 1 - x, mask.height - 1 - y)
            alpha = max(0, min(135, int((115 - edge) * 1.2)))
            mp[x, y] = alpha
    rgba.putalpha(mask.filter(ImageFilter.GaussianBlur(18)))
    save(rgba, "backgrounds/ART_FG_GreenhouseMist.png")


def process_mother() -> None:
    sheet = Image.open(SOURCE / "mother_sheet.png").convert("RGBA")
    names = ("Healthy", "Damaged", "Critical")
    for col, name in enumerate(names):
        cell = crop_grid(sheet, 3, 1, col, 0)
        save(fit_transparent(cell, (256, 256), 7, 0.96), f"core/ART_CORE_MotherFlower_{name}.png")


def process_actors() -> None:
    sheet = Image.open(SOURCE / "actor_sheet.png").convert("RGBA")
    entries = [
        (0, 0, (160, 160), "plants/ART_PLANT_ThornFlower_Powered.png"),
        (1, 0, (160, 160), "plants/ART_PLANT_ThornFlower_Unpowered.png"),
        (2, 0, (160, 160), "plants/ART_PLANT_PrismFlower_Powered.png"),
        (3, 0, (160, 160), "plants/ART_PLANT_PrismFlower_Unpowered.png"),
        (0, 1, (192, 160), "enemies/ART_ENEMY_ShadowBeast_Move.png"),
        (1, 1, (192, 160), "enemies/ART_ENEMY_ShadowBeast_Attack.png"),
        (2, 1, (160, 128), "enemies/ART_ENEMY_ErosionBug_Move.png"),
        (3, 1, (160, 128), "enemies/ART_ENEMY_ErosionBug_Attack.png"),
    ]
    for col, row, size, path in entries:
        cell = crop_grid(sheet, 4, 2, col, row)
        save(fit_transparent(cell, size, 5, 0.93), path)


def process_nodes() -> None:
    sheet = Image.open(SOURCE / "node_sheet.png").convert("RGBA")
    for col, name in enumerate(("Healthy", "Damaged", "Broken")):
        cell = crop_grid(sheet, 3, 1, col, 0)
        save(fit_transparent(cell, (96, 96), 3, 0.96), f"nodes/ART_NODE_LightBud_{name}.png")


def process_effects() -> None:
    sheet = Image.open(SOURCE / "effect_sheet.png").convert("RGBA")
    entries = [
        (0, (64, 32), "effects/ART_VFX_PrismProjectile.png", 0.72),
        (1, (512, 512), "effects/ART_VFX_Sunburst_Ring.png", 0.5),
        (2, (192, 192), "effects/ART_VFX_ShadowDissolve.png", 0.82),
    ]
    for col, size, path, anchor in entries:
        cell = crop_grid(sheet, 3, 1, col, 0)
        save(fit_transparent(cell, size, 2, anchor), path)


def crop_resize(sheet: Image.Image, box: tuple[int, int, int, int], size: tuple[int, int]) -> Image.Image:
    return sheet.crop(box).resize(size, Image.Resampling.LANCZOS).convert("RGBA")


def crop_half(sheet: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
    cropped = sheet.crop(box).convert("RGBA")
    size = ((cropped.width + 1) // 2, (cropped.height + 1) // 2)
    return cropped.resize(size, Image.Resampling.LANCZOS)


def build_ui_preview() -> None:
    canvas = Image.new("RGB", (1200, 760), (13, 18, 28))
    draw = ImageDraw.Draw(canvas)
    draw.text((28, 18), "UI CROP CONTRACT - 2026-09-24", fill=(255, 232, 166))
    items = [
        ("Top panel", "UI_PANEL_TopBar.png", (28, 52), (1144, 156)),
        ("Action panel", "UI_PANEL_ActionBar.png", (28, 190), (1144, 131)),
        ("Normal", "UI_BUTTON_Normal.png", (28, 354), None),
        ("Hover", "UI_BUTTON_Hover.png", (236, 354), None),
        ("Pressed", "UI_BUTTON_Pressed.png", (446, 354), None),
        ("Disabled", "UI_BUTTON_Disabled.png", (654, 354), None),
        ("Thorn", "UI_ICON_ThornFlower.png", (28, 470), None),
        ("Prism", "UI_ICON_PrismFlower.png", (188, 470), None),
        ("Sunburst", "UI_ICON_Sunburst.png", (348, 470), None),
        ("Repair", "UI_ICON_Repair.png", (508, 470), None),
        ("Health fill", "UI_BAR_Health.png", (710, 490), (430, 54)),
        ("Energy fill", "UI_BAR_Energy.png", (710, 570), (430, 54)),
        ("Result panel", "UI_PANEL_Result.png", (710, 650), (430, 82)),
    ]
    for label, filename, position, preview_size in items:
        asset = Image.open(ASSETS / "ui" / filename).convert("RGBA")
        if preview_size is not None:
            asset.thumbnail(preview_size, Image.Resampling.LANCZOS)
        canvas.paste(asset.convert("RGB"), position)
        draw.text((position[0], position[1] - 18), label, fill=(218, 220, 224))
    canvas.save(SOURCE / "ui_crop_preview.png", "PNG", optimize=True)


def build_result_panel(action: Image.Image) -> Image.Image:
    width, height = 512, 256
    corner_w, corner_h = 150, 44
    result = action.crop((220, 20, 556, 69)).resize((width, height), Image.Resampling.LANCZOS)
    center_w = width - corner_w * 2
    center_h = height - corner_h * 2
    result.alpha_composite(action.crop((0, 0, corner_w, corner_h)), (0, 0))
    result.alpha_composite(action.crop((action.width - corner_w, 0, action.width, corner_h)), (width - corner_w, 0))
    result.alpha_composite(action.crop((0, action.height - corner_h, corner_w, action.height)), (0, height - corner_h))
    result.alpha_composite(action.crop((action.width - corner_w, action.height - corner_h, action.width, action.height)), (width - corner_w, height - corner_h))
    top_edge = action.crop((corner_w, 0, action.width - corner_w, 18)).resize((center_w, 18), Image.Resampling.LANCZOS)
    bottom_edge = action.crop((corner_w, action.height - 18, action.width - corner_w, action.height)).resize((center_w, 18), Image.Resampling.LANCZOS)
    left_edge = action.crop((0, corner_h, 10, action.height - corner_h)).resize((10, center_h), Image.Resampling.LANCZOS)
    right_edge = action.crop((action.width - 10, corner_h, action.width, action.height - corner_h)).resize((10, center_h), Image.Resampling.LANCZOS)
    result.alpha_composite(top_edge, (corner_w, 0))
    result.alpha_composite(bottom_edge, (corner_w, height - 18))
    result.alpha_composite(left_edge, (0, corner_h))
    result.alpha_composite(right_edge, (width - 10, corner_h))
    return result


def process_ui() -> None:
    sheet = Image.open(SOURCE / "ui_sheet.png").convert("RGBA")
    if sheet.size != (1672, 940):
        raise ValueError(f"unexpected UI sheet size: {sheet.size}; expected 1672x940")
    save(crop_half(sheet, (60, 50, 1612, 261)), "ui/UI_PANEL_TopBar.png")
    action_panel = crop_half(sheet, (60, 286, 1612, 464))
    save(action_panel, "ui/UI_PANEL_ActionBar.png")
    save(build_result_panel(action_panel), "ui/UI_PANEL_Result.png")
    button_boxes = {
        "Normal": (60, 493, 406, 610),
        "Hover": (456, 493, 805, 610),
        "Pressed": (865, 493, 1210, 610),
        "Disabled": (1264, 493, 1612, 610),
    }
    for name, box in button_boxes.items():
        save(crop_half(sheet, box), f"ui/UI_BUTTON_{name}.png")
    icon_boxes = {
        "ThornFlower": (56, 656, 256, 856),
        "PrismFlower": (286, 656, 486, 856),
        "Sunburst": (516, 656, 716, 856),
        "Repair": (747, 656, 947, 856),
    }
    for name, box in icon_boxes.items():
        save(crop_resize(sheet, box, (128, 128)), f"ui/UI_ICON_{name}.png")
    # Keep only the clean luminous center strips. The medallions and leaf caps must
    # never enter a ProgressBar fill because percentage clipping would distort them.
    save(crop_resize(sheet, (1110, 688, 1438, 744), (256, 32)), "ui/UI_BAR_Health.png")
    save(crop_resize(sheet, (1106, 798, 1404, 842), (256, 32)), "ui/UI_BAR_Energy.png")
    build_ui_preview()


def main() -> None:
    ensure_dirs()
    process_background()
    process_mother()
    process_actors()
    process_nodes()
    process_effects()
    process_ui()
    print("processed formal art assets")


if __name__ == "__main__":
    main()
