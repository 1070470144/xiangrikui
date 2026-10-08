# Sunflower Defense Main Menu Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current split-screen menu with the approved immersive greenhouse entrance layout, generate its background through the requested OpenAI-compatible `gpt-image-2` endpoint, and verify navigation, layout, and rendering without changing the seven-night campaign or local-save contract.

**Architecture:** Keep `scripts/main_menu.gd` as the menu controller and preserve its current `start_requested` single-campaign signal. Add one generated background constant to `ArtLibrary`, build the home screen and modal pages with native Godot containers, and expose a small read-only UI-state contract for deterministic tests. Reuse the existing `sprite-gen` OpenAI provider through `SPRITE_GEN_API_BASE` and `OPENAI_API_KEY`; do not add another HTTP client.

**Tech Stack:** Godot 4.7.2 / GDScript, existing `sprite-gen` Python CLI, OpenAI-compatible Images API, PNG assets, headless Godot contract tests, normal-renderer screenshot capture.

---

## File map

- Create `art_source/prompts/main_menu_background.txt`: reproducible background-generation prompt.
- Create `art_source/main_menu_background.report.json`: generated provider report; contains no credential.
- Create `assets/backgrounds/ART_BG_MainMenu_Greenhouse.png`: approved 1152×648 menu background.
- Modify `scripts/art_library.gd`: add the main-menu background path.
- Modify `scripts/main_menu.gd`: home composition, account modal, seven-night record, shared modal shell, focus and Escape behavior.
- Modify `tests/test_main_menu.gd`: read-only contracts for labels, progress data and campaign start signal.
- Modify `tests/test_menu_layout.gd`: rendered-tree layout, focus and page-navigation assertions.
- Modify `tests/test_runner.gd`: keep contract suite coverage if a new suite is introduced; otherwise no change.
- Create `tests/main_menu_capture.gd`: deterministic screenshot capture that leaves the menu on its home page.
- Create `preview_main_menu/`: generated verification frames; do not commit transient duplicate frames unless the repository convention requires them.

### Task 1: Lock the menu contract with failing tests

**Files:**
- Modify: `tests/test_main_menu.gd`
- Modify: `tests/test_menu_layout.gd`

- [ ] **Step 1: Add contract assertions for the approved information hierarchy**

Add these calls to `run()` in `tests/test_main_menu.gd` before `test_game_start_flow()`:

```gdscript
	test_home_menu_contract()
	test_seven_night_contract()
```

Add the following tests above `test_game_start_flow()`:

```gdscript
func test_home_menu_contract() -> void:
	var script := _load_script("res://scripts/main_menu.gd")
	if script == null:
		return
	var menu: Control = script.new()
	var labels: Array = menu.get_home_action_labels()
	expect(labels == ["继续守夜", "七夜记录", "温室图鉴", "设置"], "home menu must expose the approved action hierarchy")
	expect(menu.get_home_tagline() == "太阳已经熄灭，而守夜仍将继续。", "home menu must expose the approved narrative tagline")
	expect(menu.has_signal("start_requested"), "home menu must preserve the single-campaign start signal")
	menu.free()

func test_seven_night_contract() -> void:
	var script := _load_script("res://scripts/main_menu.gd")
	if script == null:
		return
	var menu: Control = script.new()
	var nights: Array = menu.get_night_records()
	expect(nights.size() == 7, "night record must expose exactly seven nights")
	expect(str(nights[2].get("name", "")) == "酸雨", "third night must be named Acid Rain")
	expect(str(nights[3].get("name", "")) == "雷雨", "fourth night must be named Thunderstorm")
expect(str(nights[4].get("name", "")) == "根冠巨像", "fifth night must name the first boss")
	menu.free()
```

- [ ] **Step 2: Replace the obsolete home-page layout assertion**

In `tests/test_menu_layout.gd`, replace `verify_layout()` with:

```gdscript
func verify_layout() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var main := scene.instantiate()
	root.add_child(main)
	for _frame in range(4):
		await process_frame

	var start_button := _find_button(main, "继续守夜")
	var account_button := _find_button_containing(main, "本地存档")
	var record_button := _find_button(main, "七夜记录")
	if start_button == null or account_button == null or record_button == null:
		push_error("home page must expose start, account and seven-night controls")
		quit(1)
		return

	var viewport_rect := root.get_viewport().get_visible_rect()
	for control in [start_button, account_button, record_button]:
		if not viewport_rect.encloses(control.get_global_rect()):
			push_error("home control is clipped: %s" % control.text)
			quit(1)
			return

	start_button.grab_focus()
	if root.get_viewport().gui_get_focus_owner() != start_button:
		push_error("primary action must accept keyboard focus")
		quit(1)
		return

	record_button.emit_signal("pressed")
	await process_frame
	if _find_label(main, "七夜记录") == null or _find_button(main, "返回") == null:
		push_error("seven-night record page must open and expose a return action")
		quit(1)
		return

	print("MENU LAYOUT PASSED")
	quit(0)
```

Append these helpers:

```gdscript
func _find_button_containing(node: Node, fragment: String) -> Button:
	if node is Button and fragment in node.text:
		return node
	for child in node.get_children():
		var found := _find_button_containing(child, fragment)
		if found != null:
			return found
	return null

func _find_label(node: Node, label_text: String) -> Label:
	if node is Label and node.text == label_text:
		return node
	for child in node.get_children():
		var found := _find_label(child, label_text)
		if found != null:
			return found
	return null
```

- [ ] **Step 3: Run the tests and verify the new contracts fail**

Run:

```powershell
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . -s tests/test_runner.gd
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . -s tests/test_menu_layout.gd
```

Expected: the contract suite fails because `get_home_action_labels`, `get_home_tagline`, and `get_night_records` do not exist; the layout test fails because the new controls do not exist.

- [ ] **Step 4: Commit the red tests**

```powershell
git add -- tests/test_main_menu.gd tests/test_menu_layout.gd
git commit -m "test: define redesigned main menu contract"
```

### Task 2: Create the reproducible background prompt and generate the asset

**Files:**
- Create: `art_source/prompts/main_menu_background.txt`
- Create: `art_source/main_menu_background.generated.png`
- Create: `art_source/main_menu_background.report.json`
- Create: `assets/backgrounds/ART_BG_MainMenu_Greenhouse.png`

- [ ] **Step 1: Create the exact generation prompt**

Write this text to `art_source/prompts/main_menu_background.txt`:

```text
Use case: production game main-menu background
Asset type: opaque 2D environment illustration, no interface elements
Primary request: The interior entrance of a ruined Victorian greenhouse after the sun has died, for a dark fantasy botanical defense game called The Last Sunflower. A healthy solar mother flower grows slightly left of center and is the only strong warm light source. The rightmost 36 percent is a calm, low-detail, dark negative-space area reserved for a native game menu.
Style and medium: premium hand-painted storybook environment, thick painterly brushwork, botanical realism, subtle paper grain, restrained oxidized metal and worn horticultural materials, production-quality 2D game art.
Composition: exact wide 16:9 frame. Broken greenhouse ribs, shattered glass silhouettes, dead leaves and cold mist frame the outer edges. Keep the mother flower silhouette unobstructed. Preserve strong readable separation between the left focal area and right menu-safe area without drawing a vertical divider or panel.
Lighting and mood: melancholic and dangerous but still hopeful. Cold blue-violet ruined night surrounds a warm golden living core. The mother flower is the brightest and warmest object, with restrained roots and a few subtle floating motes; no large bloom cloud.
Palette: deep navy #111827, muted gray-violet #25263A, brown-purple #3A3032, desaturated moss #263D35, life gold #E5B94B and warm highlight #FFF0B0.
Constraints: no words, no letters, no numbers, no labels, no logo, no watermark, no buttons, no frames, no cards, no HUD, no people, no menu UI, no split-screen divider. The right side must remain readable beneath a translucent dark panel.
Avoid: photorealism, anime, pixel art, flat vector art, neon cyberpunk, glassmorphism, ornate medieval filigree, bright saturated rainbow colors, central symmetry, a sunflower placed on the right side.
```

