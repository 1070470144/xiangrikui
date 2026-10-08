# Sunflower Defense Godot Prototype Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a complete, runnable Godot 4 prototype of 《最后的向日葵》 with a three-wave defense loop, breakable light network, two plants, two enemies, an active sunburst skill, victory/failure, and restart.

**Architecture:** The game uses one authoritative `Game` node for phase and resource state, small scene-backed combat actors, and signal-based communication. Visuals are drawn procedurally through `CanvasItem._draw()` so the prototype runs without external art while preserving the established cold-shadow versus warm-light art direction.

**Tech Stack:** Godot 4.x, GDScript 2.0, Godot scene resources (`.tscn`), headless GDScript smoke tests, Windows PowerShell verification.

---

## File Structure

- `project.godot` — project settings, input actions, main scene, viewport configuration.
- `icon.svg` — minimal sunflower project icon.
- `scenes/main.tscn` — root scene wiring game, battlefield, actors, effects, and HUD.
- `scenes/components/mother_flower.tscn` — central objective scene.
- `scenes/components/light_node.tscn` — breakable and repairable light-network node.
- `scenes/components/plant.tscn` — configurable thorn/prism plant scene.
- `scenes/components/enemy.tscn` — configurable shadow-beast/erosion-bug scene.
- `scenes/components/projectile.tscn` — prism projectile scene.
- `scenes/ui/hud.tscn` — resource display, build buttons, skill button, overlays.
- `scripts/game.gd` — phase machine, waves, resources, spawning, placement, victory/failure.
- `scripts/battlefield.gd` — battlefield drawing, slots, entrances, warnings, pointer feedback.
- `scripts/mother_flower.gd` — health and visual state.
- `scripts/light_node.gd` — health, connection, damage, repair.
- `scripts/plant.gd` — targeting and both plant attack patterns.
- `scripts/enemy.gd` — target selection, steering, attack, damage, death reward.
- `scripts/projectile.gd` — movement and hit resolution.
- `scripts/hud.gd` — presentation and input requests.
- `scripts/effects.gd` — short-lived sunburst, hit, death, warning, and resource particles.
- `tests/test_runner.gd` — headless test runner returning a non-zero exit code on failure.
- `tests/test_combat.gd` — damage, death, reward, and projectile behavior tests.
- `tests/test_light_network.gd` — node break/repair and plant power-state tests.
- `tests/test_game_flow.gd` — phase, wave, victory, failure, and restart tests.
- `README.md` — launch controls, gameplay summary, and verification commands.

### Task 1: Bootstrap the Godot Project and Test Harness

**Files:**
- Create: `project.godot`
- Create: `icon.svg`
- Create: `tests/test_runner.gd`
- Create: `tests/test_bootstrap.gd`

- [ ] **Step 1: Write the bootstrap test**

Create `tests/test_bootstrap.gd` with a suite exposing `run()` and checking project constants:

```gdscript
extends RefCounted

func run() -> Array[String]:
    var failures: Array[String] = []
    if ProjectSettings.get_setting("display/window/size/viewport_width") != 1152:
        failures.append("viewport width must be 1152")
    if ProjectSettings.get_setting("display/window/size/viewport_height") != 648:
        failures.append("viewport height must be 648")
    if not InputMap.has_action("sunburst"):
        failures.append("sunburst input action missing")
    return failures
```

- [ ] **Step 2: Create the headless runner**

Create `tests/test_runner.gd`:

```gdscript
extends SceneTree

const SUITES := [
    preload("res://tests/test_bootstrap.gd"),
]

func _initialize() -> void:
    var failures: Array[String] = []
    for suite_script in SUITES:
        failures.append_array(suite_script.new().run())
    if failures.is_empty():
        print("TESTS PASSED")
        quit(0)
    for failure in failures:
        push_error(failure)
    quit(1)
```

- [ ] **Step 3: Run the test and verify it fails**

Run: `godot --headless --path . -s tests/test_runner.gd`

Expected: non-zero exit because `project.godot` and input actions do not exist.

- [ ] **Step 4: Create project settings and icon**

Create `project.godot` with Godot 4 rendering, 1152×648 canvas, stretch mode `canvas_items`, main scene `res://scenes/main.tscn`, and actions `select_thorn`, `select_prism`, `sunburst`, `cancel_action`, `restart`, and `start_wave`.

