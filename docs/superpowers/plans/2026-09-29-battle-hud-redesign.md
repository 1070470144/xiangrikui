# Battle HUD Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the battle HUD as a low-obstruction, edge-anchored day/night interface with one tactical instrument, one phase action tray, contextual details, and verified `mm-tools` art bindings.

**Architecture:** Keep `Game.get_hud_battle_state()` and all existing HUD signals stable. Recompose the programmatic Godot `Control` tree inside `scripts/hud.gd`, combine network and threat displays in one anchored frame, and preserve temporary `StyleBoxFlat` fallbacks until generated assets pass manifest verification. The four mandatory `mm-tools` stages remain explicit: temporary layout and behavior, manifest/test gate, confirmed image generation and runtime integration, then screenshot comparison.

**Tech Stack:** Godot 4.7.2, GDScript, programmatic `Control` UI, JSON art manifest, Python 3.11 manifest tooling, `mm-api/gpt-image-2`, headless tests and runtime screenshot capture.

---

## File map

- `scripts/hud.gd` — owns HUD construction, phase visibility, contextual feedback and manifest application.
- `scripts/threat_compass.gd` — draws only the threat overlay used inside the unified tactical instrument; change only if independent visibility cannot be expressed by its current API.
- `tests/test_battle_hud.gd` — executable layout, behavior, compatibility and viewport contracts.
- `tests/ui_state_capture.gd` — deterministic day/night/boss/low-resource/selection/notification capture states.
- `art_source/manifests/battle_hud.json` — complete generated and runtime visual inventory with explicit node bindings.
- `docs/superpowers/validation/2026-09-29-battle-hud-redesign.md` — stage evidence, screenshots and final difference log.
- `art_source/generated/mm_tools/battle_hud/` — generated PNGs and reports; never overwrite unrelated user assets.

### Task 1: Lock the structural and responsive contracts

**Files:**
- Modify: `tests/test_battle_hud.gd`
- Test: `tests/test_battle_hud.gd`

- [ ] **Step 1: Add failing structure assertions**

Extend the required node list with `TacticalInstrumentFrame`, `PhaseActionTray`, `SelectionDetailPanel`, and `PrimaryActionButton`. Assert that `SelectionDetailPanel` and `NotificationBanner` start hidden, both radar layers are descendants of `TacticalInstrumentFrame`, and the legacy `NetworkRadarFrame`, `ThreatCompassFrame`, `StartNightButton`, and `SunburstButton` names remain discoverable for compatibility.

- [ ] **Step 2: Add failing phase assertions**

After `set_phase_layout("day")`, assert deployment controls are visible, combat hand and threat overlay are hidden, and `PrimaryActionButton` represents start-night. After `set_phase_layout("night")`, assert the same tray position is retained, the combat hand and threat overlay are visible, and the primary action represents sunburst.

- [ ] **Step 3: Add failing responsive geometry assertions**

For 1152×648, 1280×720, and 1920×1080, calculate anchored rectangles and assert all stable anchors fit the viewport, the top status groups do not overlap, the tactical instrument does not overlap the resource panel, and the phase tray does not overlap the primary action.

- [ ] **Step 4: Run the suite and confirm the new contract fails**

```powershell
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . -s tests/test_runner.gd
```

Expected: `test_battle_hud` reports missing unified-layout nodes or incorrect visibility/geometry; no parser error.

- [ ] **Step 5: Commit the failing contract**

```powershell
git add tests/test_battle_hud.gd
git commit -m "test: define redesigned battle HUD contract"
```

### Task 2: Build the edge-anchored temporary HUD

**Files:**
- Modify: `scripts/hud.gd`
- Test: `tests/test_battle_hud.gd`

- [ ] **Step 1: Replace the stable top anchors**

Rebuild `MotherStatusPanel` as a compact 300×82 top-left unit, `PhaseBanner` as a 320×76 top-center two-line unit, and `ResourcePanel` as a 292×58 top-right unit. Retain `mother_health_value`, `phase_label`, `wave_label`, `timer_label`, `enemy_count_label`, `energy_value`, and `seed_label` references so `update_battle_state()` remains the sole public update path.

- [ ] **Step 2: Create the unified tactical instrument**

