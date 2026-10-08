"""Generate approved A-F main-menu art via sprite-gen mm-api.

Run from the Godot project root with sprite-gen's virtualenv Python.
"""
from __future__ import annotations

import concurrent.futures
import json
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art_source/generated/mm_tools/01_main_menu"
SOURCE = OUT / "source"
STYLE = (
    "Art for The Last Sunflower, a dark fantasy greenhouse survival game. "
    "Sophisticated hand-painted botanical storybook style, visible oil-brush texture, "
    "oxidized antique gold, ink-green foliage, cool midnight glass and warm sunflower light. "
    "Match the supplied main menu concept: restrained antique horticultural journal, "
    "clear silhouette, precisely centered isolated asset. No letters, numbers, words, UI screenshot, "
    "watermark, checkerboard, or multiple alternatives."
)

# Group, identifier, final pixel size, opaque, isolated subject description.
ITEMS = [
    ("A", "main_menu_greenhouse_background", (1920, 1080), True, "Wide empty night greenhouse environment, broken glass roof, blue moonlight, cold distant fog. Dramatic vacant left-center clearing for a separate mother-flower character and quiet dark right third for a separate menu panel. No flower heroine, no UI or lettering."),
    ("A", "main_menu_mother_flower", (900, 1100), False, "Full-body majestic living mother sunflower with a gentle almost human face and botanical roots, golden petals and intricate dark leaves, a warm luminous core, three-quarter view, one standalone figure. No scenery."),
    ("A", "main_menu_mother_flower_glow", (900, 1100), False, "Only the soft amber luminous halo and thin bloom highlights corresponding to a tall sunflower silhouette, sparse warm particles, no solid figure or dark background. Isolated light overlay."),
    ("A", "main_menu_light_vines", (1600, 900), False, "A few delicate branching golden living root-light filaments running along the lower left and bottom, sparse and elegant, isolated light effect with much empty transparent space."),
    ("A", "main_menu_light_particles", (1024, 1024), False, "A sparse cluster of tiny warm golden firefly sparks and floating pollen motes, varied size, isolated particle layer, no bloom filling the canvas."),
    ("A", "main_menu_cold_mist", (1920, 1080), False, "Thin translucent cold blue-gray greenhouse mist wisps concentrated along outer edges, mostly empty center, isolated fog overlay."),
    ("A", "main_menu_moon", (512, 512), False, "One small luminous full moon with restrained cool silver-blue rim and subtle crater texture, centered isolated circular celestial disc."),
    ("B", "menu_record_panel", (720, 1200), False, "Tall narrow antique horticultural journal menu panel, thin oxidized gold botanical border and deep dark green inner surface, precise unbroken rectangular frame, no controls or inscriptions."),
    ("B", "menu_record_panel_subpage", (900, 620), False, "Wide landscape antique botanical journal subpage frame, muted dark parchment inner field, delicate gold botanical trim, symmetric rectangular composition, no controls or text."),
    ("B", "menu_panel_shadow", (900, 1300), False, "Only a soft dark ambient rectangular drop-shadow for a tall menu panel, no visible frame, transparent outer edge."),
    ("B", "menu_panel_inner_texture", (1024, 1024), False, "Subtle seamless-looking aged dark ink-green paper and lightly oxidized metal surface texture, fine fibers and understated patina, no borders or symbols."),
    ("B", "menu_botanical_border", (720, 1200), False, "Only a tall rectangular fine antique-gold botanical frame: clean straight edges, small leaf engravings and precise corners, hollow center, no filled panel."),
    ("B", "menu_corner_ornament", (180, 180), False, "One delicate antique-gold engraved corner flourish with tiny leaves and sunflower seed motif for upper-left corner of a rectangular journal panel, no frame or backdrop."),
    ("B", "menu_divider_gold", (720, 32), False, "One very thin horizontal antique-gold ornamental rule with subtle botanical tips, centered and spanning the width, no text."),
    ("B", "menu_overlay_dim", (1920, 1080), False, "Subtle translucent blue-black vignette overlay, dark outer edges and lighter open center, no objects or text."),
    ("C", "gardener_badge_frame", (420, 110), False, "Slim horizontal gardener nameplate, antique bronze and fine gold border, dark green hollow-looking center for separately rendered player name, small framed emblem well on left, no text or emblem."),
    ("C", "gardener_badge_emblem", (96, 96), False, "Single small antique golden sunflower emblem for a gardener insignia, clear tiny silhouette, no border."),
    ("C", "gardener_avatar", (80, 80), False, "One tiny icon portrait of a hooded greenhouse gardener, antique hand-painted ink and gold, simple high contrast head and shoulders, no frame."),
    ("C", "gardener_avatar_background", (96, 96), False, "A small round engraved aged-gold medallion backing for a separate gardener avatar, dark green empty center, no portrait."),
    ("C", "gardener_badge_status_dot", (24, 24), False, "A single tiny warm golden status light dot with subtle halo, no label or background."),
    ("D", "menu_button_primary_frame", (650, 118), False, "Long wide primary menu button frame: dark ink-green center, luminous old-gold narrow double-line botanical border, ornate but restrained square corners, empty middle, no icons."),
    ("D", "menu_button_primary_hover", (650, 118), False, "Only a long horizontal golden rim-light highlight overlay for the primary button, hollow center and no solid panel."),
    ("D", "menu_button_primary_pressed", (650, 118), False, "Long horizontal primary button pressed state, deep dark green face and tightened subdued gold engraved border, no text or icon."),
    ("D", "menu_button_secondary_frame", (650, 86), False, "Long flat secondary menu row, near-black ink-green center and a hairline oxidized-gold lower edge, restrained antique botanical style, no icon or text."),
    ("D", "menu_button_secondary_hover", (650, 86), False, "Only a restrained warm-gold edge glow for a long secondary menu row, mostly transparent hollow center, no text."),
    ("D", "menu_button_secondary_pressed", (650, 86), False, "Long flat secondary menu row pressed state, muted dark bronze-green face and thin gold lower edge, no icon or text."),
    ("D", "menu_button_focus_frame", (680, 110), False, "Only a crisp thin golden rectangular keyboard focus outline for a long menu button, transparent hollow center, no text."),
    ("D", "menu_button_arrow", (48, 48), False, "One delicate right-pointing antique-gold chevron arrow, tiny UI icon, no button plate."),
    ("D", "menu_button_separator", (600, 8), False, "One very thin subdued oxidized-gold horizontal separator line, faint floral flourish at ends, no text."),
    ("E", "icon_continue_night", (72, 72), False, "One gold sunflower seedling sprouting toward a small star, iconic high-contrast silhouette for continue game."),
    ("E", "icon_deck_config", (72, 72), False, "Three overlapping old botanical specimen cards outlined in gold, compact icon for deck configuration, no writing."),
    ("E", "icon_night_records", (72, 72), False, "One open antique field journal with a small crescent moon glyph, gold-ink compact icon for night records, no writing."),
    ("E", "icon_greenhouse_codex", (72, 72), False, "A tiny sunflower specimen hovering above an open botanical encyclopedia, gold-ink compact icon for greenhouse codex, no writing."),
    ("E", "icon_settings", (72, 72), False, "One precise antique brass gear with a subtle leaf-shaped inner hub, compact settings icon, no writing."),
    ("E", "icon_exit_game", (72, 72), False, "One minimal antique greenhouse door ajar with a rightward exit arrow, fine gold-ink compact icon, no writing."),
    ("F", "save_summary_frame", (650, 150), False, "Horizontal old botanical ledger summary card with delicate gold corner border and dark ink-green empty center, no flower, progress bar or writing."),
    ("F", "save_summary_flower_icon", (92, 92), False, "One small aged golden sunflower specimen with stem and leaves, high contrast emblem for a save progress card, no frame."),
    ("F", "save_summary_progress_track", (470, 26), False, "Long narrow recessed dark bronze progress bar track with fine gold edge, empty inside, no fill or labels."),
    ("F", "save_summary_progress_fill", (470, 26), False, "Long narrow horizontal warm amber-gold progress bar fill with gentle organic luminous texture, no surrounding track or label."),
    ("F", "save_summary_warning_mark", (48, 48), False, "One tiny antique brass warning sigil shaped like a rain-damaged leaf in a pointed diamond, compact icon, no text or backing plate."),
]


