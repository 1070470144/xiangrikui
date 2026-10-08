# Deck Builder Production UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the existing deck-builder presentation into a production-quality, project-consistent four-column collection UI, then generate and integrate a new lightweight botanical art set with multi-state Godot screenshot verification.

**Architecture:** Keep `DeckBuilderModel` and persistence behavior unchanged. Move card, deck-row, detail, cost-curve, toolbar, and action-bar presentation into stable named components with programmatic fallback styles; only after those components pass layout tests should the manifest describe exact-size visual assets and `mm-api/gpt-image-2` generation begin. Static art is applied through `ArtManifest`, while dynamic card frames and icons are selected by the card component from explicit manifest-backed runtime paths.

**Tech Stack:** Godot 4.7 GDScript, Control containers, StyleBoxFlat/StyleBoxTexture, existing `mm-tools` manifest schema v1, Python unittest, `mm-api/gpt-image-2`.

---

## File map

- Modify `scenes/deck_builder.tscn`: stable panel hierarchy, named anchors, production spacing and toolbar/footer controls.
- Modify `scripts/deck_card_view.gd`: complete card composition, fixed regions, fallback art, all visual states.
- Modify `scripts/deck_list_item.gd`: fixed-column current-deck row.
- Create `scripts/deck_detail_view.gd`: selected-card detail composition and action signal.
- Create `scripts/deck_cost_curve.gd`: fixed 1–8 cost slots and rule feedback.
- Modify `scripts/deck_builder.gd`: configure components instead of rebuilding anonymous detail/curve trees.
- Modify `scripts/art_manifest.gd`: preserve explicit static bindings and safe nine-patch margins.
- Modify `tests/test_deck_builder_ui.gd`: component contracts, layout invariants, state coverage and long-name tests.
- Create `tests/deck_builder_visual_capture.gd`: deterministic multi-state screenshots from Godot.
- Replace `art_source/manifests/deck_builder.json`: versioned production resource plan with new output names.
- Modify `tests/test_mm_manifest.py`: required asset IDs, exact output sizes and non-overwrite assertions.
- Create `docs/mm-tools-deck-builder-production-acceptance.md`: four-stage evidence and screenshot comparison.

### Task 1: Lock production layout contracts

**Files:**
- Modify: `tests/test_deck_builder_ui.gd`
- Modify: `scenes/deck_builder.tscn`

- [ ] **Step 1: Write failing scene-layout assertions**

Add assertions after scene instantiation:

```gdscript
var library_panel := page.get_node("Root/MainSplit/LibraryPanel") as PanelContainer
var sidebar := page.get_node("Root/MainSplit/Sidebar") as VBoxContainer
var grid := page.get_node("Root/MainSplit/LibraryPanel/Library/CardScroll/CardGrid") as GridContainer
expect(library_panel != null, "library content must have a dedicated visual surface")
expect(grid.columns == 4, "deck library must remain four columns")
expect(grid.get_theme_constant("h_separation") >= 8, "card columns need stable separation")
expect(sidebar.custom_minimum_size.x >= 350, "sidebar must preserve readable detail width")
```

- [ ] **Step 2: Run the Godot suite and verify the named panel assertion fails**

Run:

```powershell
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . -s tests/test_runner.gd
```

Expected: exit 1 with `LibraryPanel` missing.

- [ ] **Step 3: Replace the library VBox root with a stable panel hierarchy**

Use this named structure in `deck_builder.tscn`:

```text
MainSplit
├── LibraryPanel (PanelContainer)
│   └── Library (VBoxContainer)
│       ├── Tools (HBoxContainer, 36 px)
│       └── CardScroll
│           └── CardGrid (4 columns, 8/10 separation)
└── Sidebar (VBoxContainer, min width 350)
```

Apply fallback `StyleBoxFlat` resources in the scene: library background `#142126e8`, border `#6f6748`, 1 px border, 12 px corner radius and 14 px content margins. Keep top and bottom bars visible at 1152×648.

- [ ] **Step 4: Update every node path in `deck_builder.gd` and tests**

Change `$Root/MainSplit/Library/...` to `$Root/MainSplit/LibraryPanel/Library/...`. Run the suite and expect `TESTS PASSED`.

- [ ] **Step 5: Commit the layout surface**

```powershell
git add scenes/deck_builder.tscn scripts/deck_builder.gd tests/test_deck_builder_ui.gd
git commit -m "ui: add stable deck builder surfaces"
```