Create `TacticalInstrumentFrame` at the right edge below resources. Parent `NetworkRadarFrame` and `ThreatCompassFrame` inside it with identical full-frame geometry; keep `radar` interactive and set the threat overlay to ignore mouse input. Day mode hides the threat overlay; night mode shows both layers without moving the instrument.

- [ ] **Step 3: Create one phase action tray**

Create `PhaseActionTray` at bottom center and parent `DayActionPanel` and `NightHandPanel` within it. Both panels use the same anchors and only the current phase panel is visible. Keep the existing deployment buttons, repair behavior, combat-card emissions, and content-driven hand width; cap the four-card tray so its right edge cannot collide with the primary action.

- [ ] **Step 4: Create the contextual and primary controls**

Rename/rebuild the lower-left panel as `SelectionDetailPanel`, hidden by default, with `SelectionPanel` retained as a compatibility child. Create a right-bottom `PrimaryActionButton` container hosting the existing `StartNightButton` and `SunburstButton` in the same rectangle. Keep their separate signals and manifest-bindable node names.

- [ ] **Step 5: Make feedback state-driven**

Update `set_phase_layout()` to switch only phase children; do not move stable anchors. Update `update_battle_state()` so low sunburst energy dims the sunburst control and colors only `SunburstCostLabel` dark red. Keep `show_message()` as a four-second transient banner and add `show_selection_detail(title, detail)` plus `hide_selection_detail()` without introducing gameplay dependencies.

- [ ] **Step 6: Run the HUD and regression suites**

```powershell
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . -s tests/test_runner.gd
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . -s tests/integration_smoke.gd
```

Expected: `TESTS PASSED` and `INTEGRATION PASSED`.

- [ ] **Step 7: Commit the functional temporary UI**

```powershell
git add scripts/hud.gd tests/test_battle_hud.gd
git commit -m "feat: restructure battle HUD layout"
```

### Task 3: Complete and validate the battle HUD manifest

**Files:**
- Modify: `art_source/manifests/battle_hud.json`
- Modify: `tests/test_mm_manifest.py`
- Test: `tests/test_mm_manifest.py`

- [ ] **Step 1: Strengthen the checked-in manifest test**

Require IDs `primary_action_button`, `phase_action_tray`, `compact_status_frame`, `tactical_instrument_frame`, `start_night_icon`, `sunburst_icon`, `phase_title`, `resource_text`, and `selection_detail_text`. Assert generated state assets use `mm-api`, `gpt-image-2`, transparent output where appropriate, and explicit nodes under the redesigned tree.

- [ ] **Step 2: Run the Python test and confirm failure**

```powershell
& 'C:\Users\mengmenglv\AppData\Local\Programs\Python\Python311\python.exe' -m unittest tests.test_mm_manifest -v
```

Expected: failure listing missing redesigned HUD asset IDs.

- [ ] **Step 3: Rewrite the manifest inventory**

Set `style.reference_images` to the two checked-in runtime screenshots, the design specification, and the two commercial reference URLs. Define generated assets for the four-state primary button, tray frame, status frame, tactical frame, start-night icon, and sunburst icon. Define every Godot-rendered label as `generation.enabled: false`; bind all assets to explicit paths rooted at `BattleHudRoot`.

- [ ] **Step 4: Validate and plan the manifest**

```powershell
& 'C:\Users\mengmenglv\AppData\Local\Programs\Python\Python311\python.exe' aiskill/mm-tools/mm_manifest.py validate art_source/manifests/battle_hud.json
& 'C:\Users\mengmenglv\AppData\Local\Programs\Python\Python311\python.exe' aiskill/mm-tools/mm_manifest.py plan art_source/manifests/battle_hud.json
& 'C:\Users\mengmenglv\AppData\Local\Programs\Python\Python311\python.exe' -m unittest tests.test_mm_manifest -v
```

Expected: validation succeeds, plan lists only the intended HUD generation jobs, and Python tests pass.

- [ ] **Step 5: Run the temporary UI runtime gate**

```powershell
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . --quit-after 5
```

Expected: exit code 0 with no parser or invalid-node binding error. Record the expanded job count, paths, sizes, style evidence and overwrite status; ask the user to approve this exact generation plan before Task 4.

