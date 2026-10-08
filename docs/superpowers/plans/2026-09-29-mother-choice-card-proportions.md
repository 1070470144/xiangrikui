# Mother Choice Card Proportions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the stretched horizontal button skin on mother-upgrade choices with a cropped, nine-sliced portrait card skin that keeps a stable 240×300 layout.

**Architecture:** Add a mother-choice-specific card constructor in `hud.gd`; it crops the existing 280×180 `UI_Card.png` to its non-transparent 124×145 artwork bounds and uses that atlas region as a nine-sliced `StyleBoxTexture`. Keep all choice signals and data flow unchanged, while extending the battle HUD manifest and regression tests to describe and verify the new visual contract.

**Tech Stack:** Godot 4 GDScript, `AtlasTexture`, `StyleBoxTexture`, JSON art manifest, Godot headless tests.

---

### Task 1: Add a failing card-skin regression test

**Files:**
- Modify: `tests/test_battle_hud.gd`
- Test: `tests/test_battle_hud.gd`

- [ ] **Step 1: Assert portrait size and cropped atlas usage**

Inside the existing `row.get_child_count() == 3` block, add:

```gdscript
			var first_card := row.get_child(0) as Button
			expect(first_card.custom_minimum_size == Vector2(240, 300), "mother choice cards must use the portrait card size")
			var card_style := first_card.get_theme_stylebox("normal") as StyleBoxTexture
			var atlas := card_style.texture as AtlasTexture if card_style != null else null
			expect(atlas != null, "mother choice cards must use a cropped atlas texture instead of the shared horizontal button skin")
			if atlas != null:
				expect(atlas.region == Rect2(76, 19, 124, 145), "mother choice card atlas must crop transparent source padding")
```

- [ ] **Step 2: Run the focused HUD test and verify failure**

Run the focused HUD suite through a temporary `SceneTree` runner or the full command:

```powershell
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . -s tests/test_runner.gd
```

Expected: the new portrait-size and cropped-atlas assertions fail against the current `_button()` implementation.

### Task 2: Implement a dedicated non-stretched mother card

**Files:**
- Modify: `scripts/art_library.gd`
- Modify: `scripts/hud.gd`
- Test: `tests/test_battle_hud.gd`

- [ ] **Step 1: Expose the existing card texture path**

Add to `scripts/art_library.gd` beside the other generated UI constants:

```gdscript
const UI_GEN_CARD := "res://assets/ui/generated/UI_Card.png"
```

- [ ] **Step 2: Add cropped nine-slice styling helpers**

Add below `_texture_style()` in `scripts/hud.gd`:

```gdscript
func _mother_card_style(tint: Color) -> StyleBoxTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = ArtLibrary.load_texture(ArtLibrary.UI_GEN_CARD)
	atlas.region = Rect2(76, 19, 124, 145)
	var style := StyleBoxTexture.new()
	style.texture = atlas
	style.modulate_color = tint
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, 22)
		style.set_content_margin(side, 30)
	return style

func _mother_choice_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(240, 300)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color("f6e4ad"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _mother_card_style(Color.WHITE))
	button.add_theme_stylebox_override("hover", _mother_card_style(Color("fff4c7")))
	button.add_theme_stylebox_override("pressed", _mother_card_style(Color("d6b86f")))
	button.mouse_entered.connect(func(): button.position.y = -6)
	button.mouse_exited.connect(func(): button.position.y = 0)
	return button
```

- [ ] **Step 3: Use the dedicated card and tighten the modal**

Change the choice panel offsets to `Vector4(-460, -220, 460, 220)`, change row separation to `28`, and replace the current choice button creation with:

```gdscript
		var button := _mother_choice_button("%s\n\n%s" % [str(data.get("name", card_id)), description])
```

Keep the existing button name, tooltip, signal connection, and `mother_choice_row.add_child(button)` lines.

- [ ] **Step 4: Run the full Godot suite**

Run:

```powershell
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . -s tests/test_runner.gd
```

Expected: exit code `0` and `TESTS PASSED`.

### Task 3: Update and validate the mm-tools manifest

**Files:**
- Modify: `art_source/manifests/battle_hud.json`
- Test: `tests/test_mm_manifest.py`

- [ ] **Step 1: Describe the reused cropped card asset**

Replace the `mother_choice_card_frame` entry with:

```json
{
  "id": "mother_choice_card_frame",
  "kind": "panel",
  "role": "母花强化三选一专用竖版卡框；复用现有 UI_Card，裁掉透明外边后九宫格拉伸，不含文字",
  "generation": {"enabled": false},
  "runtime": {
    "source": "res://assets/ui/generated/UI_Card.png",
    "source_size": [280, 180],
    "atlas_region": [76, 19, 124, 145],
    "minimum_size": [240, 300],
    "patch_margin": [22, 22, 22, 22]
  },
  "bindings": [{"node": "MotherChoiceOverlay/MotherChoicePanel", "property": "mouse_filter"}]
}
```

Also add these two verified reference URLs to `style.reference_images`:

```json
"https://www.gameuidatabase.com/",
"https://brotato.wiki.spellsandguns.com/Upgrades"
```

The design analysis remains in `docs/superpowers/specs/2026-09-29-mother-choice-card-proportions-design.md`; do not add a `design_record` key because the current manifest schema rejects unknown top-level properties.

- [ ] **Step 2: Validate and inspect the generation plan**

Run:

```powershell
& 'C:\Users\mengmenglv\AppData\Local\Programs\Python\Python311\python.exe' aiskill/mm-tools/mm_manifest.py validate art_source/manifests/battle_hud.json
& 'C:\Users\mengmenglv\AppData\Local\Programs\Python\Python311\python.exe' aiskill/mm-tools/mm_manifest.py plan art_source/manifests/battle_hud.json
& 'C:\Users\mengmenglv\AppData\Local\Programs\Python\Python311\python.exe' -m unittest tests.test_mm_manifest
```

Expected: manifest validation succeeds, manifest tests pass, and no new generation job is scheduled for `mother_choice_card_frame`.

### Task 4: Render and inspect the final UI

**Files:**
- Verify: `tests/hud_capture.gd`
- Output: `output/imagegen/previews/hud-mother-choice-runtime.png`

- [ ] **Step 1: Render the existing mother-choice capture**

Run:

```powershell
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --path . --script tests/hud_capture.gd
```

Expected: the screenshot is regenerated with three 240×300 portrait cards using undistorted floral borders.

- [ ] **Step 2: Inspect the screenshot against the design**

Verify that floral corners retain their proportions, all three cards are equal, text remains inside the safe area, the cards fit the panel at 1152×648, and the dimmed battlefield remains visible.

- [ ] **Step 3: Run final checks**

Run:

```powershell
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . -s tests/test_runner.gd
& 'C:\Users\mengmenglv\AppData\Local\Programs\Python\Python311\python.exe' -m unittest tests.test_mm_manifest
git diff --check
```

Expected: Godot prints `TESTS PASSED`, Python reports all tests passing, and Git reports no whitespace errors.
