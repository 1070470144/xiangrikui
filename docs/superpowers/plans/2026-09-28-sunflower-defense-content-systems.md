# Sunflower Defense Content Systems Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement every non-UI system defined by `Design/Sunflower-Defense-Content-Data.md`: expanded units, mother evolution, consumable combat deck, retreat/extraction, meta seeds, card unlocks, capped mother growth, persistence, and seven-night integration.

**Architecture:** Keep static content in one read-only data module, and place mutable rules in focused `RefCounted` models that can be tested without a scene tree. Scene scripts consume those models: `Game` orchestrates the run, `MotherFlower` executes mother abilities, `Plant` and `Enemy` execute unit behaviors, and the profile model persists account progression. UI is intentionally excluded; every choice and action is exposed through callable methods and signals for later UI binding.

**Tech Stack:** Godot 4.7, GDScript, headless SceneTree tests.

---

### Task 1: Static content catalog

**Files:**
- Create: `scripts/content_data.gd`
- Create: `tests/test_content_data.gd`
- Modify: `tests/test_runner.gd`

- [ ] **Step 1: Write the failing catalog test**

Test exact counts, unique IDs, deck restrictions, six flowers, ten enemies, three mother paths, fifty-four upgrades, twenty-four cards, and five-level meta tracks.

```gdscript
func test_catalog_counts() -> void:
    var data := _load_script("res://scripts/content_data.gd")
    expect(data.FLOWERS.size() == 6, "catalog must define six flowers")
    expect(data.ENEMIES.size() == 10, "catalog must define ten enemies")
    expect(data.MOTHER_PATHS.size() == 3, "catalog must define three mother paths")
    expect(data.MOTHER_UPGRADES.size() == 54, "catalog must define fifty-four mother upgrades")
    expect(data.COMBAT_CARDS.size() == 24, "catalog must define twenty-four combat cards")
```

- [ ] **Step 2: Run the test and verify RED**

Run: `Godot --headless --path . -s tests/test_runner.gd`  
Expected: FAIL because `content_data.gd` does not exist.

- [ ] **Step 3: Implement `ContentData`**

Define dictionaries keyed by stable IDs and helper methods:

```gdscript
static func get_flower(id: String) -> Dictionary
static func get_enemy(id: String) -> Dictionary
static func get_card(id: String) -> Dictionary
static func get_mother_path(id: String) -> Dictionary
static func get_mother_upgrade(id: String) -> Dictionary
static func get_next_mother_choices(path_id: String, branch_ranks: Dictionary) -> Array[String]
```

All numeric values must match the content document.

- [ ] **Step 4: Run the suite and verify GREEN**

Expected: catalog tests pass and existing tests remain green.

### Task 2: Meta progression and extraction model

**Files:**
- Create: `scripts/progression.gd`
- Create: `tests/test_progression.gd`
- Modify: `tests/test_runner.gd`

- [ ] **Step 1: Write failing progression tests**

Cover initial seeds not being extractable, safe retreat at 100%, failure at 10% with minimum one, victory at 100%, unlock costs, deck validation, and five-level growth caps.

```gdscript
func test_seed_extraction() -> void:
    var p := Progression.new()
    p.start_run(5)
    expect(p.get_extractable_seeds() == 0, "initial seeds must not be extractable")
    p.gain_run_seeds(3)
    expect(p.get_extractable_seeds() == 3, "earned seeds must be extractable")
    expect(p.settle_failure() == 1, "failure must return ten percent with minimum one")
```

- [ ] **Step 2: Verify RED**

Expected: FAIL because `Progression` is missing.

- [ ] **Step 3: Implement the model**

Required API:

```gdscript
func start_run(starting_seeds: int) -> void
func gain_run_seeds(amount: int) -> int
func spend_run_seeds(amount: int) -> bool
func get_extractable_seeds() -> int
func settle_retreat() -> int
func settle_failure() -> int
func settle_victory() -> int
func unlock_card(card_id: String) -> bool
func upgrade_mother(track_id: String) -> bool
func validate_deck(deck: Array[String]) -> bool
func export_profile() -> Dictionary
func import_profile(profile: Dictionary) -> void
```

- [ ] **Step 4: Verify GREEN**

Expected: progression tests and full suite pass.

### Task 3: Mother evolution state and mother abilities

**Files:**
- Create: `scripts/mother_evolution.gd`
- Create: `tests/test_mother_evolution.gd`
- Modify: `scripts/mother_flower.gd`
- Modify: `tests/test_runner.gd`