- [ ] **Step 2: Verify the provider configuration without spending credit**

Run:

```powershell
$env:SPRITE_GEN_API_BASE = 'https://newapi.oairegbox.cc/v1'
$env:PYTHONPATH = (Resolve-Path 'sprite-gen').Path
& python -c "from sprite_gen.gen.openai_provider import resolve_api_base, SIZES; assert resolve_api_base() == 'https://newapi.oairegbox.cc/v1'; assert SIZES['16:9'] == '1536x864'; print('OPENAI COMPAT CONFIG PASSED')"
```

Expected: `OPENAI COMPAT CONFIG PASSED`. This command makes no network request.

- [ ] **Step 3: Confirm the required credential exists without printing it**

Run:

```powershell
if ([string]::IsNullOrWhiteSpace($env:OPENAI_API_KEY)) { throw 'OPENAI_API_KEY is not set' } else { 'OPENAI_API_KEY is configured' }
```

Expected: `OPENAI_API_KEY is configured`. If it is missing, stop here and ask the user to configure it; do not create a placeholder key or switch provider.

- [ ] **Step 4: Generate exactly one paid candidate**

Run from `sprite-gen`:

```powershell
$env:SPRITE_GEN_API_BASE = 'https://newapi.oairegbox.cc/v1'
& python -m sprite_gen gen --provider openai --prompt-file '..\art_source\prompts\main_menu_background.txt' --out '..\art_source\main_menu_background.generated.png' --aspect-ratio 16:9 --quality high --model gpt-image-2 --report '..\art_source\main_menu_background.report.json'
```

Expected: one successful API request, a valid opaque 1536×864 PNG, and a report whose `provider` is `openai`, `model` is `gpt-image-2`, `extra.endpoint` is `/images/generations`, and `extra.size` is `1536x864`. Do not automatically retry a transport failure because the request may already have been billed.

- [ ] **Step 5: Inspect and resize the candidate**

Open `art_source/main_menu_background.generated.png` and reject it if it contains text, watermarks, UI elements, a right-side focal object, or insufficient right-side negative space. If accepted, use Pillow for a high-quality exact resize:

```powershell
& python -c "from PIL import Image; src=Image.open('art_source/main_menu_background.generated.png').convert('RGB'); assert src.size == (1536,864), src.size; src.resize((1152,648), Image.Resampling.LANCZOS).save('assets/backgrounds/ART_BG_MainMenu_Greenhouse.png', optimize=True); print('MAIN MENU BACKGROUND READY')"
```

Expected: `MAIN MENU BACKGROUND READY` and an opaque 1152×648 PNG.

- [ ] **Step 6: Commit the prompt, report, source and game asset**

```powershell
git add -- art_source/prompts/main_menu_background.txt art_source/main_menu_background.generated.png art_source/main_menu_background.report.json assets/backgrounds/ART_BG_MainMenu_Greenhouse.png
git commit -m "art: add generated greenhouse menu background"
```

### Task 3: Add the background asset contract

**Files:**
- Modify: `scripts/art_library.gd`
- Modify: `tests/test_art_assets.gd`

- [ ] **Step 1: Add a failing art-asset assertion**

In `tests/test_art_assets.gd`, add the main-menu path to the same required-path collection used for other formal assets:

```gdscript
	ArtLibrary.MAIN_MENU_BACKGROUND,
```

If that test enumerates paths inline instead of using a collection, add:

```gdscript
expect(ResourceLoader.exists(ArtLibrary.MAIN_MENU_BACKGROUND), "main menu background must exist")
```

