# Full-Screen Deck Builder Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the main-menu deck popup with a full-screen, collection-style deck builder that supports browsing all cards, direct unlocks, safe draft editing, deck statistics, and keyboard interaction.

**Architecture:** A small `DeckBuilderModel` owns pure deck/filter/unlock logic, while a dedicated `DeckBuilder` Control owns presentation and persistence callbacks. Reusable card and deck-row controls render state without duplicating rules. The main menu hosts the full-screen scene and remains the owner of the active profile and disk writes.

**Tech Stack:** Godot 4.7 GDScript, Control scenes, existing `ContentData`/profile storage, project-native test harness, `mm-tools` art manifest.

---

## File map

- Create `scripts/deck_builder_model.gd`: pure draft, validation, filtering, sorting, unlock, and auto-fill rules.
- Create `tests/test_deck_builder_model.gd`: model behavior and boundary tests.
- Create `scripts/deck_card_view.gd`: collection card rendering and input signals.
- Create `scripts/deck_list_item.gd`: compact current-deck row rendering and removal signals.
- Create `scripts/deck_builder.gd`: full-screen controller, state synchronization, dialogs, keyboard behavior, and profile callbacks.
- Create `scenes/deck_builder.tscn`: stable full-screen layout and named UI anchors.
- Create `tests/test_deck_builder_ui.gd`: scene structure, signal, interaction, and responsive-layout contracts.
- Modify `scripts/main_menu.gd`: remove the old popup builder and host the new scene.
- Modify `tests/test_main_menu.gd`: verify deck-builder entry and profile updates.
- Modify `tests/test_runner.gd`: register the two new suites.
- Create `art_source/manifests/deck_builder.json`: feature art inventory and explicit scene bindings.
- Create `tests/fixtures/deck_builder_manifest_expected.json`: stable asset-ID fixture.
- Modify `tests/test_mm_manifest.py`: validate deck-builder manifest coverage.

### Task 1: Extract a testable deck-builder model

**Files:**
- Create: `scripts/deck_builder_model.gd`
- Create: `tests/test_deck_builder_model.gd`
- Modify: `tests/test_runner.gd`

- [ ] **Step 1: Register a failing model test suite**

Add `res://tests/test_deck_builder_model.gd` to `SUITE_PATHS`, then create the suite with tests for draft validation, filtering, sorting, unlocks, and auto-fill:

```gdscript
extends RefCounted

const Model = preload("res://scripts/deck_builder_model.gd")
const ContentData = preload("res://scripts/content_data.gd")
var failures: Array[String] = []

func expect(value: bool, message: String) -> void:
	if not value: failures.append(message)

func run() -> Array[String]:
	var profile := {"meta_seeds": 40, "unlocked_cards": ContentData.STARTER_CARD_IDS.duplicate(), "selected_deck": []}
	var model = Model.new(profile)
	expect(model.get_visible_cards("night", "cost").all(func(card): return str(card.phase) in ["night", "any"]), "night filter must include night and universal cards")
	expect(model.try_unlock("card_time_stasis") == true, "affordable locked card must unlock")
	expect(model.meta_seeds == 5, "unlock must deduct its documented cost")
	model.clear_draft()
	expect(model.auto_fill(), "auto-fill must complete a legal deck")
	expect(model.validate_draft().is_empty(), "auto-filled deck must be valid")
	return failures
```

- [ ] **Step 2: Run the suite and verify the missing model fails**

Run:

```powershell
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . -s tests/test_runner.gd
```

Expected: exit 1 and `res://scripts/deck_builder_model.gd` cannot be loaded.

- [ ] **Step 3: Implement the minimal model API**

Create `scripts/deck_builder_model.gd` with this public surface:

```gdscript
extends RefCounted
class_name DeckBuilderModel

const ContentData = preload("res://scripts/content_data.gd")
var meta_seeds: int
var unlocked_cards: Array[String] = []
var saved_deck: Array[String] = []
var draft: Array[String] = []

func _init(profile: Dictionary) -> void:
	meta_seeds = maxi(0, int(profile.get("meta_seeds", 0)))
	for id in profile.get("unlocked_cards", []): unlocked_cards.append(str(id))
	for id in profile.get("selected_deck", []): saved_deck.append(str(id))
	draft = saved_deck.duplicate()

func validate_draft() -> Array[String]:
	var errors: Array[String] = []
	if draft.size() != ContentData.DECK_SIZE: errors.append("卡组需要 12 张卡牌")
	var counts := {}; var rare := 0; var legendary := 0
	for id in draft:
		var card := ContentData.get_card(id)
		if card.is_empty() or not unlocked_cards.has(id): errors.append("卡组包含无效或未解锁卡牌"); continue
		counts[id] = int(counts.get(id, 0)) + 1
		if counts[id] > int(card.get("copies_allowed", 1)): errors.append("%s 超出携带上限" % card.name)
		if card.rarity == "rare": rare += 1
		elif card.rarity == "legendary": legendary += 1
	if rare > 4: errors.append("稀有卡最多携带 4 张")
	if legendary > 1: errors.append("传奇卡最多携带 1 张")
	return errors
```

Also implement `get_visible_cards(phase_filter, sort_mode)`, `can_add(card_id)`, `add_card(card_id)`, `remove_card(card_id)`, `clear_draft()`, `restore_saved()`, `try_unlock(card_id)`, `auto_fill()`, `is_dirty()`, and `export_profile_patch()`. Sort ties by card ID so results are deterministic. Auto-fill iterates unlocked cards by ascending cost and ID until it reaches 12, skipping any addition rejected by `can_add`.

- [ ] **Step 4: Expand edge-case assertions and run tests**

Add assertions for 13th-card rejection, copy limits, four rare/one legendary totals, insufficient seeds, dirty state, restore, and stable sorting. Run the full test command and expect `TESTS PASSED`.

- [ ] **Step 5: Commit the model**

```powershell
git add scripts/deck_builder_model.gd tests/test_deck_builder_model.gd tests/test_runner.gd
git commit -m "feat: add deck builder model"
```

### Task 2: Build reusable card and deck-row controls

**Files:**
- Create: `scripts/deck_card_view.gd`
- Create: `scripts/deck_list_item.gd`
- Modify: `tests/test_deck_builder_ui.gd`
- Modify: `tests/test_runner.gd`

- [ ] **Step 1: Write failing component contracts**

Create `tests/test_deck_builder_ui.gd`, register it, and assert the scripts compile, expose `configure`, and emit explicit signals:

```gdscript
extends RefCounted
var failures: Array[String] = []
func expect(value: bool, message: String) -> void:
	if not value: failures.append(message)
func run() -> Array[String]:
	var card_script := load("res://scripts/deck_card_view.gd") as Script
	var row_script := load("res://scripts/deck_list_item.gd") as Script
	expect(card_script != null and card_script.can_instantiate(), "deck card view must compile")
	expect(row_script != null and row_script.can_instantiate(), "deck list item must compile")
	var card = card_script.new()
	expect(card.has_signal("selected") and card.has_signal("add_requested"), "card view must expose browse and add signals")
	var row = row_script.new()
	expect(row.has_signal("selected") and row.has_signal("remove_requested"), "deck row must expose browse and remove signals")
	card.free(); row.free()
	return failures
```

- [ ] **Step 2: Run tests and verify both missing scripts fail**

Run the full Godot test command. Expected: exit 1 with component load failures.

- [ ] **Step 3: Implement `DeckCardView`**

Use a `PanelContainer` root with signals and one `configure` method:

```gdscript
extends PanelContainer
class_name DeckCardView
signal selected(card_id: String)
signal add_requested(card_id: String)
var card_id := ""

func configure(card: Dictionary, unlocked: bool, count: int, limit: int, blocked_reason := "") -> void:
	card_id = str(card.id)
	tooltip_text = blocked_reason
	# Rebuild named Cost, ArtFallback, Name, Phase, Rarity, LockOverlay and AddButton children.
	# Use text/icon overlays for lock and blocked states; do not encode either state by color alone.
```

Handle left click as `selected`, double-click as `add_requested`, and make the named `AddButton` emit `add_requested`. Use a minimum size of `Vector2(142, 198)` so four cards fit the 1152×648 baseline.

- [ ] **Step 4: Implement `DeckListItem` and run tests**