Create an SVG icon using a gold sunflower with a dark blue-purple background.

- [ ] **Step 5: Run the bootstrap test**

Run: `godot --headless --path . -s tests/test_runner.gd`

Expected: `TESTS PASSED`.

- [ ] **Step 6: Commit**

Run:

```powershell
git add project.godot icon.svg tests/test_runner.gd tests/test_bootstrap.gd
git commit -m "build: bootstrap Godot prototype"
```

### Task 2: Build Health Actors and Light-Network Rules

**Files:**
- Create: `scripts/mother_flower.gd`
- Create: `scripts/light_node.gd`
- Create: `scenes/components/mother_flower.tscn`
- Create: `scenes/components/light_node.tscn`
- Create: `tests/test_light_network.gd`
- Modify: `tests/test_runner.gd`

- [ ] **Step 1: Write failing light-network tests**

The suite must instantiate scripts directly and assert:

```gdscript
var node := LightNode.new()
node.max_health = 100.0
node.reset_state()
node.take_damage(100.0)
expect(node.is_connected_to_light == false, "destroyed node must disconnect")
expect(node.repair(60.0) == true, "destroyed node must be repairable")
expect(node.is_connected_to_light == true, "repaired node must reconnect")
```

It must also verify the mother flower emits `destroyed` exactly once at zero health.

- [ ] **Step 2: Run the suite and verify failure**

Run: `godot --headless --path . -s tests/test_runner.gd`

Expected: parse or preload failure because actor scripts do not exist.

- [ ] **Step 3: Implement the mother flower**

Implement `max_health`, `health`, `take_damage(amount)`, `reset_state()`, `health_changed`, and one-shot `destroyed`. Draw layered petals, a warm core, roots, a shadow, a health-dependent glow, and a short hit flash.

- [ ] **Step 4: Implement light nodes**

Implement `node_index`, `max_health`, `health`, `is_connected_to_light`, `take_damage(amount)`, `repair(amount)`, `reset_state()`, `health_changed`, `connection_changed`, and `destroyed`. Repairing from zero immediately reconnects the branch.

- [ ] **Step 5: Create actor scenes**

Each scene contains a `Node2D` root using the corresponding script, a `CollisionShape2D` for hit radius, and no external texture dependencies.

- [ ] **Step 6: Run tests and commit**

Expected: `TESTS PASSED`.

Run:

```powershell
git add scripts/mother_flower.gd scripts/light_node.gd scenes/components tests
git commit -m "feat: add mother flower and light network"
```

### Task 3: Implement Plants, Enemies, and Projectiles

**Files:**
- Create: `scripts/plant.gd`
- Create: `scripts/enemy.gd`
- Create: `scripts/projectile.gd`
- Create: `scenes/components/plant.tscn`
- Create: `scenes/components/enemy.tscn`
- Create: `scenes/components/projectile.tscn`
- Create: `tests/test_combat.gd`
- Modify: `tests/test_runner.gd`

- [ ] **Step 1: Write failing combat tests**

Test these public contracts:

```gdscript
var enemy := Enemy.new()
enemy.configure(Enemy.Kind.SHADOW_BEAST, Vector2.ZERO)
var start_health := enemy.health
enemy.take_damage(15.0)
expect(enemy.health == start_health - 15.0, "enemy damage must subtract health")

var plant := Plant.new()
plant.configure(Plant.Kind.PRISM, 0)
plant.set_powered(false)
expect(plant.can_attack() == false, "unpowered plant must not attack")
```

Also test enemy reward emission once, erosion-bug node priority, thorn area damage, and projectile single-hit behavior.

- [ ] **Step 2: Run tests and verify failure**

Run: `godot --headless --path . -s tests/test_runner.gd`

Expected: missing combat scripts or failed assertions.

- [ ] **Step 3: Implement enemy behavior**

Define `Kind { SHADOW_BEAST, EROSION_BUG }`, configuration values, `set_targets(mother, light_nodes)`, target selection, movement, timed attacks, damage, one-shot death, and `died(reward, position)`.

- [ ] **Step 4: Implement plant behavior**

Define `Kind { THORN, PRISM }`, `configure(kind, branch_index)`, `set_powered(value)`, `can_attack()`, nearest-target queries from group `enemies`, thorn pulse damage, and prism projectile requests.