- [ ] **Step 2: Run the art test and verify it fails**

Run:

```powershell
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . -s tests/test_runner.gd
```

Expected: FAIL because `ArtLibrary.MAIN_MENU_BACKGROUND` is undefined.

- [ ] **Step 3: Add the asset constant**

At the top of `scripts/art_library.gd`, immediately after `BACKGROUND_FOREGROUND`, add:

```gdscript
const MAIN_MENU_BACKGROUND := "res://assets/backgrounds/ART_BG_MainMenu_Greenhouse.png"
```

- [ ] **Step 4: Run the contract suite**

Run the command from Step 2.

Expected: the art-asset assertion passes; Task 1's menu contract tests still fail.

- [ ] **Step 5: Commit the asset contract**

```powershell
git add -- scripts/art_library.gd tests/test_art_assets.gd
git commit -m "feat: register main menu background asset"
```

### Task 4: Implement the home screen hierarchy

**Files:**
- Modify: `scripts/main_menu.gd:1-223`
- Test: `tests/test_main_menu.gd`
- Test: `tests/test_menu_layout.gd`

- [ ] **Step 1: Add stable home and night-record data contracts**

After `SETTINGS_ENTRIES`, add:

```gdscript
const HOME_ACTION_LABELS := ["继续守夜", "七夜记录", "温室图鉴", "设置"]
const HOME_TAGLINE := "太阳已经熄灭，而守夜仍将继续。"
const NIGHT_RECORDS := [
	{"number": 1, "name": "初临"},
	{"number": 2, "name": "八方来袭"},
	{"number": 3, "name": "酸雨"},
	{"number": 4, "name": "雷雨"},
	{"number": 5, "name": "根冠巨像"},
	{"number": 6, "name": "喘息"},
	{"number": 7, "name": "太阳吞噬者"},
]
```

Add these public read-only helpers after `get_settings_entries()`:

```gdscript
func get_home_action_labels() -> Array:
	return HOME_ACTION_LABELS.duplicate()

func get_home_tagline() -> String:
	return HOME_TAGLINE

func get_night_records() -> Array:
	return NIGHT_RECORDS.duplicate(true)
```

- [ ] **Step 2: Build the generated background with a safe fallback**

Replace `_build_background()` with:

```gdscript
func _build_background() -> void:
	var fallback := ColorRect.new()
	fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fallback.color = Color("111827")
	add_child(fallback)

	var bg := TextureRect.new()
	bg.name = "MainMenuBackground"
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.texture = ArtLibrary.load_texture(ArtLibrary.MAIN_MENU_BACKGROUND)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg)

	var atmosphere := ColorRect.new()
	atmosphere.name = "AtmosphereShade"
	atmosphere.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	atmosphere.color = Color(0.02, 0.035, 0.055, 0.22)
	add_child(atmosphere)

	page_stack = Control.new()
	page_stack.name = "PageStack"
	page_stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page_stack)
```

- [ ] **Step 3: Replace `_show_home()` with the entrance composition**

Use native containers and named controls. The implementation must include these exact control names and labels so tests and future maintenance have stable anchors:

```gdscript
func _show_home() -> void:
	_clear_page()
	var root := Control.new()
	root.name = "HomePage"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page_stack.add_child(root)

	var title_box := VBoxContainer.new()
	title_box.name = "TitleBlock"
	title_box.position = Vector2(58, 58)
	title_box.size = Vector2(610, 150)
	title_box.add_theme_constant_override("separation", 8)
	root.add_child(title_box)
	var title := _label("最后的向日葵", 46, Color("fff0b0"))
	title.add_theme_color_override("font_shadow_color", Color(0.03, 0.04, 0.07, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 3)
	title_box.add_child(title)
	var tagline := _label(HOME_TAGLINE, 18, Color("d5dccb"))
	title_box.add_child(tagline)

	var account := _account_entry_button()
	account.position = Vector2(846, 28)
	account.size = Vector2(278, 58)
	root.add_child(account)

	var menu_panel := PanelContainer.new()
	menu_panel.name = "MenuJournal"
	menu_panel.position = Vector2(778, 105)
	menu_panel.size = Vector2(346, 505)
	menu_panel.add_theme_stylebox_override("panel", _journal_style())
	root.add_child(menu_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 24)
	menu_panel.add_child(margin)
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 13)
	margin.add_child(actions)
	var section := _label("园丁记录", 18, Color("a9c49e"))
	actions.add_child(section)
	var primary := _menu_button("继续守夜", _request_start)
	primary.name = "PrimaryStartButton"
	primary.custom_minimum_size.y = 68
	primary.add_theme_font_size_override("font_size", 25)
	actions.add_child(primary)
	var progress := clampi(int(local_profile.get("level_progress", 0)), 0, 7)
	var progress_text := "尚未开始 · 第一夜等待园丁" if progress == 0 else "第 %d 夜 · %s" % [progress, NIGHT_RECORDS[progress - 1]["name"]]
	var progress_label := _label(progress_text, 13, Color("c4b77f"))
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	actions.add_child(progress_label)
	actions.add_child(_menu_button("七夜记录", _show_night_records))
	actions.add_child(_menu_button("温室图鉴", _show_codex))
	actions.add_child(_menu_button("设置", _show_settings))
	var flex := Control.new()
	flex.size_flags_vertical = Control.SIZE_EXPAND_FILL
	actions.add_child(flex)
	var exit_button := Button.new()
	exit_button.text = "退出游戏"
	exit_button.flat = true
	exit_button.custom_minimum_size.y = 44
	exit_button.add_theme_font_size_override("font_size", 15)
	exit_button.add_theme_color_override("font_color", Color("87938a"))
	exit_button.add_theme_color_override("font_hover_color", Color("d8c98f"))
	exit_button.pressed.connect(func(): get_tree().quit())
	actions.add_child(exit_button)

	var version := _label("本地版本 · 数据仅保存在此设备", 12, Color("6f7d78"))
	version.position = Vector2(30, 610)
	root.add_child(version)
	primary.grab_focus()
```

Add the direct start helper:

```gdscript
var start_pending := false

func _request_start() -> void:
	if start_pending:
		return
	start_pending = true
	start_requested.emit()
```

- [ ] **Step 4: Add account-entry and journal styles**

Add:

```gdscript
func _account_entry_button() -> Button:
	var button := Button.new()
	button.name = "AccountEntry"
	button.text = "✦  %s\n本地存档" % str(local_profile.get("player_name", "温室守护者"))
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color("eee0aa"))
	button.add_theme_stylebox_override("normal", _compact_style(Color("14231ee8"), Color("7f7651")))
	button.add_theme_stylebox_override("hover", _compact_style(Color("21352ce8"), Color("d0ad54")))
	button.add_theme_stylebox_override("focus", _focus_style())
	button.pressed.connect(_show_account_switcher)
	return button

func _journal_style() -> StyleBoxFlat:
	var style := _panel_style(Color("101a20ee"), Color("9d8246"), 1)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	style.shadow_color = Color(0, 0, 0, 0.42)
	style.shadow_size = 10
	return style

func _compact_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _focus_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color("fff0b0")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.expand_margin_left = 2
	style.expand_margin_right = 2
	style.expand_margin_top = 2
	style.expand_margin_bottom = 2
	return style
```

Update `_menu_button()` to add disabled and focus styles while preserving existing pressed callbacks:

```gdscript
	button.add_theme_stylebox_override("disabled", _panel_style(Color("1c2522"), Color("53594f"), 1))
	button.add_theme_stylebox_override("focus", _focus_style())
```

- [ ] **Step 5: Run the contract suite**

Run:

```powershell
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . -s tests/test_runner.gd
```

