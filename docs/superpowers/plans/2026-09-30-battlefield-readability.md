# Battlefield Readability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add world-space enemy-direction and mother-danger feedback while reducing non-actionable HUD emphasis, without changing combat rules or bottom action controls.

**Architecture:** A focused `WorldThreatFeedback` Node2D consumes the existing eight-direction threat snapshot and draws transient, input-transparent warnings at authoritative battlefield spawn positions. `MotherFlower` owns its local danger ring because it already owns health and hit timing. `Game` only wires read-only battle state into both presentation components; `Hud` keeps exact values while lowering idle emphasis.

**Tech Stack:** Godot 4.7, GDScript, custom `_draw()` primitives, existing SceneTree test runner.

---

## File map

- Create `scripts/world_threat_feedback.gd`: render and animate eight world-space warning directions; expose deterministic presentation state for tests.
- Create `tests/test_world_threat_feedback.gd`: verify direction mapping, severity, boss treatment, lifecycle, and input/collision boundaries.
- Modify `scripts/mother_flower.gd`: draw safe, threatened, hit, and low-health rings around the existing mother object.
- Create `tests/test_mother_danger_feedback.gd`: verify mother danger-state transitions without inspecting pixels.
- Modify `scripts/game.gd`: instantiate the feedback node and pass threat, boss, and nearby-enemy state to presentation code.
- Modify `scripts/hud.gd`: compact notifications and dim the idle tactical instrument.
- Modify `tests/test_battle_hud.gd`: protect notification lifetime and tactical-instrument emphasis behavior.
- Modify `tests/test_runner.gd`: register the two new deterministic suites.
- Modify `tests/hud_capture.gd`: capture the agreed readability states for manual review.
- Create `docs/superpowers/validation/2026-09-30-battlefield-readability.md`: record commands, screenshots, observed results, and limitations.

### Task 1: Deterministic world threat presentation

**Files:**
- Create: `tests/test_world_threat_feedback.gd`
- Modify: `tests/test_runner.gd`
- Create: `scripts/world_threat_feedback.gd`

- [ ] **Step 1: Register a failing behavior suite**

Add `res://tests/test_world_threat_feedback.gd` to `SUITE_PATHS`, then create the suite with these assertions:

```gdscript
extends RefCounted

var failures: Array[String] = []

func expect(value: bool, message: String) -> void:
	if not value: failures.append(message)

func run() -> Array[String]:
	var script := load("res://scripts/world_threat_feedback.gd") as Script
	if script == null or not script.can_instantiate():
		return ["world threat feedback must compile"]
	var feedback: Node2D = script.new()
	expect(feedback.get_warning_states().size() == 8, "feedback must expose eight directions")
	feedback.update_snapshot(PackedFloat32Array([0.0, 0.15, 0.4, 0.8]), 2)
	var states: Array[Dictionary] = feedback.get_warning_states()
	expect(states[0]["severity"] == 0, "zero threat must stay idle")
	expect(states[1]["severity"] == 1, "small threat must be normal")
	expect(states[2]["severity"] == 2, "medium threat must be severe")
	expect(states[2]["boss"], "boss direction must be marked without text")
	expect(states[3]["intensity"] > states[1]["intensity"], "larger threat must read stronger")
	expect(states[7]["severity"] == 0, "missing snapshot entries must safely become zero")
	feedback.advance_feedback(2.0)
	expect(feedback.get_warning_states()[1]["visibility"] < 1.0, "cleared threat must decay")
	expect(feedback.get_child_count() == 0, "feedback must not create collision or input children")
	feedback.free()
	return failures
```

- [ ] **Step 2: Run the suite and verify RED**

Run:

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

Expected: non-zero exit with `world threat feedback must compile` because the production script does not exist.

- [ ] **Step 3: Implement the minimal deterministic model and drawing**

Create `scripts/world_threat_feedback.gd` with this public contract and drawing behavior:

```gdscript
extends Node2D

const BattlefieldSpec = preload("res://scripts/battlefield_spec.gd")
const NORMAL_THRESHOLD := 0.01
const SEVERE_THRESHOLD := 0.35
const FADE_SPEED := 2.5

var _states: Array[Dictionary] = []
var _time := 0.0

func _init() -> void:
	for position in BattlefieldSpec.get_spawn_positions():
		_states.append({"position": position, "intensity": 0.0, "visibility": 0.0, "severity": 0, "boss": false})

func update_snapshot(threats: PackedFloat32Array, boss_direction := -1) -> void:
	for index in range(_states.size()):
		var value := clampf(threats[index] if index < threats.size() else 0.0, 0.0, 1.0)
		var state := _states[index]
		state["intensity"] = value
		state["severity"] = 0 if value < NORMAL_THRESHOLD else (2 if value >= SEVERE_THRESHOLD else 1)
		state["boss"] = index == boss_direction and value >= NORMAL_THRESHOLD
		if value >= NORMAL_THRESHOLD: state["visibility"] = 1.0
		_states[index] = state
	queue_redraw()

func advance_feedback(delta: float) -> void:
	_time += delta
	for index in range(_states.size()):
		var state := _states[index]
		if float(state["intensity"]) < NORMAL_THRESHOLD:
			state["visibility"] = maxf(0.0, float(state["visibility"]) - delta * FADE_SPEED)
		_states[index] = state
	queue_redraw()

func _process(delta: float) -> void: advance_feedback(delta)
func get_warning_states() -> Array[Dictionary]: return _states.duplicate(true)
```