- [ ] **Step 5: Implement projectile behavior**

Implement `launch(target, damage)`, homing movement, validity checks, a 3-second timeout, and exactly one call to `target.take_damage(damage)`.

- [ ] **Step 6: Add procedural actor art**

Draw distinct silhouettes: low wide thorns with curved spikes, faceted prism petals, crouched shadow beasts, segmented erosion bugs, and bright gold projectiles. Include powered/unpowered, hit, and death feedback.

- [ ] **Step 7: Run tests and commit**

Expected: `TESTS PASSED`.

Run:

```powershell
git add scripts/plant.gd scripts/enemy.gd scripts/projectile.gd scenes/components tests
git commit -m "feat: add plants enemies and projectiles"
```

### Task 4: Build the Battlefield and Placement Interaction

**Files:**
- Create: `scripts/battlefield.gd`
- Create: `scenes/battlefield.tscn`
- Create: `tests/test_battlefield.gd`
- Modify: `tests/test_runner.gd`

- [ ] **Step 1: Write failing battlefield tests**

Verify the battlefield exposes exactly eight plant slots, four branch mappings, four spawn entrances, rejects occupied slots, and maps pointer positions to the correct slot within its selection radius.

- [ ] **Step 2: Run tests and verify failure**

Run: `godot --headless --path . -s tests/test_runner.gd`

Expected: missing battlefield script.

- [ ] **Step 3: Implement battlefield geometry**

Use constants for center `(576, 338)`, inner/middle/outer elliptical rings, eight slot positions, four light-node positions, and four off-screen spawn points. Expose `get_slot_position(index)`, `get_slot_branch(index)`, `find_slot_at(local_position)`, `set_slot_occupied(index, value)`, and `get_spawn_position(direction)`.

- [ ] **Step 4: Draw the art-direction foundation**

Draw layered soil ellipses, broken greenhouse ribs, cold fog, roots, stones, eight readable plant sockets, four golden light veins, and branch-specific damaged/disconnected states. Keep the center brighter than the periphery.

- [ ] **Step 5: Add spawn warnings and placement preview**

Expose `warn_spawn(direction, duration)` and `set_placement_preview(slot, plant_kind, valid)`. Animate warning pulses without changing game rules.

- [ ] **Step 6: Run tests and commit**

Expected: `TESTS PASSED`.

Run:

```powershell
git add scripts/battlefield.gd scenes/battlefield.tscn tests
git commit -m "feat: build ring battlefield and placement slots"
```

### Task 5: Implement the Game State Machine and Three Waves

**Files:**
- Create: `scripts/game.gd`
- Create: `scenes/main.tscn`
- Create: `tests/test_game_flow.gd`
- Modify: `tests/test_runner.gd`

- [ ] **Step 1: Write failing game-flow tests**

Test these transitions without waiting real time:

```gdscript
game.start_new_run()
expect(game.phase == Game.Phase.DAY, "new run starts in day")
game.start_wave_now()
expect(game.phase == Game.Phase.NIGHT, "start wave enters night")
game.debug_complete_wave()
expect(game.phase == Game.Phase.DAY, "cleared non-final wave returns to day")
```

Also test final-wave victory, mother-flower failure, restart reset, seed spending, light reward clamping, repair cost, and sunburst cost.

- [ ] **Step 2: Run tests and verify failure**

Run: `godot --headless --path . -s tests/test_runner.gd`

Expected: missing game script or failed assertions.

- [ ] **Step 3: Implement authoritative state**

Define `Phase { DAY, NIGHT, VICTORY, FAILURE }`, wave index, day timer, seeds, light energy, selected build, selected skill, dynamic actor lists, and signals for all UI values.

- [ ] **Step 4: Implement wave data**

Use three fixed arrays of spawn entries containing enemy kind, direction, delay, and count. Wave 1 contains shadow beasts only; wave 2 introduces erosion bugs; wave 3 increases simultaneous directions and requires sunburst use.

- [ ] **Step 5: Implement placement, repair, and spawning**

During day, left-click plants a selected type into a free slot if seeds remain, or repairs a damaged branch for light energy. During night, placement is rejected. Spawn warnings occur before each enemy instance.

- [ ] **Step 6: Implement sunburst**

