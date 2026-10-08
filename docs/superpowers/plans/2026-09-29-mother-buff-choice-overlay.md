# Mother Buff Choice Overlay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the empty central mother-buff panel with a full-screen dimmed modal containing three equal, readable choice cards that disappears immediately after a successful choice.

**Architecture:** Keep the existing `mother_card_requested` signal and game-state ownership unchanged. Refactor only the HUD presentation into a full-viewport modal overlay whose visibility is driven by non-empty choice data, and extend the existing feature art manifest with explicit text/card bindings while retaining programmatic fallback styling.

**Tech Stack:** Godot 4 GDScript, programmatic `Control` UI, JSON art manifest, headless Godot test runner.

---

### Task 1: Specify modal behavior with failing HUD tests

**Files:**
- Modify: `tests/test_battle_hud.gd`
- Test: `tests/test_battle_hud.gd`

- [ ] **Step 1: Add failing overlay assertions**

Add the following block after the combat-hand assertions in `run()`:

```gdscript
	if hud.has_method("show_mother_choices"):
		var choices: Array[String] = ["mother_path_sunseed", "mother_path_receptacle", "mother_path_dawn"]
		hud.show_mother_choices(choices)
		var overlay := hud.find_child("MotherChoiceOverlay", true, false) as Control
		var row := hud.find_child("MotherChoiceRow", true, false) as Container
		expect(overlay != null and overlay.visible, "non-empty mother choices must show the full-screen overlay")
		expect(overlay != null and overlay.anchor_right == 1.0 and overlay.anchor_bottom == 1.0, "mother choice overlay must cover the viewport")
		expect(overlay != null and overlay.mouse_filter == Control.MOUSE_FILTER_STOP, "mother choice overlay must block background input")
		expect(row != null and row.get_child_count() == 3, "mother choice overlay must show exactly three cards")
		if row != null and row.get_child_count() == 3:
			var first_size := (row.get_child(0) as Control).custom_minimum_size
			for child in row.get_children():
				expect((child as Control).custom_minimum_size == first_size, "mother buff cards must use equal sizes")
		hud.hide_mother_choices()
		expect(not overlay.visible, "choosing a mother buff must hide the complete overlay")
		hud.show_mother_choices([] as Array[String])
		expect(not overlay.visible, "empty mother choices must not leave a blank overlay")
```

- [ ] **Step 2: Run the test suite and confirm the new contract fails**

Run: `godot --headless --path . -s tests/test_runner.gd`

Expected: exit code `1` with failures mentioning `MotherChoiceOverlay` and/or `MotherChoiceRow`.

- [ ] **Step 3: Commit the test contract**

```powershell
git add tests/test_battle_hud.gd
git commit -m "test: define mother buff overlay behavior"
```

### Task 2: Build the full-screen overlay and equal cards

**Files:**
- Modify: `scripts/hud.gd:28-45`
- Modify: `scripts/hud.gd:184-218`
- Test: `tests/test_battle_hud.gd`

- [ ] **Step 1: Track the overlay and name the choice row**

Replace the mother-choice declarations with:

```gdscript
var mother_choice_overlay: Control
var mother_choice_panel: PanelContainer
var mother_choice_row: HBoxContainer
```

- [ ] **Step 2: Replace the compact panel with a full-viewport modal**

Replace the mother-choice construction at the start of `_build_modal_layers()` with:

```gdscript
	mother_choice_overlay = ColorRect.new()
	mother_choice_overlay.name = "MotherChoiceOverlay"
	mother_choice_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mother_choice_overlay.color = Color(0.015, 0.02, 0.025, 0.78)
	mother_choice_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	mother_choice_overlay.visible = false
	_root.add_child(mother_choice_overlay)
	mother_choice_panel = _panel("MotherChoicePanel", mother_choice_overlay, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-500, -210, 500, 210), _ornate_panel(Color("071016f2"), Color("b48d42"), 2, 10))
	var choice_box := VBoxContainer.new()
	choice_box.add_theme_constant_override("separation", 24)
	mother_choice_panel.add_child(choice_box)
	var choice_title := _label("选择今日的母花强化", 28)
	choice_title.name = "MotherChoiceTitle"
	choice_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	choice_box.add_child(choice_title)
	mother_choice_row = HBoxContainer.new()
	mother_choice_row.name = "MotherChoiceRow"
	mother_choice_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mother_choice_row.add_theme_constant_override("separation", 24)
	choice_box.add_child(mother_choice_row)
```

- [ ] **Step 3: Render readable equal-size cards and hide empty states**

Replace `show_mother_choices()` and `hide_mother_choices()` with:

