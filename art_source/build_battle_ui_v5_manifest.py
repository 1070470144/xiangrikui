"""Versioned V5 battle palette/card contract; builds a plan, never generates."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
baseline = "res://output/imagegen/previews/battle-hud-v4-1280x720-hud-night-runtime.png"
anchor = (
    "Project botanical greenhouse storybook UI, now midnight blue-grey glass "
    "#172331/#263449, muted warm ivory paper #cfc1a3, dark paper ink #282c33 "
    "and aged copper #b98b55. Visible restrained hand-painted brushwork, fine "
    "worn metal edges, sparse flattened botanical corner relief. Warm upper-left "
    "soft light. No olive green glass. Preserve the project's plants and brass "
    "instrument language; layout reference is only vertical collectible cards, "
    "never any other game's art or brand."
)
evidence = [
    ("art_guide", "res://Design/Sunflower-Defense-Art-Style-Guide.md", "Section 8 blue-grey instruments and worn gardening records"),
    ("accepted_manifest", "res://docs/mm-tools-battle-ui-v5-stage12.md", "V5 palette, card slots, interaction and explicit two-master scope"),
    ("runtime_screenshot", baseline, "Actual V4 night baseline and preserved battlefield boundaries"),
    ("runtime_screenshot", "res://tmp/battle-ui-v5-layout/1280x720-hud-night-runtime.png", "Actual V5 navy/ivory vertical-card fallback and bound recolored instrument before generation"),
    ("runtime_asset", "res://assets/ui/generated/battle_hud_v3/primary_action_normal.png", "Preserved botanical copper painting; deterministic navy derivation"),
    ("runtime_asset", "res://assets/ui/generated/battle_hud_v3/tactical_bezel.png", "Preserved instrument silhouette and transparent opening"),
    ("runtime_asset", "res://assets/core/ART_CORE_MotherFlower_Healthy.png", "Warm focal-point portrait and existing sun-card illustration"),
    ("runtime_asset", "res://assets/nodes/ART_NODE_LightBud_Healthy.png", "Existing root/light specimen silhouette on deployment and healing cards"),
    ("runtime_asset", "res://assets/plants/ART_PLANT_ThornFlower_Powered.png", "Existing root-action botanical illustration"),
    ("runtime_asset", "res://assets/plants/ART_PLANT_PrismFlower_Powered.png", "Existing piercing-action botanical illustration"),
    ("runtime_asset", "res://assets/ui/UI_ICON_Repair.png", "Repair illustration distinct from deployment; reuse existing asset"),
    ("external_reference", "https://playhearthstone.com/en-us/", "Layout/interaction only: vertical illustration, cost and effect hierarchy, overlapping hand; fetched official page archived tmp/battle-ui-v5-research/Hearthstone.html; no brand/art/style copying"),
    ("external_reference", "https://store.steampowered.com/app/646570/Slay_the_Spire/", "Layout only: readable energy cost and short effect description in collectible combat cards; fetched mature-game page archived tmp/battle-ui-v5-research/Slay_the_Spire.html; no art authority"),
]
assets = []
for asset_id, kind, source_size, display, safe, role, layout, bindings in [
    ("navy_status_frame", "panel", [768, 256], [304, 88], [18, 12, 18, 12],
     "Shared battle mother-health, phase and resource instrument readout", 
     "One horizontal 3:1 rounded instrument frame. Midnight navy-blue painted glass, "
     "fine old copper edge and corner leaf embossing only in outer 8 percent. "
     "Central 84 percent quiet uninterrupted navy for warm native text. No portrait, "
     "badge, paper, dial, icon or blue glow.",
     [{"node": n, "property": "theme_override_styles/panel"} for n in ("MotherStatusPanel", "PhaseBanner", "ResourcePanel")]),
    ("vertical_botanical_card", "button", [768, 1024], [142, 218], [12, 10, 12, 8],
     "Vertical collectible botanical card framing existing plant art and native effect description",
     "One vertical card with aspect 142:218, old copper fine border, small leaf "
     "corner clasps, upper exactly 55.5 percent midnight-navy illustration and title zone, "
     "lower exactly 44.5 percent muted warm ivory parchment record area. The single "
     "paper upper boundary is exactly 121/218 of the card silhouette height, not 60 percent. Illustration "
     "window is quiet and empty. At runtime cost gem left top 33px, art x12 y28 "
     "w118 h68, title y98-121; paper y121 height85, description x12 y126-199. "
     "Place the sole thin separator at y121/218, never across these text slots. "
     "No pre-drawn gem, circle, mana mark, cost, plant, icon, text or ornamental "
     "centerpiece. Straight-on 2D card, no perspective or tilted view.",
     [{"scope": "component", "node": ".", "property_map": {s: "theme_override_styles/" + s for s in ("normal", "hover", "pressed", "disabled")}}]),
]:
    prompt = (
        f"1. Game asset use: {role}.\n"
        f"2. Runtime contract: source {source_size}, runtime {display}; safe margins {safe}. "
        "Fill canvas with one frame and 8px transparent exterior margin. Preserve corners, "
        "only straight rails and quiet centers may stretch.\n"
        f"3. Project visual anchor: {anchor}\n"
        f"4. Composition and state contract: {layout} One neutral master; exact same "
        "silhouette for runtime state tinting.\n"
        "5. Comfort: restrained copper luminance, low-frequency painted texture, "
        "paper luminance below the mother flower's gold. No bright bloom.\n"
        "6. Exclusions: text, pseudo-writing, logo, watermark, baked controls, "
        "plants, portrait, cost gem, alternatives, contact sheet, game-brand imitation, "
        "olive/pale-green panel fill, neon, chrome, plastic.\n"
        "7. Transparency: actual PNG alpha channel with exterior pixels alpha=0; "
        "never simulate transparency with painted gray-white checkerboard squares. "
        "real clean RGBA exterior, no environment, no solid background "
        "and no checkerboard; card paper and glass centers are intentional artwork."
    )
    runtime = {
        "size": display, "mode": "nine_patch", "patch_margin": [16, 14, 16, 14],
        "content_margin": [10, 8, 10, 8],
        "derived_by": "res://art_source/process_battle_ui_v5.py",
    }
    if kind == "button":
        runtime["path_pattern"] = "res://assets/ui/generated/battle_ui_v5/card_{state}.png"
        runtime["slots"] = {"cost_gem": [5, 5, 33, 33], "illustration": [12, 28, 118, 68],
                            "title": [12, 98, 118, 23], "description": [12, 126, 118, 73],
                            "paper": [8, 121, 126, 85]}
    else:
        runtime["path"] = "res://assets/ui/generated/battle_ui_v5/navy_status_frame.png"
    assets.append({
        "id": asset_id, "kind": kind, "role": role,
        "states": ["normal", "hover", "pressed", "disabled"] if kind == "button" else ["neutral"],
        "generation": {"enabled": True, "provider": "openai", "model": "gpt-image-2", "transparent": True, "prompt": prompt},
        "output": {"path": f"res://art_source/generated/mm_tools/battle_ui_v5/{asset_id}.png", "size": source_size},
        "runtime": runtime,
        "ui_spec": {"purpose": role, "display_size": display, "content_safe_area": safe,
                    "layout": layout, "state_contract": "Neutral master, deterministic state tints preserve exact alpha geometry",
                    "negative": ["text", "brand imitation", "watermark", "logo", "cost gem", "plant", "portrait", "baked UI"]},
        "bindings": bindings,
    })
for asset_id, node, property_name in [
    ("card_illustration", "Illustration", "texture"), ("card_title", "CardTitle", "text"),
    ("card_effect", "EffectDescription", "text"), ("card_cost", "CostValue", "text"),
]:
    assets.append({"id": asset_id, "kind": "portrait" if property_name == "texture" else "text",
                   "role": "Native semantic card content from existing project art and gameplay data",
                   "generation": {"enabled": False},
                   "bindings": [{"scope": "component", "node": node, "property": property_name}]})
for asset_id, source, path, node, prop in [
    ("navy_primary_action", "res://assets/ui/generated/battle_hud_v3/primary_action_normal.png", "res://assets/ui/generated/battle_ui_v5/primary_action_{state}.png", "PrimaryActionButton", "theme_override_styles/panel"),
    ("navy_tactical_bezel", "res://assets/ui/generated/battle_hud_v3/tactical_bezel.png", "res://assets/ui/generated/battle_ui_v5/tactical_bezel.png", "TacticalBezelArt", "texture"),
]:
    assets.append({"id": asset_id, "kind": "decoration", "role": "Deterministic navy sibling retaining source copper and alpha",
                   "generation": {"enabled": False}, "derivation": {"source": source,
                       "output": path, "derived_by": "res://art_source/process_battle_ui_v5.py",
                       "palette_function": "res://scripts/battle_palette.gd:map_green_to_navy",
                       "preserve": ["source assets", "alpha geometry", "warm copper", "brush luminance"]},
                   "bindings": [{"node": node, "property": prop}]})
manifest = {
    "$schema": "../schemas/mm_art_manifest.schema.json", "schema_version": 1,
    "feature": "battle_ui_v5", "scene": "res://scenes/main.tscn", "root_node": "BattleHudRoot",
    "style": {"reference_images": [baseline], "prompt_prefix": anchor,
              "evidence": [{"kind": k, "source": s, "reason": r} for k, s, r in evidence],
              "sprite_gen_contract": "sprite-gen/docs/gen.md", "visual_anchor": anchor,
              "comfort_constraints": ["Quiet readout centers", "Paper below mother-flower brightness", "No continuous hand tray or central obstruction"],
              "avoid": ["olive green", "neon", "brand imitation", "dense ornament", "text", "watermark"]},
    "assets": assets,
}
(ROOT / "art_source/manifests/battle_ui_v5.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