Expected: `TESTS PASSED`. The rendered layout test may still fail until Task 5 creates the seven-night page.

- [ ] **Step 6: Commit the home screen**

```powershell
git add -- scripts/main_menu.gd tests/test_main_menu.gd
git commit -m "feat: redesign main menu home screen"
```

### Task 5: Implement the record and modal pages

**Files:**
- Modify: `scripts/main_menu.gd:225-407`
- Test: `tests/test_menu_layout.gd`

- [ ] **Step 1: Add shared modal-shell construction**

Add before `_show_account_switcher()`:

```gdscript
func _modal_shell(title_text: String, panel_size: Vector2 = Vector2(900, 520)) -> VBoxContainer:
	_clear_page()
	var shade := ColorRect.new()
	shade.name = "ModalShade"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.025, 0.035, 0.55)
	page_stack.add_child(shade)
	var root := VBoxContainer.new()
	root.name = title_text + "Page"
	root.position = (Vector2(1152, 648) - panel_size) * 0.5
	root.size = panel_size
	root.add_theme_constant_override("separation", 14)
	page_stack.add_child(root)
	var back := _back_button(_show_home)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	root.add_child(back)
	var heading := _label(title_text, 34, Color("fff0b0"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(heading)
	return root
```

- [ ] **Step 2: Implement the seven-night record page**

Add:

```gdscript
func _show_night_records() -> void:
	var root := _modal_shell("七夜记录", Vector2(980, 500))
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _journal_style())
	root.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 38)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	var progress := clampi(int(local_profile.get("level_progress", 0)), 0, 7)
	for night in NIGHT_RECORDS:
		var number := int(night["number"])
		var card := VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_constant_override("separation", 10)
		row.add_child(card)
		var marker := Label.new()
		marker.text = "✦" if number <= progress else "◇"
		marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		marker.add_theme_font_size_override("font_size", 29)
		marker.add_theme_color_override("font_color", Color("fff0b0") if number == progress else (Color("e5b94b") if number < progress else Color("686779")))
		card.add_child(marker)
		var number_label := _label("第 %d 夜" % number, 14, Color("c7cdbf"))
		number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(number_label)
		var name_label := _label(str(night["name"]), 14, Color("f0dfa5") if number <= progress else Color("777783"))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(name_label)
```

- [ ] **Step 3: Move account, codex and settings into the shared shell**

For `_show_account_switcher()`, `_show_settings()` and `_show_codex()`, replace their fixed root positions and duplicate headings with calls to `_modal_shell()`:

```gdscript
var root := _modal_shell("园丁档案", Vector2(620, 535))
```

```gdscript
var root := _modal_shell("设置", Vector2(650, 500))
```

```gdscript
var root := _modal_shell("温室图鉴", Vector2(980, 565))
```

Do not add a second bottom return button; `_modal_shell()` already provides one at the top-left. Keep the existing account creation, volume, fullscreen, tab, and card logic inside each root.

- [ ] **Step 4: Add Escape navigation**

Add:

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel_action") and page_stack != null:
		var home := page_stack.get_node_or_null("HomePage")
		if home == null:
			_show_home()
			get_viewport().set_input_as_handled()
```

- [ ] **Step 5: Run the menu contract and layout tests**

Run:

```powershell
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . -s tests/test_runner.gd
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . -s tests/test_menu_layout.gd
```

Expected: `TESTS PASSED` and `MENU LAYOUT PASSED`.

- [ ] **Step 6: Commit the modal pages**

```powershell
git add -- scripts/main_menu.gd tests/test_menu_layout.gd
git commit -m "feat: add garden journal menu pages"
```

### Task 6: Add restrained motion and deterministic capture support

**Files:**
- Modify: `scripts/main_menu.gd`
- Create: `tests/main_menu_capture.gd`

- [ ] **Step 1: Add a simple entrance animation that can be disabled**

Add a public test switch near `start_pending`:

```gdscript
var motion_enabled := true