### Task 2: Rebuild the card as a complete component

**Files:**
- Modify: `scripts/deck_card_view.gd`
- Modify: `tests/test_deck_builder_ui.gd`

- [ ] **Step 1: Write failing card-region and state tests**

Instantiate locked, normal and blocked cards and assert:

```gdscript
for node_name in ["CostBadge", "ArtSurface", "NameLabel", "TagRow", "StatusRow", "ActionButton"]:
    expect(normal.find_child(node_name, true, false) != null, "card region missing: %s" % node_name)
expect((normal.find_child("ArtSurface", true, false) as Control).custom_minimum_size.y >= 76, "card art cannot be empty")
expect(locked.get_visual_state() == "locked", "locked card needs explicit state")
expect(blocked.get_visual_state() == "disabled", "blocked card needs explicit state")
expect(normal.custom_minimum_size == Vector2(158, 220), "card must fit four columns and two complete rows")
```

- [ ] **Step 2: Run the suite and verify missing named regions fail**

Expected: failures naming `CostBadge`, `ArtSurface`, `TagRow`, `StatusRow`, and `get_visual_state`.

- [ ] **Step 3: Implement fixed card regions**

Rebuild `configure` with one stable tree:

```text
DeckCardView
└── CardMargin
    └── CardColumn
        ├── ArtSurface (PanelContainer, 82 px)
        │   ├── ArtFallback (TextureRect or centered botanical glyph)
        │   └── CostBadge (PanelContainer + CostLabel)
        ├── NameLabel (26 px)
        ├── TagRow (24 px)
        ├── StatusRow (24 px)
        └── ActionButton (30 px)
```

Use existing plant textures from `ContentData` when an explicit art path exists; otherwise choose a deterministic project botanical emblem by card ID. Use `TextServer.AUTOWRAP_OFF`, `text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS`, and tooltip text for the full card name.

- [ ] **Step 4: Implement stable visual states**

Add:

```gdscript
func get_visual_state() -> String:
    if not unlocked: return "locked"
    if not blocked_reason.is_empty(): return "disabled"
    if selected_state: return "selected"
    return "hover" if hovered else "normal"
```

Each state changes only frame style, art modulation and status copy; it must not add/remove rows or change minimum size.

- [ ] **Step 5: Run tests and commit**

Run the full Godot suite and expect `TESTS PASSED`, then:

```powershell
git add scripts/deck_card_view.gd tests/test_deck_builder_ui.gd
git commit -m "ui: rebuild deck collection cards"
```

### Task 3: Add dedicated detail, deck-row and cost-curve components

**Files:**
- Create: `scripts/deck_detail_view.gd`
- Create: `scripts/deck_cost_curve.gd`
- Modify: `scripts/deck_list_item.gd`
- Modify: `scripts/deck_builder.gd`
- Modify: `scenes/deck_builder.tscn`
- Modify: `tests/test_deck_builder_ui.gd`

- [ ] **Step 1: Write failing component contracts**

Assert that `DeckDetailView` exposes `configure(card, unlocked, count, limit, seeds, blocked_reason)` and signal `action_requested(card_id)`, that each `DeckListItem` contains `CostLabel`, `NameLabel`, `CountLabel`, `RemoveButton`, and that `DeckCostCurve.configure(deck)` produces eight named `CostSlot1`–`CostSlot8` controls.

- [ ] **Step 2: Run tests and verify scripts/nodes are missing**

Expected: load failures for the two new scripts and missing fixed row columns.

- [ ] **Step 3: Implement `DeckDetailView`**

Use a stable `VBoxContainer` with named title, tag, art, rules, count and action nodes. Convert numeric card fields through `deck_builder_text.gd`; never render the prefix `效果数据：`. Keep a 12 px content margin and allow rules text to wrap vertically.

- [ ] **Step 4: Implement fixed-column `DeckListItem`**

Use an `HBoxContainer` with widths: cost 34 px, name expand-fill, count 40 px, remove 30 px. Keep a 30 px row height and emit existing signals without changing model behavior.

- [ ] **Step 5: Implement `DeckCostCurve`**

Create eight fixed slots. Each slot contains an expanding spacer, a bar with height `clampi(count * 6, 2, 30)`, and the cost number. Expose `configure(deck_ids)` and `set_validation(messages)`.

- [ ] **Step 6: Wire named components in the scene and controller**