Complete `_draw()` by iterating visible states, deriving the inward direction with `(BattlefieldSpec.CENTER - position).normalized()`, drawing a severity-colored arc at the entrance, an inward line/arrow, and a pulsing inner arc. Use gold-red for normal, red-violet for severe, and a second slower outer arc when `boss` is true. Draw only; do not create `Area2D`, `CollisionObject2D`, or `Control` children.

- [ ] **Step 4: Run the suite and verify GREEN**

Run the headless command again. Expected: the new suite passes; any unrelated pre-existing failure must be recorded separately.

- [ ] **Step 5: Commit the focused slice**

```powershell
git add scripts/world_threat_feedback.gd tests/test_world_threat_feedback.gd tests/test_runner.gd
git commit -m "feat: add world-space threat warnings"
```

### Task 2: Mother flower danger ring

**Files:**
- Create: `tests/test_mother_danger_feedback.gd`
- Modify: `tests/test_runner.gd`
- Modify: `scripts/mother_flower.gd`

- [ ] **Step 1: Write the failing state-transition test**

```gdscript
extends RefCounted

var failures: Array[String] = []
func expect(value: bool, message: String) -> void:
	if not value: failures.append(message)

func run() -> Array[String]:
	var MotherFlower = load("res://scripts/mother_flower.gd")
	var mother = MotherFlower.new()
	mother.max_health = 100.0
	mother.reset_state()
	expect(mother.get_danger_state() == "safe", "healthy mother must start safe")
	mother.set_nearby_enemy_count(2)
	expect(mother.get_danger_state() == "threatened", "nearby enemies must raise a world warning")
	mother.take_damage(10.0)
	expect(mother.get_danger_state() == "hit", "recent damage must briefly override threatened")
	mother.advance_danger_feedback(0.25)
	mother.health = 20.0
	expect(mother.get_danger_state() == "critical", "low health must stay visibly critical")
	mother.free()
	return failures
```

Register the suite in `tests/test_runner.gd`.

- [ ] **Step 2: Run and verify RED**

Expected failure: `Invalid call. Nonexistent function 'get_danger_state'`.

- [ ] **Step 3: Implement state without changing damage rules**

Add to `mother_flower.gd`:

```gdscript
const DANGER_LOW_HEALTH_RATIO := 0.34
var _nearby_enemy_count := 0

func set_nearby_enemy_count(value: int) -> void:
	_nearby_enemy_count = maxi(0, value)
	queue_redraw()

func advance_danger_feedback(delta: float) -> void:
	_hit_flash = maxf(0.0, _hit_flash - delta)

func get_danger_state() -> String:
	if _hit_flash > 0.0: return "hit"
	if max_health > 0.0 and health / max_health <= DANGER_LOW_HEALTH_RATIO: return "critical"
	if _nearby_enemy_count > 0: return "threatened"
	return "safe"
```

Replace the existing `_hit_flash` countdown in `_process()` with `advance_danger_feedback(delta)`. In `_draw()`, derive ring color, alpha, width, radius, and pulse rate from `get_danger_state()`: safe is a faint static gold ring; threatened is a slow amber breath; hit is a short expanding warm-white ring; critical is a steady restrained red ring. Keep the existing art texture and health-ratio behavior unchanged.

- [ ] **Step 4: Run tests and verify GREEN**

Run the full headless runner. Expected: mother danger suite and existing mother/core tests pass.

- [ ] **Step 5: Commit**

```powershell
git add scripts/mother_flower.gd tests/test_mother_danger_feedback.gd tests/test_runner.gd
git commit -m "feat: add mother danger feedback ring"
```

### Task 3: Wire presentation into live combat

**Files:**
- Modify: `scripts/game.gd`
- Modify: `tests/test_game_flow.gd`

- [ ] **Step 1: Add a failing integration assertion**

Extend the existing game-flow setup to assert:

```gdscript
expect(game.world_threat_feedback != null, "game must create world threat feedback")
game.threat_levels = PackedFloat32Array([0.0, 0.2, 0.5, 0.0, 0.0, 0.0, 0.0, 0.0])
game._update_readability_feedback()
var states = game.world_threat_feedback.get_warning_states()
expect(states[1]["severity"] == 1 and states[2]["severity"] == 2, "game must forward live threat state")
```

- [ ] **Step 2: Run and verify RED**

Expected failure: `world_threat_feedback` is not defined.

- [ ] **Step 3: Add presentation-only wiring**

Add the preload and property:

```gdscript
const WorldThreatFeedbackScript = preload("res://scripts/world_threat_feedback.gd")
var world_threat_feedback: Node2D
```