Create a compact `HBoxContainer` with `configure(card, count)`, named labels, and a `RemoveButton`. Left click emits `selected`; button press and double-click emit `remove_requested`. Run the full suite and expect `TESTS PASSED`.

- [ ] **Step 5: Commit the components**

```powershell
git add scripts/deck_card_view.gd scripts/deck_list_item.gd tests/test_deck_builder_ui.gd tests/test_runner.gd
git commit -m "feat: add deck builder card controls"
```

### Task 3: Create the full-screen scene and responsive layout

**Files:**
- Create: `scenes/deck_builder.tscn`
- Create: `scripts/deck_builder.gd`
- Modify: `tests/test_deck_builder_ui.gd`

- [ ] **Step 1: Add a failing scene-structure test**

Load and instantiate `res://scenes/deck_builder.tscn`. Assert the following unique nodes exist: `TopBar`, `BackButton`, `SeedLabel`, `DeckCountLabel`, `UnsavedLabel`, `PhaseFilter`, `SortOption`, `CardScroll`, `CardGrid`, `DetailPanel`, `DeckScroll`, `DeckList`, `CostCurve`, `ValidationLabel`, `ClearButton`, `RestoreButton`, `AutoFillButton`, and `SaveButton`.

- [ ] **Step 2: Run tests and verify the scene is missing**

Run the full Godot suite. Expected: exit 1 and scene load failure.

- [ ] **Step 3: Create `deck_builder.tscn`**

Build this hierarchy with containers, anchors, and explicit size flags:

```text
DeckBuilder (Control, full rect)
├── Background (ColorRect, full rect)
├── PageMargin (MarginContainer, full rect, 24/20/24/20)
│   └── RootColumn (VBoxContainer)
│       ├── TopBar (HBoxContainer, 52 px)
│       ├── MainSplit (HSplitContainer, expand)
│       │   ├── LibraryColumn (VBoxContainer, stretch_ratio 1.65)
│       │   │   ├── LibraryTools (HBoxContainer)
│       │   │   └── CardScroll (ScrollContainer)
│       │   │       └── CardGrid (GridContainer, columns 4)
│       │   └── Sidebar (VBoxContainer, stretch_ratio 1.0)
│       │       ├── DetailPanel (PanelContainer, stretch_ratio 1.05)
│       │       ├── DeckScroll (ScrollContainer, stretch_ratio 0.8)
│       │       │   └── DeckList (VBoxContainer)
│       │       ├── CostCurve (HBoxContainer, 54 px)
│       │       └── ValidationLabel (Label)
│       └── BottomBar (HBoxContainer, 48 px)
└── DialogLayer (CanvasLayer)
```

Set the scene script to `deck_builder.gd`. Keep both scroll regions independent and disable horizontal scrolling.

- [ ] **Step 4: Implement a compile-safe controller shell**

Create signals `profile_patch_requested(patch: Dictionary)`, `save_deck_requested(deck: Array[String])`, and `back_requested`. Implement `setup(profile)`, cache all named nodes in `_ready`, and expose `get_model()` for tests. Do not add persistence here.

- [ ] **Step 5: Run tests and commit the layout**

Run the full suite and expect `TESTS PASSED`.

```powershell
git add scenes/deck_builder.tscn scripts/deck_builder.gd tests/test_deck_builder_ui.gd
git commit -m "feat: scaffold full-screen deck builder"
```

### Task 4: Wire browsing, details, draft editing, and statistics

**Files:**
- Modify: `scripts/deck_builder.gd`
- Modify: `tests/test_deck_builder_ui.gd`

- [ ] **Step 1: Write failing interaction tests**

After `setup(profile)`, call the public methods `select_card`, `request_add`, `request_remove`, `set_phase_filter`, and `set_sort_mode`. Assert card count changes, `UnsavedLabel` becomes visible, filters reduce `CardGrid`, and `CostCurve` contains one bucket per represented energy cost.

- [ ] **Step 2: Run tests and verify missing methods fail**

Run the full suite. Expected: exit 1 with invalid method calls.

- [ ] **Step 3: Implement refresh boundaries**

Implement focused methods rather than one monolithic rebuild:

```gdscript
func refresh_all() -> void:
	refresh_top_bar()
	refresh_library()
	refresh_detail()
	refresh_deck_list()
	refresh_cost_curve()
	refresh_actions()

func request_add(card_id: String) -> void:
	var reason := model.can_add(card_id)
	if reason.is_empty(): model.add_card(card_id); refresh_all()
	else: show_status(reason)
```

`refresh_library` must restore `CardScroll.scroll_vertical` after rebuilding. `refresh_deck_list` groups identical IDs and sorts by cost/name. `refresh_detail` produces readable labels from known numeric fields rather than inventing effects absent from `ContentData`.

- [ ] **Step 4: Implement keyboard focus behavior**

In `_unhandled_key_input`, map Enter to add the selected library card, Delete to remove the selected deck card, and Escape to `request_back`. Leave arrow traversal to Godot focus neighbors and assign deterministic focus neighbors when rebuilding the grid.

- [ ] **Step 5: Run tests and commit interactions**

Run the full suite and expect `TESTS PASSED`.

```powershell
git add scripts/deck_builder.gd tests/test_deck_builder_ui.gd
git commit -m "feat: add deck builder interactions"
```

### Task 5: Add unlocks, save safety, and exit confirmation

**Files:**
- Modify: `scripts/deck_builder.gd`
- Modify: `scripts/deck_builder_model.gd`
- Modify: `tests/test_deck_builder_model.gd`
- Modify: `tests/test_deck_builder_ui.gd`

- [ ] **Step 1: Write failing transactional tests**

Assert that unlock emits a profile patch only after confirmation, insufficient seeds never emit, failed persistence calls `rollback_unlock(card_id, prior_seed_count)`, invalid drafts never emit `save_deck_requested`, and dirty back navigation opens a three-action confirmation dialog.

- [ ] **Step 2: Run tests and verify transactional APIs are absent**

Run the full suite. Expected: exit 1 with missing confirmation and rollback methods.

- [ ] **Step 3: Implement confirmation flows**

Use `ConfirmationDialog` for unlock and a custom `AcceptDialog` with three explicit buttons for exit. Implement:

```gdscript
func confirm_unlock(card_id: String) -> void:
	var before := model.meta_seeds
	if not model.try_unlock(card_id): show_status("种子不足或卡牌不可解锁"); return
	pending_unlock = {"card_id": card_id, "before": before}
	profile_patch_requested.emit(model.export_profile_patch())

func report_profile_patch_result(success: bool) -> void:
	if not success and not pending_unlock.is_empty():
		model.rollback_unlock(pending_unlock.card_id, pending_unlock.before)
	pending_unlock.clear(); refresh_all()
```

Saving emits a duplicated `Array[String]` only when `validate_draft()` is empty. `report_deck_save_result(true)` calls `model.mark_saved()` and emits `back_requested`; failure keeps the draft and displays an error.

- [ ] **Step 4: Run tests and commit safe persistence behavior**

Run the full suite and expect `TESTS PASSED`.

```powershell
git add scripts/deck_builder.gd scripts/deck_builder_model.gd tests/test_deck_builder_model.gd tests/test_deck_builder_ui.gd
git commit -m "feat: add safe deck unlock and save flows"
```

### Task 6: Integrate the scene with the main menu profile owner

**Files:**
- Modify: `scripts/main_menu.gd`
- Modify: `tests/test_main_menu.gd`

- [ ] **Step 1: Replace old-contract tests with failing scene integration tests**

Assert that invoking `_show_deck_builder()` creates a node named `DeckBuilder`, that saving updates `selected_deck`, that an unlock patch updates `meta_seeds`/`unlocked_cards`, and that `back_requested` returns to `HomePage`.

- [ ] **Step 2: Run tests and verify the old popup fails the new contract**

Run the full suite. Expected: exit 1 because the old dynamic popup has no `DeckBuilder` scene root or persistence callbacks.

- [ ] **Step 3: Host the dedicated scene**

Preload `res://scenes/deck_builder.tscn`, instantiate it under `PageStack`, call `setup(get_local_profile())`, and connect its three signals. Use existing `_save_local_profile()` for both profile patches and deck saves, and report its success back to the builder. Change `_save_local_profile()` to return the `Error` from its storage operation if it currently returns void.

- [ ] **Step 4: Remove obsolete popup code**