- [ ] **Step 1: Write failing evolution tests**

Test first-day path choices, locked path, three next branch choices, sequential prerequisites, six-upgrade limit, reset, and representative effects for all three paths.

```gdscript
func test_branch_choices_advance_sequentially() -> void:
    var state := MotherEvolution.new()
    state.choose_path("dawn_pulse")
    expect(state.get_choices() == ["mother_charge_01", "mother_quelling_01", "mother_morningstar_01"], "first ranks must be offered")
    expect(state.choose_upgrade("mother_charge_01"), "valid upgrade must apply")
    expect(state.get_choices()[0] == "mother_charge_02", "selected branch must advance")
```

- [ ] **Step 2: Verify RED**

Expected: FAIL because the evolution model is missing.

- [ ] **Step 3: Implement evolution state**

Required API:

```gdscript
func reset() -> void
func get_choices() -> Array[String]
func choose_path(path_id: String) -> bool
func choose_upgrade(upgrade_id: String) -> bool
func has_upgrade(upgrade_id: String) -> bool
func get_modifier(key: String, default_value: float = 0.0) -> float
func export_state() -> Dictionary
```

- [ ] **Step 4: Extend `MotherFlower`**

Add configured maximum health, shields, damage reduction, night regeneration, auto-attack/root-whip/dawn-pulse timers, incoming-damage hooks, and signals for mother-originated attack/pulse/sunburst effects. No UI calls are allowed in this class.

- [ ] **Step 5: Verify GREEN**

Expected: evolution and mother behavior tests pass.

### Task 4: Six plants and ten enemies

**Files:**
- Modify: `scripts/plant.gd`
- Modify: `scripts/enemy.gd`
- Modify: `scripts/game.gd`
- Create: `tests/test_expanded_units.gd`
- Modify: `tests/test_runner.gd`

- [ ] **Step 1: Write failing unit tests**

Test all six flower configurations, lantern non-stacking reserve, frost slow caps, honeydew healing target selection, all ten enemy configurations, targeting, charge, corrosion, light suppression, support buff, splitting, armor, and Boss thresholds.

- [ ] **Step 2: Verify RED**

Expected: FAIL because new kinds and abilities do not exist.

- [ ] **Step 3: Implement plant kinds**

Expand `Plant.Kind` and configuration to all five non-node flowers. Add deterministic methods for applying lantern reserve, frost status, and honeydew healing. Use existing art as fallback when dedicated assets do not exist.

- [ ] **Step 4: Implement enemy kinds and status API**

Required public behavior:

```gdscript
func configure_by_id(enemy_id: String, spawn_position: Vector2) -> void
func apply_slow(source_id: String, ratio: float, duration: float) -> void
func apply_attack_slow(source_id: String, ratio: float, duration: float) -> void
func remove_positive_buffs() -> void
func interrupt_ability() -> bool
func convert_to_friendly(duration: float) -> bool
func get_rank() -> String
```

- [ ] **Step 5: Integrate spawns and unit support**

Map wave entries to string IDs, support split-spawn requests, temporary friendliness, node suppression, root-wall/decoy targets, and honeydew/lantern interactions.

- [ ] **Step 6: Verify GREEN**

Expected: expanded unit tests and existing unit tests pass.

### Task 5: Consumable combat deck

**Files:**
- Create: `scripts/combat_deck.gd`
- Create: `scripts/temporary_battle_object.gd`
- Create: `tests/test_combat_deck.gd`
- Modify: `tests/test_runner.gd`

- [ ] **Step 1: Write failing deck tests**

Cover exact twelve-card validation, initial four-card hand, one-time opening mulligan, play-and-remove, immediate refill, cross-night preservation, empty-deck behavior, energy validation, phase validation, and target validation.

- [ ] **Step 2: Verify RED**

Expected: FAIL because the deck model is missing.

- [ ] **Step 3: Implement deck state**

Required API:

```gdscript
func start_run(deck_ids: Array[String], seed_value: int = 0) -> bool
func get_hand() -> Array[String]
func mulligan(card_id: String) -> bool
func can_play(card_id: String, phase: String, energy: int, target_context: Dictionary) -> bool
func consume(card_id: String) -> bool
func remaining_count() -> int
func export_state() -> Dictionary
```

- [ ] **Step 4: Implement temporary battle object model**

Support root wall, lure bud, temporary sprout, path beacon, golden domain, and timed cleanup through one configured Node2D with health, duration, radius, allegiance, and optional supply/taunt behavior.