Create the node immediately after `battlefield` so it shares world coordinates and renders above terrain but below interactive actors:

```gdscript
world_threat_feedback = WorldThreatFeedbackScript.new()
world_threat_feedback.name = "WorldThreatFeedback"
world_threat_feedback.z_index = 18
add_child(world_threat_feedback)
```

Add and call this method once per `_process()` after spawn processing:

```gdscript
func _update_readability_feedback() -> void:
	var boss_direction := int(get_hud_battle_state().get("boss_direction", -1))
	if is_instance_valid(world_threat_feedback):
		world_threat_feedback.update_snapshot(threat_levels, boss_direction)
	if is_instance_valid(mother_flower):
		var nearby := 0
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(enemy) and enemy.global_position.distance_to(mother_flower.global_position) <= 260.0:
				nearby += 1
		mother_flower.set_nearby_enemy_count(nearby)
```

Do not change spawn timing, enemy paths, damage, threat calculation, or camera behavior.

- [ ] **Step 4: Run tests and verify GREEN**

Expected: game-flow and both new feedback suites pass.

- [ ] **Step 5: Commit**

```powershell
git add scripts/game.gd tests/test_game_flow.gd
git commit -m "feat: connect readability feedback to combat"
```

### Task 4: Reduce idle HUD competition

**Files:**
- Modify: `tests/test_battle_hud.gd`
- Modify: `scripts/hud.gd`

- [ ] **Step 1: Add failing HUD behavior assertions**

After constructing the HUD, assert:

```gdscript
hud.update_threat_compass(PackedFloat32Array([0,0,0,0,0,0,0,0]), -1)
expect(hud.find_child("TacticalInstrumentFrame", true, false).modulate.a <= 0.45, "idle tactical instrument must recede")
hud.update_threat_compass(PackedFloat32Array([0,0,0.5,0,0,0,0,0]), 2)
expect(hud.find_child("TacticalInstrumentFrame", true, false).modulate.a >= 0.95, "active threat must restore tactical emphasis")
hud.show_message("普通提示")
expect(hud.get_message_time_left() <= 2.6, "ordinary notification must leave the battlefield quickly")
```

- [ ] **Step 2: Run and verify RED**

Expected: idle alpha remains `1.0` and `get_message_time_left()` is missing.

- [ ] **Step 3: Implement compact notification and emphasis states**

Change the notification offsets from `(-210, 102, 210, 146)` to `(-180, 92, 180, 128)`. Add:

```gdscript
func get_message_time_left() -> float: return _message_time_left

func _set_tactical_emphasis(active: bool) -> void:
	if tactical_instrument_frame != null:
		tactical_instrument_frame.modulate.a = 1.0 if active else 0.38
```

Set ordinary messages to `2.5` seconds in `show_message()`. In `update_threat_compass()`, safely scan up to eight values, call `_set_tactical_emphasis(has_threat or boss_direction >= 0)`, then forward the snapshot to the compass. Keep the frame interactive behavior and radar click contract unchanged.

- [ ] **Step 4: Run HUD and full suites**

Expected: new HUD assertions pass and existing viewport/no-overlap assertions remain green at 1152×648, 1280×720, and 1920×1080.

- [ ] **Step 5: Commit**

```powershell
git add scripts/hud.gd tests/test_battle_hud.gd
git commit -m "fix: reduce idle battle HUD competition"
```

### Task 5: Runtime capture and completion evidence

**Files:**
- Modify: `tests/hud_capture.gd`
- Create: `docs/superpowers/validation/2026-09-30-battlefield-readability.md`

- [ ] **Step 1: Add deterministic capture states**

Extend `tests/hud_capture.gd` so it can capture these states with fixed threat snapshots: day/idle, night/north-east normal threat, night/east severe threat, boss threat, mother recently hit, and mother critical. Save images under `output/imagegen/previews/readability/` without replacing existing user screenshots.

- [ ] **Step 2: Run the complete automated suite**

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

Expected: `TESTS PASSED`, exit code `0`, and no new parse errors or warnings.

- [ ] **Step 3: Run the project and capture actual states**

Run the project with its configured main scene, exercise day → night → threat → damage → restart, and execute the capture script using the project's established Godot invocation. Confirm the six PNGs exist and are non-empty.

- [ ] **Step 4: Inspect the captures against the design**

At 1152×648 verify that the notification does not form a persistent central wall; the dominant direction reads without looking at the right instrument; boss and severe directions differ without text; the mother remains locatable in safe, hit, and critical states; and world feedback does not obscure deployable ground.

- [ ] **Step 5: Write the validation record**

Record exact commands, exit codes, screenshot paths, pre-existing failures, visual observations, and the next gameplay question in `docs/superpowers/validation/2026-09-30-battlefield-readability.md`. Do not claim a state was exercised unless it was observed.

- [ ] **Step 6: Commit evidence**

```powershell
git add tests/hud_capture.gd docs/superpowers/validation/2026-09-30-battlefield-readability.md
git commit -m "test: validate battlefield readability"
```