- [ ] **Step 6: Commit the validated manifest**

```powershell
git add art_source/manifests/battle_hud.json tests/test_mm_manifest.py
git commit -m "feat: define battle HUD art manifest"
```

### Task 4: Generate, verify, and bind approved art

**Files:**
- Create: `art_source/generated/mm_tools/battle_hud/*.png`
- Create: `art_source/generated/mm_tools/battle_hud/*.report.json`
- Modify: `scripts/hud.gd` only if a verified binding needs a corrected explicit node path
- Modify: `docs/superpowers/validation/2026-09-29-battle-hud-redesign.md`

- [ ] **Step 1: Stop unless the user approved the exact Task 3 plan**

Do not infer approval from design approval. Confirm job count, provider/model, destinations and that no existing file will be overwritten.

- [ ] **Step 2: Generate through the fixed provider**

```powershell
& 'C:\Users\mengmenglv\AppData\Local\Programs\Python\Python311\python.exe' aiskill/mm-tools/mm_manifest.py generate art_source/manifests/battle_hud.json --confirm
```

Expected: every job uses `mm-api/gpt-image-2`; reports contain no authorization header or API key.

- [ ] **Step 3: Verify every output**

```powershell
& 'C:\Users\mengmenglv\AppData\Local\Programs\Python\Python311\python.exe' aiskill/mm-tools/mm_manifest.py verify art_source/manifests/battle_hud.json
```

Expected: dimensions and alpha requirements pass for every target.

- [ ] **Step 4: Import and exercise runtime binding**

```powershell
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --editor --path . --quit-after 5
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . -s tests/test_runner.gd
```

Expected: imports complete, `ArtManifest.apply_file()` resolves every explicit binding, and `TESTS PASSED`.

- [ ] **Step 5: Commit generated and integrated assets**

```powershell
git add art_source/generated/mm_tools/battle_hud art_source/manifests/battle_hud.json scripts/hud.gd docs/superpowers/validation/2026-09-29-battle-hud-redesign.md
git commit -m "feat: integrate generated battle HUD art"
```

### Task 5: Capture key states and close the four-stage comparison gate

**Files:**
- Modify: `tests/ui_state_capture.gd`
- Create: `output/imagegen/previews/battle-hud-*.png`
- Modify: `docs/superpowers/validation/2026-09-29-battle-hud-redesign.md`

- [ ] **Step 1: Add deterministic capture states**

Support `day`, `night`, `boss`, `low_resource`, `selection`, and `notification`. Each state must call the public HUD update methods with fixed data; `selection` calls `show_selection_detail()`, and `notification` calls `show_message()`.

- [ ] **Step 2: Capture all six states at 1152×648**

Use the existing Godot movie-frame capture workflow, writing stable PNG names under `output/imagegen/previews/`. Repeat day and night at 1280×720 and 1920×1080 or record equivalent viewport evidence in the automated geometry test.

- [ ] **Step 3: Write the comparison report**

For each screenshot, record compliance or difference against: stable information hierarchy, day/night operation filtering, central battlefield clearance, original art direction, adopted commercial-case principles, manifest assets and bindings, and responsive limits. Include every correction and its rerun evidence; leave no unresolved difference.

- [ ] **Step 4: Run final verification**

```powershell
& 'C:\Users\mengmenglv\AppData\Local\Programs\Python\Python311\python.exe' aiskill/mm-tools/mm_manifest.py validate art_source/manifests/battle_hud.json
& 'C:\Users\mengmenglv\AppData\Local\Programs\Python\Python311\python.exe' aiskill/mm-tools/mm_manifest.py verify art_source/manifests/battle_hud.json
& 'C:\Users\mengmenglv\AppData\Local\Programs\Python\Python311\python.exe' -m unittest tests.test_mm_manifest -v
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . -s tests/test_runner.gd
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . -s tests/integration_smoke.gd
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . --quit-after 5
```

Expected: all manifest, Python, Godot and startup checks pass with no unhandled runtime error.

- [ ] **Step 5: Commit final evidence**

```powershell
git add tests/ui_state_capture.gd output/imagegen/previews docs/superpowers/validation/2026-09-29-battle-hud-redesign.md
git commit -m "test: verify redesigned battle HUD states"
```