Delete `deck_draft`, `_deck_column`, and the dynamic card-list body from `main_menu.gd`. Keep `_show_deck_builder` as the scene entry point used by the home button. Confirm no tests or production calls depend on `_deck_column`.

- [ ] **Step 5: Run tests and commit integration**

Run the full suite and expect `TESTS PASSED`.

```powershell
git add scripts/main_menu.gd tests/test_main_menu.gd
git commit -m "feat: integrate full-screen deck builder"
```

### Task 7: Add and validate the `mm-tools` art manifest

**Files:**
- Create: `art_source/manifests/deck_builder.json`
- Create: `tests/fixtures/deck_builder_manifest_expected.json`
- Modify: `tests/test_mm_manifest.py`

- [ ] **Step 1: Add a failing manifest coverage test**

Define the required IDs in the fixture: `deck_background`, `library_panel`, `detail_panel`, `deck_panel`, `card_frame_common`, `card_frame_rare`, `card_frame_legendary`, `lock_overlay`, `energy_badge`, `phase_badges`, `rarity_badges`, `action_button_states`, `cost_curve_ornament`, `page_title_text`, `seed_count_text`, `deck_count_text`, `card_name_text`, `card_rules_text`, and `validation_text`. Assert validation succeeds and the manifest ID set contains every fixture ID.

- [ ] **Step 2: Run the focused manifest test and verify failure**

Run:

```powershell
python -m unittest tests.test_mm_manifest -v
```

Expected: FAIL because `deck_builder.json` does not exist.

- [ ] **Step 3: Create the complete manifest**

Use schema version 1, scene `res://scenes/deck_builder.tscn`, root `DeckBuilder`, explicit node/property bindings, `mm-api`/`gpt-image-2` for enabled generation entries, and `generation.enabled: false` for all text. Bind card frames to the reusable card component node paths documented in each asset role; do not bake Chinese labels into images.

- [ ] **Step 4: Validate and expand the generation plan**

Run:

```powershell
& 'C:\Users\mengmenglv\AppData\Local\Programs\Python\Python311\python.exe' aiskill/mm-tools/mm_manifest.py validate art_source/manifests/deck_builder.json
& 'C:\Users\mengmenglv\AppData\Local\Programs\Python\Python311\python.exe' aiskill/mm-tools/mm_manifest.py plan art_source/manifests/deck_builder.json
```

Expected: both commands exit 0; the plan lists intended outputs without invoking the image API. Stop before `generate` and present the plan for user confirmation.

- [ ] **Step 5: Commit the manifest plan**

```powershell
git add art_source/manifests/deck_builder.json tests/fixtures/deck_builder_manifest_expected.json tests/test_mm_manifest.py
git commit -m "art: plan deck builder visual assets"
```

### Task 8: Final regression and visual verification

**Files:**
- Modify only files required by failures discovered in this task.

- [ ] **Step 1: Run all automated tests**

```powershell
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . -s tests/test_runner.gd
python -m unittest tests.test_mm_manifest -v
```

Expected: `TESTS PASSED` and all Python tests pass.

- [ ] **Step 2: Launch the game at the baseline resolution**

```powershell
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe' --path 'D:\MyData\GodotData\MyGame'
```

Verify at 1152×648: four library columns do not overlap; top and bottom bars remain visible; detail text is readable; library and deck scroll independently; locked/blocked states include text or icons; save stays disabled with a visible reason until the deck is legal.

- [ ] **Step 3: Exercise the persistence path manually**

Unlock one affordable card, leave and re-enter to verify it persists; add/remove cards and choose “continue editing”; then test “discard” and “save and return”. Confirm an unlock remains after discarding a deck draft.

- [ ] **Step 4: Inspect the final diff and commit any verification fixes**

Run `git diff --check` and `git status --short`. Do not include unrelated pre-existing changes. If verification required fixes, stage each path reported for this feature explicitly (never use `git add .`), then commit:

```powershell
git commit -m "fix: complete deck builder verification"
```

- [ ] **Step 5: Hand off the ungenerated art plan**

Report the manifest validate/plan output and explicitly ask whether to run `mm_manifest.py generate art_source/manifests/deck_builder.json --confirm`. Do not generate assets without that confirmation.
