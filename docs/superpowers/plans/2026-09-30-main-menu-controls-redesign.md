# Main Menu Controls Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the compressed main-menu controls with native-ratio greenhouse UI art for the primary button, secondary buttons, journal panel, and account plate.

**Architecture:** `sprite-gen` produces auditable source images and reports in `art_source/`; deterministic cutout and sizing publish runtime PNGs in `assets/ui/generated/`. `art_source/manifests/main_menu.json` remains the binding owner, while `scripts/main_menu.gd` owns runtime dimensions, behavior, and code-style fallbacks.

**Tech Stack:** Godot 4 GDScript, sprite-gen 2.2, GPT Image 2 through the configured OpenAI-compatible endpoint, Pillow from the sprite-gen virtual environment.

---

### Task 1: Lock the control aspect-ratio contract

**Files:**
- Modify: `tests/test_main_menu_art_contract.gd`
- Modify: `scripts/main_menu.gd:286-306`

- [ ] **Step 1: Write the failing contract assertions**

Add assertions requiring the runtime dimensions below:

```gdscript
var primary := menu.find_child("PrimaryStartButton", true, false) as Button
expect(primary.custom_minimum_size == Vector2(290, 64), "primary menu button must preserve the approved 290x64 ratio")
for node_name in ["DeckBuilderButton", "NightRecordsButton", "CodexButton", "SettingsButton"]:
	var secondary := menu.find_child(node_name, true, false) as Button
	expect(secondary.custom_minimum_size == Vector2(290, 52), "%s must preserve the approved 290x52 ratio" % node_name)
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```powershell
& $godot --headless --path . --script tests/test_main_menu_art_contract.gd
```

Expected: failure because the current dimensions are `290×53` and `290×43`.

- [ ] **Step 3: Apply the approved runtime dimensions**

Set:

```gdscript
primary.custom_minimum_size = Vector2(290, 64)
secondary.custom_minimum_size = Vector2(290, 52)
```

- [ ] **Step 4: Re-run the contract test**

Expected: the dimension assertions pass; art-file assertions may remain red until Tasks 2 and 3.

### Task 2: Generate native-ratio greenhouse controls

**Files:**
- Create: `art_source/main_menu_primary_v2_prompt.txt`
- Create: `art_source/main_menu_secondary_v2_prompt.txt`
- Create: `art_source/main_menu_panel_v2_prompt.txt`
- Create: `art_source/main_menu_account_v2_prompt.txt`
- Create: `art_source/main_menu_*_v2.generated.png`
- Create: `art_source/main_menu_*_v2.report.json`

- [ ] **Step 1: Write the four production prompts**

Each prompt must specify one isolated asset, no text or symbols, the exact target aspect ratio, a clean center safe area, matching dark-green glass and restrained brass botanical corners, and a uniform removable background.

- [ ] **Step 2: Generate each source with the explicit provider**

Run for each prompt/output pair:

```powershell
$env:SPRITE_GEN_MM_API_BASE='https://newapi.oairegbox.cc'
$env:SPRITE_GEN_MM_API_MODEL='gpt-image-2'
& 'C:\Users\mengmenglv\.codex\skills\sprite-gen\.venv\Scripts\sprite-gen.exe' gen --provider mm-api --model gpt-image-2 --prompt-file $prompt --out $output --report $report
```

The API key must remain process-local in `SPRITE_GEN_MM_API_KEY`; never write it to prompts, reports, source files, or Git.

- [ ] **Step 3: Inspect all four generated sources**

Reject any source containing text, multiple stacked controls, perspective distortion, asymmetric edge damage, or a second greenhouse scene inside the journal panel.

- [ ] **Step 4: Remove the uniform backgrounds through sprite-gen**

Run:

```powershell
& 'C:\Users\mengmenglv\.codex\skills\sprite-gen\.venv\Scripts\sprite-gen.exe' cutout $input --out $cutout --key white --white-check
```

Expected: RGBA output with non-zero transparent coverage and verification composites.

### Task 3: Publish runtime images and bind them

**Files:**
- Create: `assets/ui/generated/mm_greenhouse_primary_v2_{normal,hover,pressed,disabled}.png`
- Create: `assets/ui/generated/mm_greenhouse_secondary_v2_{normal,hover,pressed,disabled}.png`
- Create: `assets/ui/generated/mm_greenhouse_record_panel_v2.png`
- Create: `assets/ui/generated/mm_greenhouse_account_plate_v2.png`
- Modify: `art_source/manifests/main_menu.json`
- Modify: `scripts/main_menu.gd`

- [ ] **Step 1: Crop transparent bounds and size without aspect distortion**

Publish exact sizes:

```text
primary states:   580×128
secondary states: 580×104
panel:             692×1012
account plate:     556×116
```

Use proportional resize followed only by transparent padding; do not stretch either axis independently.

- [ ] **Step 2: Derive interaction states from one accepted base per button family**

Use identical alpha masks for all states. Apply brightness/saturation only:

```text
normal   brightness 0.92, saturation 0.92
hover    brightness 1.10, saturation 1.05
pressed  brightness 0.74, saturation 0.88
disabled brightness 0.52, saturation 0.55, alpha multiplier 0.72
```

- [ ] **Step 3: Update the manifest bindings**

Bind the v2 paths to `PrimaryStartButton`, the four secondary buttons, `MenuJournal`, and `AccountEntry`. Use patch margins measured from the final files, preserving at least 60% central stretchable width for buttons and 70% central stretchable area for panel/plate.

- [ ] **Step 4: Keep code fallbacks visually compatible**

Set the fallback panel/account styles to dark translucent green, one-pixel muted brass borders, 8–10 px corner radius, and no opaque scene texture.

- [ ] **Step 5: Remove retired v1 runtime images**

Delete only files whose names match the replaced main-menu families after confirming no remaining `rg` reference. Do not delete HUD or deck-builder shared UI art.

### Task 4: Verify import, layout, and interactions

**Files:**
- Modify: `tests/test_main_menu_art_contract.gd`
- Use: `tests/test_menu_layout.gd`
- Use: `tests/main_menu_capture.gd`

- [ ] **Step 1: Extend the art contract test**

Assert exact PNG dimensions, RGBA mode, transparent coverage, identical state alpha bounds, manifest bindings, and runtime control dimensions.

- [ ] **Step 2: Run Godot import and focused tests**

Run:

```powershell
& $godot --headless --path . --editor --quit
& $godot --headless --path . --script tests/test_main_menu_art_contract.gd
& $godot --headless --path . --script tests/test_menu_layout.gd
```

Expected: both tests exit 0 with their PASS messages and no missing-resource warnings.

- [ ] **Step 3: Capture the runtime menu**

Run:

```powershell
& $godot --headless --path . --script tests/main_menu_capture.gd
```

Inspect the screenshot for uncompressed corners, consistent button width, readable text, a non-scenic journal background, and a styled account plate.

- [ ] **Step 4: Run the broader menu regression suite**

Run the existing main-menu runner and confirm start, deck, records, codex, settings, account switching, keyboard focus, and Escape navigation remain functional.