- [ ] **Step 5: Verify GREEN**

Expected: deck tests pass.

### Task 6: Resolve all twenty-four card effects

**Files:**
- Create: `scripts/card_effect_resolver.gd`
- Create: `tests/test_card_effects.gd`
- Modify: `scripts/game.gd`
- Modify: `tests/test_runner.gd`

- [ ] **Step 1: Write failing effect tests**

Create one assertion per card ID. Tests must prove damage, healing, duration, target restrictions, temporary object configuration, weather suppression, resurrection ordering, and shadow conversion.

- [ ] **Step 2: Verify RED**

Expected: FAIL because the resolver is missing.

- [ ] **Step 3: Implement the resolver**

Use one entry point:

```gdscript
func resolve(game: Node, card_id: String, target: Variant) -> Dictionary
```

Return `{"ok": bool, "energy_spent": int, "created": Array, "affected": int}`. Validate before mutation. `Game.play_combat_card(card_id, target)` delegates to the resolver, deducts energy, consumes the card only on success, and refills the hand.

- [ ] **Step 4: Verify GREEN**

Expected: every card effect test and the full suite pass.

### Task 7: Seven-day choices, retreat, rewards, and persistence

**Files:**
- Modify: `scripts/game.gd`
- Create: `scripts/profile_store.gd`
- Modify: `scripts/main_menu.gd`
- Create: `tests/test_run_progression.gd`
- Modify: `tests/test_main_menu.gd`
- Modify: `tests/test_runner.gd`

- [ ] **Step 1: Write failing run-flow tests**

Cover first-day path choice, six later evolution choices, retreat availability, first-day zero extraction, safe retreat 100%, failure 10%, victory 100%, sixth-night behavior, profile seed addition, card unlocking, mother upgrades, and deck persistence.

- [ ] **Step 2: Verify RED**

Expected: FAIL because run progression APIs are absent.

- [ ] **Step 3: Implement profile store and compatibility migration**

Persist `meta_seeds`, `unlocked_cards`, `mother_meta_levels`, and `selected_deck`. Missing fields in old saves receive defaults. Preserve obsolete `highest_wave` on disk without exposing it.

- [ ] **Step 4: Integrate run APIs into `Game`**

Required UI-independent methods and signals:

```gdscript
signal mother_choices_available(choice_ids: Array[String])
signal run_settled(result: Dictionary)

func get_mother_choices() -> Array[String]
func choose_mother_card(card_id: String) -> bool
func get_combat_hand() -> Array[String]
func play_combat_card(card_id: String, target: Variant) -> Dictionary
func can_retreat() -> bool
func retreat_run() -> Dictionary
func settle_failure() -> Dictionary
func settle_victory() -> Dictionary
```

- [ ] **Step 5: Verify GREEN**

Expected: flow and persistence tests pass.

### Task 8: Full campaign integration and regression verification

**Files:**
- Modify: `scripts/balance.gd`
- Modify: `tests/integration_smoke.gd`
- Create: `tests/content_system_smoke.gd`
- Modify: `README.md`

- [ ] **Step 1: Write failing integration smoke**

Instantiate the main scene, start a run with a valid deck, choose each mother path in separate resets, spawn every unit, play representative cards from every rarity, retreat, fail, win, reload progression, and confirm no UI methods are required.

- [ ] **Step 2: Verify RED**

Expected: integration smoke fails until all systems are wired.

- [ ] **Step 3: Complete wave and runtime integration**

Replace numeric enemy kinds with stable IDs, add the expanded seven-night formations, ensure sixth night remains non-combat, and keep final night to four normal/elite types plus the Boss.

- [ ] **Step 4: Run complete verification**

Run:

```powershell
& $godot --headless --path . -s tests/test_runner.gd
& $godot --headless --path . -s tests/integration_smoke.gd
& $godot --headless --path . -s tests/content_system_smoke.gd
& $godot --headless --path . --quit-after 5
```

Expected: all commands exit zero with `TESTS PASSED`, `INTEGRATION PASSED`, and `CONTENT SYSTEMS PASSED`.

---

## Plan self-review

- Every section of `Sunflower-Defense-Content-Data.md` maps to a task.
- Static data, mutable models, scene behaviors, persistence, and integration have separate boundaries.
- Every production module is preceded by a failing test task.
- UI implementation is excluded, but public methods and signals provide complete future binding points.
- Existing seven-night tests remain mandatory regressions.