```gdscript
func show_mother_choices(choice_ids: Array[String]) -> void:
	if choice_ids.is_empty():
		hide_mother_choices()
		return
	var signature := ",".join(choice_ids)
	if signature == _mother_choice_signature and mother_choice_overlay.visible:
		return
	_mother_choice_signature = signature
	for child in mother_choice_row.get_children():
		child.free()
	for card_id in choice_ids:
		var data := ContentData.get_mother_path(card_id)
		if data.is_empty():
			data = ContentData.get_mother_upgrade(card_id)
		var title := str(data.get("name", card_id))
		var description := str(data.get("description", data.get("effect", "强化母花能力")))
		var button := _button("%s\n\n%s" % [title, description], Vector2(286, 260))
		button.name = "MotherChoiceCard_%s" % card_id
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.tooltip_text = "选择后立即生效并进入备战"
		button.pressed.connect(func(): mother_card_requested.emit(card_id))
		mother_choice_row.add_child(button)
	mother_choice_overlay.visible = true
	mother_choice_overlay.move_to_front()

func hide_mother_choices() -> void:
	mother_choice_overlay.visible = false
	_mother_choice_signature = ""
```

- [ ] **Step 4: Run the full GDScript test suite**

Run: `godot --headless --path . -s tests/test_runner.gd`

Expected: exit code `0` and `TESTS PASSED`.

- [ ] **Step 5: Commit the implementation**

```powershell
git add scripts/hud.gd tests/test_battle_hud.gd
git commit -m "feat: show mother buffs in fullscreen overlay"
```

### Task 3: Record the modal in the battle HUD manifest

**Files:**
- Modify: `art_source/manifests/battle_hud.json`
- Test: `tests/test_mm_manifest.py`

- [ ] **Step 1: Add manifest entries for programmatic text and card frame bindings**

Append these objects to the manifest `assets` array:

```json
{
  "id": "mother_choice_card_frame",
  "kind": "panel",
  "role": "母花强化三选一的等尺寸卡牌底框，不包含文字",
  "generation": {"enabled": false},
  "runtime": {"fallback": "programmatic_ornate_button", "minimum_size": [286, 260]},
  "bindings": [{"node": "MotherChoiceRow/MotherChoiceCard_*", "property": "theme_override_styles/normal"}]
},
{
  "id": "mother_choice_title",
  "kind": "text",
  "role": "全屏母花强化选择标题，由 Godot 渲染",
  "generation": {"enabled": false},
  "runtime": {"text": "选择今日的母花强化", "font_size": 28, "color": "#F6E4AD"},
  "bindings": [{"node": "MotherChoiceTitle", "property": "text"}]
}
```

- [ ] **Step 2: Validate and plan the manifest**

Run:

```powershell
python aiskill/mm-tools/mm_manifest.py validate art_source/manifests/battle_hud.json
python aiskill/mm-tools/mm_manifest.py plan art_source/manifests/battle_hud.json
```

Expected: validation succeeds; the plan reports both new entries with generation disabled and schedules no image generation for them.

- [ ] **Step 3: Run manifest tests**

Run: `python -m unittest tests.test_mm_manifest`

Expected: exit code `0` and all tests pass.

- [ ] **Step 4: Commit manifest metadata**

```powershell
git add art_source/manifests/battle_hud.json
git commit -m "docs: bind mother choice overlay art metadata"
```

### Task 4: Capture and verify the finished layout

**Files:**
- Verify: `scripts/hud.gd`
- Verify: `art_source/manifests/battle_hud.json`
- Output: existing project screenshot workflow output under `output/imagegen/previews/`

- [ ] **Step 1: Run all automated checks**

Run:

```powershell
godot --headless --path . -s tests/test_runner.gd
python -m unittest tests.test_mm_manifest
python aiskill/mm-tools/mm_manifest.py validate art_source/manifests/battle_hud.json
```

Expected: all three commands exit `0`; Godot prints `TESTS PASSED`.

- [ ] **Step 2: Capture the day HUD at the mother-choice state**

Run the repository's HUD capture entry point:

```powershell
godot --path . --editor --script tests/hud_capture.gd
```

Expected: a screenshot is produced showing a viewport-wide translucent dark overlay and three centered equal cards with visible names and descriptions.

- [ ] **Step 3: Visually inspect the capture**

Confirm the overlay covers the entire viewport, the three cards are the same size, all card text fits, the battlefield remains faintly visible, and no empty central panel remains after the modal is hidden.

- [ ] **Step 4: Review the final diff without changing unrelated work**

Run: `git diff --check` and `git status --short`

Expected: no whitespace errors; only task files and pre-existing user changes are listed.
