"""Generate revision candidates for concept-inaccurate A-F assets."""
from __future__ import annotations

import importlib.util
import subprocess
import sys
from pathlib import Path

SPEC = importlib.util.spec_from_file_location("mm_batch", Path(__file__).with_name("generate_main_menu.py"))
batch = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(batch)
DEST = batch.OUT / "corrections"
DEST.mkdir(parents=True, exist_ok=True)
STYLE = "Hand-painted antique botanical game UI in muted gold and deep midnight green. Single isolated graphic. No text, lettering, portrait, sunflower, potted plant, archway, greenhouse building, book, human, badge, alternative designs, or scene."
CORRECTIONS = {
    "main_menu_mother_flower_glow": "ONLY a soft formless amber light bloom in a tall oval silhouette, sparse glimmer, intended as additive lighting overlay over a separate figure. Absolutely no physical object, flower, leaves or stem.",
    "main_menu_light_vines": "ONLY 4 to 6 thin branching golden light trails flowing horizontally across lower canvas like glowing veins. No solid objects, no bulbs or leaves.",
    "main_menu_light_particles": "ONLY widely scattered tiny points of warm golden light and delicate dust motes on empty transparent canvas. No large shapes, no object, no cage.",
    "main_menu_cold_mist": "ONLY translucent wisps of blue-gray fog drifting near the canvas edges, central area empty. No discernible objects or architecture.",
    "menu_record_panel": "Single tall narrow EMPTY menu panel. Flat very dark desaturated green surface, razor-thin etched oxidized-gold rectangular border, tiny restrained engravings only at four corners. Center completely blank and suitable for six lines of game controls. No illustrations inside, no flower or foliage inside.",
    "menu_panel_shadow": "ONLY an empty dark translucent vertical rectangular drop-shadow with heavily feathered edges. No objects, no frame, no decorative marks.",
    "menu_panel_inner_texture": "ONLY a flat uninterrupted swatch of very dark muted green aged parchment texture with subtle brush grain. No figures, pictures, flowers, outlines, structures or symbols.",
    "menu_overlay_dim": "ONLY translucent dark blue-black edge vignette, empty unobstructed center. No objects, figures, structures or ornaments.",
    "gardener_badge_status_dot": "ONLY a single small circular luminous gold point of light on a fully transparent empty field. No other pixels except its gentle round halo.",
    "menu_button_arrow": "ONLY one clean right-facing angular gold chevron glyph, like >, of uniform thin stroke. No object, no background or flourish.",
    "icon_exit_game": "One tiny simple golden outline icon of an open rectangular door and a right-facing arrow leaving it. Exactly these two flat shapes, no perspective illustration.",
    "save_summary_warning_mark": "One clear small golden warning symbol: simple hollow triangle enclosing a single exclamation point. No other graphics.",
}

for name, subject in CORRECTIONS.items():
    image = DEST / f"{name}.png"
    report = DEST / f"{name}.report.json"
    if image.exists():
        print(f"existing: {name}", flush=True)
        continue
    command = [sys.executable, "-m", "sprite_gen.cli", "gen", "--provider", "mm-api", "--model", "gpt-image-2", "--prompt", STYLE + " " + subject + " Return a real transparent PNG background, isolated only.", "--transparent", "--out", str(image), "--report", str(report)]
    result = subprocess.run(command, cwd=batch.ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=240)
    print(f"{name}: {'ok' if result.returncode == 0 else result.stderr[-300:]}", flush=True)
