# Greenhouse Gardener Record Menu Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the mismatched eastern-scroll right-side main menu with a greenhouse gardener record UI that inherits the existing background’s dark botanical, oxidized-brass, glass, and warm-sunlight language.

**Architecture:** Keep the current `main_menu.gd` layout, navigation, profile data, and focus behavior. Add a new set of stable MM assets under `assets/ui/generated/` and bind them through `ArtLibrary`; retain native Godot fallbacks so the menu remains usable before generation or if an asset fails to load.

**Tech Stack:** Godot 4.7.2, GDScript, Python 3.11, Pillow, existing `mm-tools` manifest pipeline, `mm-api/gpt-image-2`.

---

## File structure

- Modify `scripts/main_menu.gd` — build the right-side gardener record and apply generated/fallback styles.
- Modify `scripts/art_library.gd` — define stable paths for the new asset family.
- Modify `art_source/manifests/main_menu.json` — describe all visual elements, state assets, prompts, bindings, and reference evidence.
- Modify `tests/test_main_menu.gd` — protect visual direction, control hierarchy, four-state styles, focus, and existing behavior.
- Create `assets/ui/generated/mm_greenhouse_record_panel.png` — gardener record panel.
- Create `assets/ui/generated/mm_greenhouse_account_plate.png` — account nameplate.
- Create `assets/ui/generated/mm_greenhouse_divider.png` — botanical archive divider.
- Create `assets/ui/generated/mm_greenhouse_badge.png` — small greenhouse/gardener emblem.
- Create `assets/ui/generated/mm_greenhouse_primary_{state}.png` — primary button states.
- Create `assets/ui/generated/mm_greenhouse_secondary_{state}.png` — directory-row states.
- Create `docs/superpowers/reports/2026-09-29-greenhouse-gardener-record-menu-verification.md` — stage-four comparison and correction record.

### Task 1: Lock the greenhouse-record UI contract

**Files:**
- Modify: `tests/test_main_menu.gd`
- Test: `tests/test_main_menu_runner.gd`

- [ ] **Step 1: Replace the ancient-scroll assertions with failing greenhouse-record assertions**

Add assertions to `test_home_button_visual_hierarchy()`:

```gdscript
expect(journal != null and journal.get_meta("visual_direction", "") == "greenhouse_gardener_record", "right menu must use the greenhouse gardener record direction")
expect(menu.find_child("GardenerRecordHeader", true, false) != null, "gardener record must expose its archive header")
expect(menu.find_child("GardenerBadge", true, false) != null, "gardener record must expose its greenhouse badge")
expect(menu.find_child("ArchiveDivider", true, false) != null, "gardener record must expose its botanical divider")
expect(primary.get_theme_stylebox("normal") is StyleBoxFlat, "missing generated assets must retain a readable primary fallback")
```

- [ ] **Step 2: Run the test and verify the old scroll implementation fails**

Run:

```powershell
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . -s tests/test_main_menu_runner.gd
```

Expected: failure naming `greenhouse_gardener_record` or a missing gardener record node.

- [ ] **Step 3: Commit the failing contract**

```powershell
git add tests/test_main_menu.gd
git commit -m "test: define greenhouse record menu contract"
```

### Task 2: Implement the readable fallback UI

**Files:**
- Modify: `scripts/main_menu.gd`
- Modify: `scripts/art_library.gd`
- Test: `tests/test_main_menu.gd`

- [ ] **Step 1: Add stable new asset constants without removing old constants**

Add to `scripts/art_library.gd`:

```gdscript
const UI_GREENHOUSE_RECORD_PANEL := "res://assets/ui/generated/mm_greenhouse_record_panel.png"
const UI_GREENHOUSE_ACCOUNT_PLATE := "res://assets/ui/generated/mm_greenhouse_account_plate.png"
const UI_GREENHOUSE_DIVIDER := "res://assets/ui/generated/mm_greenhouse_divider.png"
const UI_GREENHOUSE_BADGE := "res://assets/ui/generated/mm_greenhouse_badge.png"
const UI_GREENHOUSE_PRIMARY := "res://assets/ui/generated/mm_greenhouse_primary_{state}.png"
const UI_GREENHOUSE_SECONDARY := "res://assets/ui/generated/mm_greenhouse_secondary_{state}.png"
```

- [ ] **Step 2: Replace scroll-specific nodes and labels**

In `_show_home()`:

```gdscript
menu_panel.set_meta("visual_direction", "greenhouse_gardener_record")

var record_header := HBoxContainer.new()
record_header.name = "GardenerRecordHeader"

var header_title := _label("园丁记录", 18, Color("c9c5a5"))
header_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
record_header.add_child(header_title)

var badge := Label.new()
badge.name = "GardenerBadge"
badge.text = "✦"
badge.custom_minimum_size = Vector2(28, 28)
record_header.add_child(badge)

var divider := HSeparator.new()
divider.name = "ArchiveDivider"
```

Remove the `园丁手记 · 卷一`, `GardenerSeal`, `ChapterRule`, and `ancient_scroll` identifiers.

- [ ] **Step 3: Add project-matched native fallback styles**

Add focused helpers:

```gdscript
func _greenhouse_record_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0b1518ee")
	style.border_color = Color("756846")
	style.border_width_left = 2
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.set_corner_radius_all(5)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 14
	return style

func _greenhouse_button_style(fill: Color, edge: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.border_width_bottom = width
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style
```

Use these whenever `ArtLibrary.load_texture(path)` returns `null`.

- [ ] **Step 4: Run contract and layout tests**

Run:

```powershell
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . -s tests/test_main_menu_runner.gd
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . -s tests/test_menu_layout.gd
```

Expected: `MAIN MENU TESTS PASSED` and `MENU LAYOUT PASSED`.

- [ ] **Step 5: Capture the fallback UI from Godot**

```powershell
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --path . --write-movie 'tmp/main-menu-review/greenhouse-fallback.png' --fixed-fps 10 --quit-after 1 -s tests/main_menu_capture.gd
```

Expected: a readable right-side panel with no eastern scroll, seal, or plaque motifs.

- [ ] **Step 6: Commit the fallback implementation**

```powershell
git add scripts/main_menu.gd scripts/art_library.gd tests/test_main_menu.gd
git commit -m "feat: restyle menu as greenhouse gardener record"
```

### Task 3: Replace the main-menu MM manifest

**Files:**
- Modify: `art_source/manifests/main_menu.json`
- Test: `tests/test_mm_manifest.py`

- [ ] **Step 1: Disable the old scroll assets and add the new 12-asset family**

Use the following resource IDs and outputs:

```json
{
  "id": "greenhouse_record_panel",
  "kind": "panel",
  "generation": {"enabled": true, "provider": "mm-api", "model": "gpt-image-2", "transparent": false},
  "output": {"path": "res://assets/ui/generated/mm_greenhouse_record_panel.png", "size": [720, 1200], "mode": "nine_patch", "patch_margin": [72, 72, 72, 72]}
}
```

Add equivalent entries for `greenhouse_account_plate`, `greenhouse_divider`, `greenhouse_badge`, `greenhouse_primary_states`, and `greenhouse_secondary_states`. The state arrays must be `normal`, `hover`, `pressed`, `disabled`; prompts must explicitly require a clean central text-safe area and forbid scrolls, seals, plaques, Chinese ornamental motifs, letters, and symbols.

- [ ] **Step 2: Record original-project evidence in the style block**

Set `style.reference_images` to include:

```json
[
  "res://assets/backgrounds/ART_BG_MainMenu_Greenhouse.png",
  "res://tmp/main-menu-review/greenhouse-fallback00000000.png"
]
```

Use a prompt prefix that names the project evidence: abandoned Victorian greenhouse, botanical archive, oxidized brass, dark painted metal, broken glass, cool moonlight, restrained sunflower warmth, and low visual density.

- [ ] **Step 3: Validate and expand the generation plan**

```powershell
& 'C:\Users\mengmenglv\AppData\Local\Programs\Python\Python311\python.exe' aiskill/mm-tools/mm_manifest.py validate art_source/manifests/main_menu.json
& 'C:\Users\mengmenglv\AppData\Local\Programs\Python\Python311\python.exe' aiskill/mm-tools/mm_manifest.py plan art_source/manifests/main_menu.json
```

Expected: valid manifest and exactly twelve new output jobs, with no existing scroll path targeted.

- [ ] **Step 4: Run MM tool tests**

```powershell
& 'C:\Users\mengmenglv\AppData\Local\Programs\Python\Python311\python.exe' -m unittest tests.test_mm_manifest
```

Expected: all tests pass.

- [ ] **Step 5: Present the twelve-job plan and obtain explicit paid-generation confirmation**

Report the original-project style evidence, exact output list, provider/model, and confirmation that no current asset will be overwritten. Do not run generation in this step.