Replace anonymous rebuilds in `refresh_detail` and `refresh_cost_curve` with:

```gdscript
$Root/MainSplit/Sidebar/DetailPanel/DeckDetailView.configure(...)
$Root/MainSplit/Sidebar/StatsPanel/DeckCostCurve.configure(model.draft)
```

- [ ] **Step 7: Run tests and commit**

```powershell
git add scripts/deck_detail_view.gd scripts/deck_cost_curve.gd scripts/deck_list_item.gd scripts/deck_builder.gd scenes/deck_builder.tscn tests/test_deck_builder_ui.gd
git commit -m "ui: structure deck details and statistics"
```

### Task 4: Apply production fallback styling before image generation

**Files:**
- Modify: `scenes/deck_builder.tscn`
- Modify: `scripts/deck_card_view.gd`
- Modify: `scripts/deck_detail_view.gd`
- Modify: `scripts/deck_list_item.gd`
- Modify: `scripts/deck_cost_curve.gd`
- Modify: `tests/deck_builder_visual_capture.gd`

- [ ] **Step 1: Add deterministic multi-state capture setup**

Capture five PNGs under `tmp/deck-builder-review/`: `default.png`, `selected.png`, `locked.png`, `full.png`, and `invalid.png`. Each capture must instantiate a fresh scene, apply a deterministic profile, set the desired selected/hover substitute state through a public component API, wait three frames and save the viewport image.

- [ ] **Step 2: Add fallback theme colors and typography**

Use these semantic defaults consistently:

```gdscript
const COLOR_SURFACE := Color("#142126e8")
const COLOR_SURFACE_RAISED := Color("#1b2c31f2")
const COLOR_TEXT := Color("#f1ead8")
const COLOR_MUTED := Color("#a8b2a3")
const COLOR_BORDER := Color("#746b4d")
const COLOR_FOCUS := Color("#d1b86b")
const COLOR_WARNING := Color("#d98b72")
```

Page title 28 px, card name 16 px, primary text 15–16 px, metadata 12–13 px. Do not use pure white or saturated gold for ordinary body text.

- [ ] **Step 3: Run capture and inspect all five PNGs**

Run:

```powershell
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --path . --resolution 1152x648 -s tests/deck_builder_visual_capture.gd
```

Gate: no empty art surface, floating text, clipped row, half card, default Godot control skin or unclear state. Fix the programmatic UI until this gate passes before editing the manifest.

- [ ] **Step 4: Run tests and commit**

```powershell
git add scenes/deck_builder.tscn scripts/deck_card_view.gd scripts/deck_detail_view.gd scripts/deck_list_item.gd scripts/deck_cost_curve.gd tests/deck_builder_visual_capture.gd
git commit -m "ui: establish production deck builder fallback"
```

### Task 5: Replace and validate the production art manifest

**Files:**
- Modify: `art_source/manifests/deck_builder.json`
- Modify: `tests/test_mm_manifest.py`
- Modify: `scripts/art_manifest.gd`

- [ ] **Step 1: Write failing manifest coverage and size tests**

Require versioned IDs: `production_background`, `library_surface`, `detail_surface`, `deck_list_surface`, `toolbar_surface`, `card_frame_common`, `card_frame_rare`, `card_frame_legendary`, `card_art_emblem`, `energy_badge`, `lock_icon`, `warning_icon`, `remove_icon`, `primary_button`, `secondary_button`, `cost_slot`, `cost_bar`, plus text entries. Assert card frames are `[316, 440]`, buttons use at least a 3:1 aspect ratio, and every nine-patch has four positive margins smaller than half its dimensions.

- [ ] **Step 2: Run focused tests and verify old manifest fails**

```powershell
& 'C:\Users\mengmenglv\AppData\Local\Programs\Python\Python311\python.exe' -m unittest tests.test_mm_manifest -v
```

Expected: missing production IDs and size contract failures.

- [ ] **Step 3: Rewrite the manifest with new non-overwriting paths**

Use output names ending in `_v2.png` under `res://art_source/generated/mm_tools/deck_builder/`. Set `style.reference_images` to the four local project evidence images from the design spec. The prompt prefix must specify lightweight botanical field-guide UI, low saturation blue-green surfaces, thin oxidized copper, sparse corner foliage, flat clean centers, no text, no heavy gold carving, no photorealistic object frame, and exact safe areas.

- [ ] **Step 4: Extend `ArtManifest` only for required binding types**