func set_motion_enabled(enabled: bool) -> void:
	motion_enabled = enabled
```

In `_show_settings()`, add a session-level reduced-motion control after the fullscreen button:

```gdscript
	var reduced_motion := CheckButton.new()
	reduced_motion.text = "减少动态效果"
	reduced_motion.button_pressed = not motion_enabled
	reduced_motion.add_theme_font_size_override("font_size", 20)
	reduced_motion.toggled.connect(func(enabled: bool):
		motion_enabled = not enabled
	)
	box.add_child(reduced_motion)
```

At the end of `_show_home()`, after `primary.grab_focus()`, add:

```gdscript
	if motion_enabled:
		_animate_home(title_box, menu_panel)
```

Add:

```gdscript
func _animate_home(title_box: Control, menu_panel: Control) -> void:
	var title_end := title_box.position
	var panel_end := menu_panel.position
	title_box.position.y += 10.0
	menu_panel.position.x += 18.0
	title_box.modulate.a = 0.0
	menu_panel.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(title_box, "position", title_end, 0.3)
	tween.tween_property(title_box, "modulate:a", 1.0, 0.24)
	tween.tween_property(menu_panel, "position", panel_end, 0.34).set_delay(0.05)
	tween.tween_property(menu_panel, "modulate:a", 1.0, 0.28).set_delay(0.05)
```

This animation changes only local UI properties.

- [ ] **Step 2: Replace the immediate start with the approved transition**

Replace `_request_start()` from Task 4 with:

```gdscript
func _request_start() -> void:
	if start_pending:
		return
	start_pending = true
	if not motion_enabled:
		start_requested.emit()
		return
	var home := page_stack.get_node_or_null("HomePage") as Control
	var veil := ColorRect.new()
	veil.name = "StartTransitionVeil"
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.06, 0.035, 0.02, 0.0)
	page_stack.add_child(veil)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if home != null:
		tween.tween_property(home, "modulate:a", 0.0, 0.42)
	tween.tween_property(veil, "color", Color(0.015, 0.02, 0.025, 1.0), 0.5)
	tween.chain().tween_callback(func(): start_requested.emit())
```

This keeps the transition within 500 ms, ignores repeated clicks through `start_pending`, and emits immediately when reduced motion is enabled.

- [ ] **Step 3: Create deterministic capture script**

Create `tests/main_menu_capture.gd`:

```gdscript
extends SceneTree

func _initialize() -> void:
	call_deferred("capture_menu")

func capture_menu() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var main := scene.instantiate()
	root.add_child(main)
	await process_frame
	var menu := main.current_screen
	if menu != null and menu.has_method("set_motion_enabled"):
		menu.set_motion_enabled(false)
		menu._show_home()
	for _frame in range(3):
		await process_frame
	quit(0)
```

- [ ] **Step 4: Run all headless tests**

Run:

```powershell
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . -s tests/test_runner.gd
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . -s tests/test_menu_layout.gd
```

Expected: both exit 0.

- [ ] **Step 5: Commit motion and capture support**

```powershell
git add -- scripts/main_menu.gd tests/main_menu_capture.gd
git commit -m "feat: add menu entrance motion and capture"
```

### Task 7: Render and visually inspect every affected page

**Files:**
- Create: `preview_main_menu/menu*.png`
- Inspect: home, account, seven-night record, codex and settings pages

- [ ] **Step 1: Capture the home page with the normal renderer**

Run:

```powershell
New-Item -ItemType Directory -Force 'preview_main_menu' | Out-Null
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --path . --write-movie 'preview_main_menu/menu.png' --fixed-fps 10 --quit-after 4 -s tests/main_menu_capture.gd
```

Expected: exit 0 and four 1152×648 PNG frames.

- [ ] **Step 2: Inspect the last frame against the design specification**

Verify all of the following directly in the rendered PNG:

- mother flower is the brightest and warmest focal object;
- title does not cover the flower;
- right panel is 330–360 px wide and does not read as a hard split-screen wall;
- `继续守夜`, `七夜记录`, `温室图鉴`, `设置` are readable;
- account entry is fully visible in the top-right;
- exit and version text are subordinate;
- no generated text, watermark, HUD or cyber-neon elements exist in the background;
- no control is clipped at 1152×648.

- [ ] **Step 3: Add page-state capture arguments and capture every modal page**

Extend `tests/main_menu_capture.gd` to parse `--page=account|records|codex|settings` and call the corresponding menu method:

```gdscript
	var page := "home"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--page="):
			page = argument.trim_prefix("--page=")
	match page:
		"account": menu._show_account_switcher()
		"records": menu._show_night_records()
		"codex": menu._show_codex()
		"settings": menu._show_settings()
		_: menu._show_home()