Entering aim mode displays a radius preview. Confirmation spends 40 light energy and damages all enemies within 150 pixels. Insufficient energy does not alter state.

- [ ] **Step 7: Implement victory, failure, and restart**

Freeze combat on terminal phases. `restart_run()` frees dynamic actors, resets all branches, clears slots, resets resources, and returns to the first day.

- [ ] **Step 8: Run tests and commit**

Expected: `TESTS PASSED`.

Run:

```powershell
git add scripts/game.gd scenes/main.tscn tests
git commit -m "feat: implement three-wave game loop"
```

### Task 6: Build HUD, Controls, and Player Feedback

**Files:**
- Create: `scripts/hud.gd`
- Create: `scenes/ui/hud.tscn`
- Create: `scripts/effects.gd`
- Modify: `scenes/main.tscn`
- Create: `tests/test_hud_contract.gd`
- Modify: `tests/test_runner.gd`

- [ ] **Step 1: Write failing HUD contract tests**

Instantiate the HUD scene and verify required named controls exist: `HealthBar`, `EnergyBar`, `WaveLabel`, `PhaseLabel`, `TimerLabel`, `ThornButton`, `PrismButton`, `SunburstButton`, `MessageLabel`, `ResultPanel`, and `RestartButton`.

- [ ] **Step 2: Run tests and verify failure**

Run: `godot --headless --path . -s tests/test_runner.gd`

Expected: missing HUD scene or required controls.

- [ ] **Step 3: Build the HUD**

Use dark translucent botanical-record panels, thin gold borders, readable Chinese labels, warm active states, muted unavailable states, and a restrained dark-red warning state. Bind updates only through public setters and signals.

- [ ] **Step 4: Wire mouse and keyboard controls**

Buttons emit requests; `game.gd` handles keys `1`, `2`, `Space`, `Enter`, `R`, `Escape`, left-click, and right-click. Selection state appears both on the HUD and battlefield.

- [ ] **Step 5: Add feedback effects**

Add reusable effects for sunburst rings, hit flashes, enemy dissolution, resource transfer, branch repair pulses, spawn warnings, unavailable-action shake, and short message text.

- [ ] **Step 6: Run tests and commit**

Expected: `TESTS PASSED`.

Run:

```powershell
git add scripts/hud.gd scripts/effects.gd scenes/ui scenes/main.tscn tests
git commit -m "feat: add HUD controls and combat feedback"
```

### Task 7: Balance, Documentation, and Full Verification

**Files:**
- Create: `README.md`
- Modify: gameplay scripts only where verification identifies tuning defects.
- Modify: `docs/superpowers/plans/2026-09-24-sunflower-defense-godot-prototype.md` to check completed steps.

- [ ] **Step 1: Run the complete automated suite**

Run: `godot --headless --path . -s tests/test_runner.gd`

Expected: `TESTS PASSED`, exit code 0, no parser or resource errors.

- [ ] **Step 2: Run main-scene smoke verification**

Run: `godot --headless --path . --editor --quit-after 3`

Expected: project imports successfully with no scene, script, or resource errors.

Run: `godot --headless --path . --quit-after 15`

Expected: the main scene runs for 15 seconds without crashes or error output.

- [ ] **Step 3: Perform manual gameplay verification**

Launch the project and verify planting both species, early wave start, automatic attacks, node destruction, plant shutdown, repair and recovery, sunburst energy consumption, all three waves, victory, intentional failure, and restart.

- [ ] **Step 4: Tune readability and difficulty**

Adjust only named exported constants based on observed problems: actor health, damage, attack interval, move speed, spawn delay, wave composition, day length, light regeneration, reward, repair cost, and sunburst damage. Do not add new systems.

- [ ] **Step 5: Write README**

Document Godot version, launch command, controls, core rules, project layout, test command, art strategy, and how to replace procedural actors with hand-painted sprites.

- [ ] **Step 6: Audit the design completion definition**

For each of the eight completion requirements in the design spec, record the concrete file, test, runtime observation, or command output that proves it. Treat any missing evidence as unfinished work.

- [ ] **Step 7: Commit the verified prototype**

Run:

```powershell
git add README.md project.godot scenes scripts tests docs/superpowers/plans
git commit -m "feat: complete sunflower defense prototype"
```