Support texture properties, stylebox state maps, explicit nine-patch margins and runtime text. Reject incompatible bindings with warnings; do not guess node paths.

- [ ] **Step 5: Validate, plan and run the programmatic UI gate**

```powershell
& 'C:\Users\mengmenglv\.codex\skills\sprite-gen\.venv\Scripts\python.exe' aiskill/mm-tools/mm_manifest.py validate art_source/manifests/deck_builder.json
& 'C:\Users\mengmenglv\.codex\skills\sprite-gen\.venv\Scripts\python.exe' aiskill/mm-tools/mm_manifest.py plan art_source/manifests/deck_builder.json
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . -s tests/test_runner.gd
```

Expected: all exit 0. Present the complete generation count, local style evidence, output paths and non-overwrite policy to the user. Stop for explicit confirmation before generation.

- [ ] **Step 6: Commit the validated plan**

```powershell
git add art_source/manifests/deck_builder.json tests/test_mm_manifest.py scripts/art_manifest.gd
git commit -m "art: plan production deck builder assets"
```

### Task 6: Generate, verify and publish the approved resources

**Files:**
- Generate: `art_source/generated/mm_tools/deck_builder/*_v2.png`
- Publish: `assets/ui/generated/deck_builder/*_v2.png`

- [ ] **Step 1: Generate only after explicit user confirmation**

```powershell
& 'C:\Users\mengmenglv\.codex\skills\sprite-gen\.venv\Scripts\python.exe' aiskill/mm-tools/mm_manifest.py generate art_source/manifests/deck_builder.json --confirm
```

Expected: fixed provider `mm-api`, model `gpt-image-2`, no overwrite and no key in output.

- [ ] **Step 2: Verify every generated output**

```powershell
& 'C:\Users\mengmenglv\.codex\skills\sprite-gen\.venv\Scripts\python.exe' aiskill/mm-tools/mm_manifest.py verify art_source/manifests/deck_builder.json
```

Expected: `verified`. Manually reject any image with text, excessive gold, a detailed scene in a nine-patch center, missing alpha or unsafe content margins even if file validation passes.

- [ ] **Step 3: Publish only validated final PNGs**

Copy final non-raw PNGs to `assets/ui/generated/deck_builder/` with the same `_v2` names, run Godot `--import`, and confirm all `.import` metadata appears. Do not copy raw images or reports into runtime assets.

- [ ] **Step 4: Switch manifest/component bindings to v2 resources**

Update explicit runtime paths only after all target resources pass verification. Missing assets must leave the programmatic fallback visible.

- [ ] **Step 5: Commit generated and runtime assets explicitly**

Stage only the v2 manifest, reports/source outputs required by project policy, runtime PNGs, imports and binding code. Never use `git add .`.

### Task 7: Multi-state final visual acceptance

**Files:**
- Modify: `docs/mm-tools-deck-builder-production-acceptance.md`
- Modify only implementation files required by observed differences.

- [ ] **Step 1: Run all automated verification**

```powershell
& 'C:\Users\mengmenglv\AppData\Local\Programs\Python\Python311\python.exe' -m unittest tests.test_mm_manifest -v
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . -s tests/test_runner.gd
& 'C:\Users\mengmenglv\.codex\skills\sprite-gen\.venv\Scripts\python.exe' aiskill/mm-tools/mm_manifest.py verify art_source/manifests/deck_builder.json
```

Expected: zero failures and verified outputs.

- [ ] **Step 2: Capture all five Godot states**

Run the visual capture script at 1152×648. Open each PNG and compare against the design spec for surfaces, typography, alignment, complete art, state clarity, non-stretched borders and project style.

- [ ] **Step 3: Correct every observed difference at its owning stage**

Component/layout defects return to Tasks 1–4. Prompt/resource defects return to Tasks 5–6 and require regeneration confirmation if another paid model call is needed. Re-run every later test and screenshot after correction.

- [ ] **Step 4: Write the four-stage acceptance record**

Record phase 1 layout/style evidence, phase 2 manifest/test output, phase 3 generated/verified/bound resources and phase 4 per-screenshot comparison. The final section must say `未处理差异：无` only when every screenshot gate is satisfied.

- [ ] **Step 5: Run final repository checks and commit verification fixes**

```powershell
git diff --check
git status --short
```

Stage only files belonging to this feature and commit with `fix: complete production deck builder acceptance` if verification required fixes.