- [ ] **Step 6: Commit the validated manifest**

```powershell
git add art_source/manifests/main_menu.json tests/test_mm_manifest.py
git commit -m "feat: define greenhouse record MM assets"
```

### Task 4: Generate, verify, and bind the approved assets

**Files:**
- Create: `assets/ui/generated/mm_greenhouse_*.png`
- Modify: `scripts/main_menu.gd`
- Modify: `tests/test_main_menu.gd`

- [ ] **Step 1: Generate only after explicit confirmation**

```powershell
& 'sprite-gen\.venv\Scripts\python.exe' aiskill/mm-tools/mm_manifest.py generate art_source/manifests/main_menu.json --confirm
```

Expected: twelve PNGs and reports using `mm-api/gpt-image-2`, with no fallback provider.

- [ ] **Step 2: Verify output contracts**

```powershell
& 'C:\Users\mengmenglv\AppData\Local\Programs\Python\Python311\python.exe' aiskill/mm-tools/mm_manifest.py verify art_source/manifests/main_menu.json
```

Expected: `verified: art_source\manifests\main_menu.json`.

- [ ] **Step 3: Inspect every generated image before binding**

Reject and regenerate any asset containing text, eastern scroll geometry, seals, plaques, bright-gold fill, greenhouse scenery inside a button, or decoration inside the central 75% text-safe area.

- [ ] **Step 4: Bind the panel, account plate, divider, badge, and button states**

Use `_texture_style()` only after confirming `ArtLibrary.load_texture(path) != null`; otherwise retain the Task 2 fallback. Apply the account plate in `_account_entry_button()` and apply each button state with its matching state file.

- [ ] **Step 5: Update tests for generated-state binding**

After assets exist, assert:

```gdscript
expect(primary.get_theme_stylebox("normal") is StyleBoxTexture, "primary menu must bind the generated normal state")
expect(primary.get_theme_stylebox("hover") is StyleBoxTexture, "primary menu must bind the generated hover state")
expect(primary.get_theme_stylebox("normal") != primary.get_theme_stylebox("hover"), "primary menu states must use distinct textures")
```

- [ ] **Step 6: Run MM, menu, layout, and integration tests**

```powershell
& 'C:\Users\mengmenglv\AppData\Local\Programs\Python\Python311\python.exe' -m unittest tests.test_mm_manifest
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . -s tests/test_main_menu_runner.gd
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . -s tests/test_menu_layout.gd
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . -s tests/integration_smoke.gd
```

Expected: MM tests pass, both menu suites pass, and `INTEGRATION PASSED`.

- [ ] **Step 7: Commit generated assets and binding**

```powershell
git add assets/ui/generated/mm_greenhouse_*.png assets/ui/generated/mm_greenhouse_*.report.json scripts/main_menu.gd scripts/art_library.gd tests/test_main_menu.gd
git commit -m "feat: bind greenhouse gardener record artwork"
```

### Task 5: Run stage-four visual comparison

**Files:**
- Create: `docs/superpowers/reports/2026-09-29-greenhouse-gardener-record-menu-verification.md`

- [ ] **Step 1: Capture the final Godot main menu**

```powershell
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --path . --write-movie 'tmp/main-menu-review/greenhouse-final.png' --fixed-fps 10 --quit-after 1 -s tests/main_menu_capture.gd
```

- [ ] **Step 2: Compare against the approved design**

Record pass/fail for background color temperature, Victorian greenhouse material language, reduced gold area, sunflower focal priority, removal of eastern motifs, text safety, account-plate consistency, and visible four-state differences.

- [ ] **Step 3: Correct every failed comparison and rerun Tasks 3–5 as applicable**

Layout or hierarchy failures return to Task 2; prompt or asset failures return to Tasks 3–4. Recapture after every correction.

- [ ] **Step 4: Run final verification**

```powershell
& 'C:\Users\mengmenglv\AppData\Local\Programs\Python\Python311\python.exe' aiskill/mm-tools/mm_manifest.py verify art_source/manifests/main_menu.json
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . -s tests/test_main_menu_runner.gd
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . -s tests/test_menu_layout.gd
```

Expected: asset verification and both menu suites pass.

- [ ] **Step 5: Commit the comparison report**

```powershell
git add docs/superpowers/reports/2026-09-29-greenhouse-gardener-record-menu-verification.md
git commit -m "docs: verify greenhouse gardener record menu"
```