def fit_horizontal_ui(source: Image.Image, size: tuple[int, int]) -> Image.Image:
    """Preserve engraved endcaps while extending the plain central span."""
    target_width, target_height = (int(size[0] * 0.9), int(size[1] * 0.9))
    scaled = source.resize((max(1, round(source.width * target_height / source.height)), target_height), Image.Resampling.LANCZOS)
    if scaled.width >= target_width:
        return scaled.resize((target_width, target_height), Image.Resampling.LANCZOS)
    cap = min(scaled.width // 4, target_width // 4)
    center = scaled.crop((cap, 0, scaled.width - cap, target_height))
    middle_width = target_width - 2 * cap
    stretched = center.resize((middle_width, target_height), Image.Resampling.LANCZOS)
    result = Image.new("RGBA", (target_width, target_height))
    result.alpha_composite(scaled.crop((0, 0, cap, target_height)), (0, 0))
    result.alpha_composite(stretched, (cap, 0))
    result.alpha_composite(scaled.crop((scaled.width - cap, 0, scaled.width, target_height)), (cap + middle_width, 0))
    return result


def generate(item: tuple[str, str, tuple[int, int], bool, str]) -> dict:
    group, name, size, opaque, subject = item
    final = OUT / f"{name}.png"
    source = SOURCE / f"{name}.png"
    report = SOURCE / f"{name}.report.json"
    if final.exists() and "--reprocess" not in sys.argv:
        return {"id": name, "status": "existing", "group": group}
    if source.exists() != report.exists():
        return {"id": name, "status": "incomplete source/report pair", "group": group}
    if not source.exists():
        prompt = f"{STYLE} {subject} " + (
            "Opaque complete environment image, fill entire canvas edge to edge." if opaque else
            "True transparent PNG alpha surrounding the isolated asset; generous clean margin, no solid background."
        )
        command = [sys.executable, "-m", "sprite_gen.cli", "gen", "--provider", "mm-api", "--model", "gpt-image-2", "--prompt", prompt, "--out", str(source), "--report", str(report)]
        if not opaque:
            command.append("--transparent")
        completed = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=240)
        if completed.returncode:
            return {"id": name, "status": "generation failed", "detail": completed.stderr[-500:], "group": group}
    try:
        with Image.open(source) as image:
            image.load()
            if opaque:
                result = ImageOps.fit(image.convert("RGB"), size, method=Image.Resampling.LANCZOS)
            else:
                rgba = image.convert("RGBA")
                alpha = rgba.getchannel("A")
                if alpha.getextrema()[0] != 0:
                    raise ValueError("no transparent pixels")
                bounds = alpha.getbbox()
                if bounds is None:
                    raise ValueError("empty image")
                cropped = rgba.crop(bounds)
                target = (max(1, int(size[0] * 0.9)), max(1, int(size[1] * 0.9)))
                if size[0] / size[1] >= 2.5 and name != "main_menu_light_vines":
                    cropped = fit_horizontal_ui(cropped, size)
                else:
                    cropped.thumbnail(target, Image.Resampling.LANCZOS)
                result = Image.new("RGBA", size, (0, 0, 0, 0))
                result.alpha_composite(cropped, ((size[0] - cropped.width) // 2, (size[1] - cropped.height) // 2))
            result.save(final)
        return {"id": name, "status": "ok", "group": group, "size": list(size), "source": str(source.relative_to(ROOT))}
    except Exception as exc:
        return {"id": name, "status": "postprocess failed", "detail": str(exc), "group": group}


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    SOURCE.mkdir(parents=True, exist_ok=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        futures = [pool.submit(generate, item) for item in ITEMS]
        results = []
        for future in concurrent.futures.as_completed(futures):
            result = future.result()
            results.append(result)
            print(f"{result['group']} {result['id']}: {result['status']}", flush=True)
    summary = {"model": "gpt-image-2", "provider": "mm-api", "assets": sorted(results, key=lambda row: row["id"])}
    (OUT / "generation-manifest.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    failed = [item for item in results if item["status"] not in {"ok", "existing"}]
    print(f"Generated/available: {len(results) - len(failed)}/{len(results)}; failures: {len(failed)}", flush=True)
    return int(bool(failed))


if __name__ == "__main__":
    raise SystemExit(main())