```

Capture all four pages using `-- --page=account`, `-- --page=records`, `-- --page=codex`, and `-- --page=settings`; inspect headings, returns, text wrapping, and clipping in every resulting frame.

- [ ] **Step 4: Correct only observed visual defects**

For each defect, change the smallest relevant margin, minimum size, font size, contrast or container rule in `scripts/main_menu.gd`, then rerun the affected screenshot and both test commands. Do not change background generation or unrelated gameplay code to compensate for a UI layout defect.

- [ ] **Step 5: Commit verified visual adjustments**

```powershell
git add -- scripts/main_menu.gd tests/main_menu_capture.gd
git commit -m "fix: polish redesigned menu layout"
```

### Task 8: Full regression and completion audit

**Files:**
- Verify all files touched by Tasks 1–7
- Compare against: `docs/superpowers/specs/2026-09-28-sunflower-defense-main-menu-redesign.md`

- [ ] **Step 1: Run the complete unit suite**

```powershell
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . -s tests/test_runner.gd
```

Expected: exit 0 and `TESTS PASSED`.

- [ ] **Step 2: Run layout verification**

```powershell
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . -s tests/test_menu_layout.gd
```

Expected: exit 0 and `MENU LAYOUT PASSED`.

- [ ] **Step 3: Run the existing integration smoke test**

```powershell
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . -s tests/integration_smoke.gd
```

Expected: exit 0 with no parse errors, missing resources or runtime assertion failures.

- [ ] **Step 4: Validate the generated asset and report**

```powershell
& python -c "import json; from PIL import Image; p='assets/backgrounds/ART_BG_MainMenu_Greenhouse.png'; im=Image.open(p); assert im.size==(1152,648), im.size; r=json.load(open('art_source/main_menu_background.report.json',encoding='utf-8')); assert r['provider']=='openai'; assert r['model']=='gpt-image-2'; assert r['extra']['endpoint']=='/images/generations'; assert r['extra']['size']=='1536x864'; print('GENERATED ASSET VERIFIED')"
```

Expected: `GENERATED ASSET VERIFIED`.

- [ ] **Step 5: Audit the working tree without overwriting unrelated changes**

```powershell
git status --short
git diff -- scripts/main_menu.gd scripts/art_library.gd tests/test_main_menu.gd tests/test_menu_layout.gd tests/main_menu_capture.gd
```

Expected: only intended menu-redesign changes are present in these paths. Existing unrelated changes in gameplay or balance files remain untouched.

- [ ] **Step 6: Final commit if verification produced tracked corrections**

```powershell
git add -- scripts/main_menu.gd scripts/art_library.gd tests/test_main_menu.gd tests/test_menu_layout.gd tests/main_menu_capture.gd art_source/prompts/main_menu_background.txt art_source/main_menu_background.generated.png art_source/main_menu_background.report.json assets/backgrounds/ART_BG_MainMenu_Greenhouse.png
git commit -m "feat: complete greenhouse main menu redesign"
```

If all intended changes were already committed in earlier tasks, do not create an empty commit.
