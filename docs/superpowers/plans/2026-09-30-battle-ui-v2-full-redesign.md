# Battle UI V2 Full Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the complete battle UI visual skin and layout, including day/night HUD and battle modal screens, while preserving combat behavior, signals, and data contracts.

**Architecture:** Keep `Game` as the owner of combat state and `Hud` as the presentation/signals layer. Rebuild `Hud` around six visual states (`day`, `night`, `paused`, `mother_choice`, `victory`, `defeat`) and shared edge-anchored components. Generate transparent modular art into a V2 directory, bind it through a new manifest and texture helpers, then remove only battle-UI assets and layout branches with no remaining references.

**Tech Stack:** Godot 4 GDScript, existing HUD/radar/compass scripts, JSON art manifest, Python/Pillow derivation, sprite-gen with `gpt-image-2`, Godot headless tests and screenshot captures.

---

## File map and ownership

- Create `assets/ui/generated/battle_ui_v2/`: runtime PNGs and import metadata.
- Create `art_source/generated/battle_ui_v2/`: source PNGs, reports and prompts.
- Create `art_source/manifests/battle_ui_v2.json`: asset inventory, nine-patch margins, bindings and runtime text contracts.
- Create `art_source/process_battle_ui_v2.py`: deterministic alpha validation and source-to-runtime derivation.
- Modify `scripts/hud.gd`: V2 components and states while retaining public signals and update methods.
- Modify `scripts/game.gd` only for missing pause/result wiring; do not change combat rules.
- Modify `tests/test_battle_hud.gd`: six-state, fallback, modal and bounds assertions.
- Modify `tests/hud_capture.gd` and `tests/ui_state_capture.gd`: eight required visual captures.
- Create `tests/test_battle_ui_v2_art.py`: manifest paths, alpha, dimensions and provenance checks.
- Remove only after verification: unreferenced files under `assets/ui/generated/battle_hud/` and `art_source/generated/mm_tools/battle_hud/`; preserve shared assets and unrelated main-menu work.

## Task 1: Establish failing V2 contract tests

**Files:** `tests/test_battle_hud.gd`, `tests/test_battle_ui_v2_art.py`, optionally `tests/test_runner.gd`.

- [ ] **Step 1: Add failing state/node assertions.** Assert `Hud` exposes `set_visual_state(state: String)`, creates `BattleUiRoot`, `MotherStatusPanel`, `PhaseBanner`, `ResourcePanel`, `TacticalInstrumentFrame`, `PhaseActionTray`, `PrimaryActionButton`, `SelectionDetailPanel`, `NotificationBanner`, `MotherChoiceOverlay`, `PauseOverlay`, and `ResultOverlay`, while retaining current public buttons and signals.
- [ ] **Step 2: Add visibility and input-blocking assertions.** Use this exact scenario:
```gdscript
hud.set_visual_state("day")
expect(_visible(hud, "DayActionPanel"), "day actions visible")
expect(not _visible(hud, "NightHandPanel"), "night hand hidden in day")
hud.set_visual_state("night")
expect(_visible(hud, "NightHandPanel"), "night hand visible")
expect(not _visible(hud, "DayActionPanel"), "day actions hidden at night")
hud.show_result(true)
expect(_visible(hud, "ResultOverlay"), "result overlay visible")
expect(hud.find_child("ResultOverlay", true, false).mouse_filter == Control.MOUSE_FILTER_STOP, "result blocks input")
hud.hide_result()
expect(not _visible(hud, "ResultOverlay"), "result overlay hidden")
```
Also assert selection detail and notification start hidden and notifications have finite timeouts.
- [ ] **Step 3: Add `tests/test_battle_ui_v2_art.py`.** Load `art_source/manifests/battle_ui_v2.json`, enumerate runtime paths, assert existence, RGBA mode, at least one transparent pixel, declared dimensions, and `derived_by == "res://art_source/process_battle_ui_v2.py"`.
- [ ] **Step 4: Run the focused tests.** Run `godot --headless --path . --script res://tests/test_battle_hud.gd` and `python tests/test_battle_ui_v2_art.py`. Expected: new V2 state/node and manifest checks fail because implementation/files do not exist.

## Task 2: Create the V2 manifest and deterministic processor

**Files:** `art_source/manifests/battle_ui_v2.json`, `art_source/process_battle_ui_v2.py`, `tests/test_battle_ui_v2_art.py`.

- [ ] **Step 1: Define the manifest inventory.** Declare `compact_status_frame`, `phase_banner_frame`, `resource_panel_frame`, `phase_action_tray`, `selection_detail_frame`, `tactical_instrument_frame`, four primary-button states, `start_night_icon`, `sunburst_icon`, `pause_frame`, three mother-choice cards, `victory_frame`, `defeat_frame`, `victory_seal`, and `defeat_seal`. Include source/runtime paths, display sizes, patch margins and node bindings. Dynamic text, values, direction markers and costs must be `generation.enabled: false`. Use explicit provider `openai_image` and model `gpt-image-2`; never write credentials.
- [ ] **Step 2: Implement `process_battle_ui_v2.py`.** Provide `tight_crop(image, pad=8)`, `validate_rgba(image, path)`, `derive_asset(asset, source, output)`, `derive()`, and `main()`. Preserve alpha, reject missing/fully opaque sources, write only declared runtime outputs, and emit reports with source, runtime, dimensions, alpha and `derived_by`.
- [ ] **Step 3: Validate a temporary fixture.** Use a transparent 32×32 fixture outside runtime directories; verify missing and fully opaque files are rejected, then remove the fixture without adding it to Git.

## Task 3: Generate modular assets with sprite-gen

**Files:** `art_source/generated/battle_ui_v2/*.png`, reports/prompts, `assets/ui/generated/battle_ui_v2/*.png`.

- [ ] **Step 1: Resolve the image workflow with explicit provider.** Run sprite-gen's image workflow with the user-provided endpoint, model and key supplied only as process environment variables. Use `openai_image`, transparent PNG output, no defaults save, and never print the key.
- [ ] **Step 2: Generate the visual baseline.** Generate `compact_status_frame`, `phase_action_tray`, `primary_action_button_normal`, `tactical_instrument_frame`, `pause_frame`, and `victory_frame`. Inspect alpha, empty center, brass consistency and display-scale legibility; regenerate any pseudo-text, opaque, clipped or inconsistent result.
- [ ] **Step 3: Generate variants and modal assets.** Generate remaining button states, phase/resource/selection frames, two icons, three equal-size mother cards, defeat frame and both seals. Vary only approved route tints and emblems for cards.
- [ ] **Step 4: Derive and check.** Run `python art_source/process_battle_ui_v2.py` and `python tests/test_battle_ui_v2_art.py`; all declared runtime files must exist, be RGBA, preserve transparency, match dimensions and identify the processor.

## Task 4: Rebuild the HUD while preserving the public contract

**Files:** `scripts/hud.gd`, possibly `scripts/game.gd` and `scripts/art_library.gd`.

- [ ] **Step 1: Add V2 constants and texture helpers.** Add V2 root/manifest constants and a manifest texture loader returning `StyleBoxTexture` or `null`; every caller falls back to existing `StyleBoxFlat` styling when missing.
- [ ] **Step 2: Replace `_build_ui` with edge-anchored builders.** Build `BattleUiRoot`, status, phase, resources, tactical instrument, action tray, primary action, selection, notification, mother choice, pause and result layers. Keep signal declarations, field names used by `game.gd`, and public methods. Fit 1152×648: top panels within 96 px, instrument upper-right middle, tray centered at bottom, primary action bottom-right, no opaque full-width bar.
- [ ] **Step 3: Implement `set_visual_state(state: String) -> void`.** Day/night call existing phase layout. Paused/mother-choice/victory/defeat show blocking overlays while preserving underlying phase; closing a modal restores the prior day/night state. Unknown values return safely.
- [ ] **Step 4: Bind actions and runtime text.** Keep day `StartNightButton` → `wave_requested`, night `SunburstButton` → `sunburst_requested`, all plant/card/mulligan/restart/radar signals, distinct icons, and real health/energy/seed/timer/wave/enemy/cost values.
- [ ] **Step 5: Composite tactical layers.** Keep network radar and threat compass under one instrument; day hides threat marks, night shows both; preserve `update_network_radar`, `update_threat_compass`, `update_radar` and emphasis behavior.
- [ ] **Step 6: Implement modal families.** Refactor mother choices and results to V2 frames/cards; add `show_pause` and `hide_pause` if needed. Modal roots use `MOUSE_FILTER_STOP`; existing callbacks remain intact.

## Task 5: Extend captures and visual regression checks

**Files:** `tests/hud_capture.gd`, `tests/ui_state_capture.gd`, optionally `tests/battle_ui_v2_capture.gd`, `tests/test_battle_hud.gd`.

- [ ] **Step 1: Capture eight states** at 1152×648 into `output/imagegen/previews/battle_ui_v2/`: day, night, boss_night, resource_shortage, mother_choice, paused, victory and defeat. Inject state through existing HUD/game methods only.
- [ ] **Step 2: Add geometry checks** at 1152×648, 1280×720 and 1920×1080. Assert required controls are inside the viewport and these pairs do not overlap: MotherStatus/PhaseBanner, PhaseBanner/ResourcePanel, TacticalInstrument/ResourcePanel, PhaseActionTray/PrimaryAction, SelectionDetail/PhaseActionTray.
- [ ] **Step 3: Add fallback coverage.** Point the V2 loader at one missing test-only texture ID and assert a visible panel has non-null `StyleBoxFlat` and accepts input; restore the normal manifest path afterward.

## Task 6: Remove obsolete battle UI after migration

**Files:** unreferenced files under `assets/ui/generated/battle_hud/` and `art_source/generated/mm_tools/battle_hud/`; `art_source/manifests/battle_hud.json` only if no longer used.

- [ ] **Step 1: Prove references.** Run `rg -n "assets/ui/generated/battle_hud|art_source/generated/mm_tools/battle_hud|battle_hud/" scripts tests scenes art_source`. Every match must migrate to V2 or be explicitly retained historical evidence.
- [ ] **Step 2: Delete only proven-obsolete files.** Do not use a recursive wildcard against `assets/ui/generated`; do not touch current main-menu modifications.
- [ ] **Step 3: Re-run references and start Godot headless.** Expected: no runtime references to deleted files and no missing-resource errors.

## Task 7: Full verification and handoff

**Files:** implementation files above; optionally checked-in validation notes under `docs/superpowers/validation/`.

- [ ] **Step 1: Run focused Godot tests.**
```powershell
godot --headless --path . --script res://tests/test_battle_hud.gd
godot --headless --path . --script res://tests/test_game_flow.gd
godot --headless --path . --script res://tests/integration_smoke.gd
```
Each must exit 0 with no node, signal, layout or input-blocking failures.
- [ ] **Step 2: Run art tests.** Run `python tests/test_battle_ui_v2_art.py` and `python -m pytest tests/test_battle_hud_runtime_art.py -q`; migrate the old derivation test only when old files are intentionally removed.
- [ ] **Step 3: Review all eight screenshots.** Confirm open center, visible mother flower, left-top → phase → right resource/instrument → bottom action reading order, coherent day/night/modal materials and readable text.
- [ ] **Step 4: Inspect final diff.** Run `git status --short`, `git diff --check`, and `git diff -- scripts/hud.gd scripts/game.gd tests/test_battle_hud.gd art_source/manifests/battle_ui_v2.json`. Confirm main-menu changes are untouched and no credential, fixture or secret appears.
- [ ] **Step 5: Commit focused increments when Git is writable.** Use `test: define battle ui v2 contracts`, `feat: add battle ui v2 generated assets`, `feat: rebuild battle hud layout`, `test: add battle ui v2 captures`, and `chore: remove obsolete battle ui assets`; each commit passes its relevant checks.

## Plan self-review

- Spec coverage: Tasks 2–3 cover visual system and generation; Task 4 covers HUD, phases, modals and compatibility; Tasks 1 and 4 cover fallback; Task 5 covers screenshot acceptance; Task 6 covers safe deletion; Task 7 covers verification and credential hygiene.
- Placeholder scan: each asset, path, test command and deletion boundary is named; no unresolved implementation marker is used.
- Type consistency: `set_visual_state(state: String)`, `show_pause`, `hide_pause`, `show_result`, `hide_result`, `update_battle_state`, `update_network_radar`, and `update_threat_compass` are referenced consistently.
- Scope: work stays within battle UI presentation and tests; main menu, deck builder, combat rules and battlefield assets remain outside scope.

