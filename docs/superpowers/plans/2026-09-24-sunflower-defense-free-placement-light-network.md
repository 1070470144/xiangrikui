# Sunflower Defense Free Placement Light Network Implementation Plan

> 实施状态（2026-09-24）：核心任务已完成。验证命令见文末；由于当前工作区 `.git` 不可写，本轮未能创建提交。

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the fixed four-branch/eight-slot battlefield with a large square free-placement battlefield, plantable light sprouts, automatic tree connections, eight-direction waves, camera navigation, and a light-network radar.

**Architecture:** `battlefield.gd` owns world geometry and pure placement queries; `light_node.gd` represents both the root-connected plantable relay and its parent/capacity state; `game.gd` owns resources, placement, network rebuilding, waves, and actor lifecycle. A new `world_camera.gd` isolates camera movement and clamping, while `hud.gd` adds light-sprout selection and a compact radar fed by snapshots from the game state.

**Tech Stack:** Godot 4.7 GDScript, Node2D custom drawing, Camera2D, CanvasLayer UI, headless GDScript tests.

---

### Task 1: Battlefield geometry and placement rules

**Files:**
- Modify: `scripts/battlefield.gd`
- Modify: `tests/test_game_flow.gd`

- [ ] Add failing tests asserting a square 1400×1400 world, eight unique spawn positions, valid free-placement land, blocked core/edge positions, and overlap rejection.
- [ ] Run the headless suite and verify the new battlefield assertions fail against the fixed-slot implementation.
- [ ] Replace slot arrays with `WORLD_RECT`, `CENTER`, `PLANTABLE_RADIUS`, eight direction vectors/spawn positions, and pure methods `is_inside_plantable_area(point)`, `is_position_clear(point, radius, occupied)`, and `get_spawn_position(direction)`.
- [ ] Replace socket drawing with a square-world garden, eight edge markers, free-placement preview, dynamic light-network lines, and eight-direction warnings.
- [ ] Run the headless suite and verify battlefield tests pass.

### Task 2: Plantable light sprout model

**Files:**
- Modify: `scripts/light_node.gd`
- Modify: `tests/test_core_rules.gd`

- [ ] Add failing tests for parent assignment, capacity four, load accounting, connection range, and disconnection after destruction.
- [ ] Run tests and verify the new node contract fails.
- [ ] Add `parent_source`, `connection_range`, `supply_radius`, `capacity`, `load`, `can_accept(cost)`, `set_parent_source(source)`, and `set_load(value)` while preserving damage/repair signals.
- [ ] Draw the node's supply radius during placement/debug preview and expose a stable `network_id` for radar snapshots.
- [ ] Run tests and verify the node contract passes.

### Task 3: Free-placement game flow and dual costs

**Files:**
- Modify: `scripts/game.gd`
- Modify: `scripts/plant.gd`
- Modify: `scripts/hud.gd`
- Modify: `project.godot`
- Modify: `tests/test_game_flow.gd`

- [ ] Add failing tests for light-sprout day cost 15, night cost 23, thorn cost one seed, prism cost two seeds, nearest valid parent selection, and rejection outside supplied land.
- [ ] Run tests and verify these free-placement/resource assertions fail.
- [ ] Add selection kind `LIGHT_SPROUT`, change pointer clicks from slot lookup to world-position placement, and maintain arrays of plantable light nodes and placed plants.
- [ ] Implement `find_best_parent(point, load_cost)`, `can_place_light_node(point)`, `can_place_plant(point, kind)`, `_place_light_node(point)`, and `_place_plant_at(point, kind)`.
- [ ] Update plants to store `power_source` instead of fixed `branch_index`, use supply state to set powered status, and preserve existing attack behavior.
- [ ] Add a HUD button and keyboard action `3` for light sprouts, update instructions/cost labels, and keep attack plants restricted to daytime while allowing sprouts at night.
- [ ] Run tests and verify the placement/resource tests pass.

### Task 4: Network rebuilding and storage fallback

**Files:**
- Modify: `scripts/game.gd`
- Modify: `scripts/plant.gd`
- Modify: `scripts/light_node.gd`
- Modify: `tests/test_core_rules.gd`

- [ ] Add failing tests that a disconnected plant remains combat-capable during three seconds of stored light, becomes weakened, then sleeps, and can recover when assigned a new source.
- [ ] Run tests and verify storage-state assertions fail.
- [ ] Add plant power states `POWERED`, `STORED`, `LOW_LIGHT`, and `DORMANT`, with timers and damage/interval modifiers.
- [ ] Rebuild parent/load assignments when a light node is placed, destroyed, or repaired; prefer nearest available source and migrate node subtrees before individual plants.
- [ ] Ensure enemies receive the current dynamic light-node array and erosion bugs retarget when nodes die.
- [ ] Run tests and verify storage and reconnection tests pass.

### Task 5: Eight-direction five-wave combat

**Files:**
- Modify: `scripts/game.gd`
- Modify: `scripts/battlefield.gd`
- Modify: `scripts/hud.gd`
- Modify: `tests/test_game_flow.gd`

- [ ] Add failing tests for five waves, direction indices zero through seven, and diagonal spawn positions.
- [ ] Run tests and verify wave assertions fail against the three-wave model.
- [ ] Replace wave data with five formations: east/west, north/south, three adjacent directions, four diagonals, and all eight directions.
- [ ] Update completion logic and UI from three to five waves; make spawn warnings support all eight directions.
- [ ] Run tests and verify all wave tests pass.

### Task 6: Camera navigation

**Files:**
- Create: `scripts/world_camera.gd`
- Modify: `scripts/game.gd`
- Modify: `project.godot`
- Create: `tests/test_camera_rules.gd`
- Modify: `tests/test_runner.gd`

- [ ] Add tests for zoom bounds and camera position clamping within the world rectangle.
- [ ] Run tests and verify the camera script is missing.
- [ ] Implement a `Camera2D` controller with WASD/arrow movement, middle-mouse dragging, edge scrolling, wheel zoom around the pointer, and `F` focus on the mother flower.
- [ ] Instantiate it from the game root and convert viewport mouse positions to world coordinates before placement and sunburst targeting.
- [ ] Run tests and verify camera rules and existing tests pass.

### Task 7: Light-network radar

**Files:**
- Create: `scripts/light_radar.gd`
- Modify: `scripts/hud.gd`
- Modify: `scripts/game.gd`
- Create: `tests/test_radar_rules.gd`
- Modify: `tests/test_runner.gd`

- [ ] Add tests for mapping world positions into radar coordinates and representing eight threat directions.
- [ ] Run tests and verify radar tests fail because the component is missing.
- [ ] Implement a compact Control that draws the mother flower, light nodes, network lines, damaged/disconnected state, and eight directional threat pulses from a snapshot dictionary.
- [ ] Feed radar snapshots from `game.gd` and allow radar clicks to request a camera focus position.
- [ ] Run tests and verify radar and full suites pass.

### Task 8: Integration verification and documentation

**Files:**
- Modify: `README.md`
- Modify: `docs/superpowers/plans/2026-09-24-sunflower-defense-free-placement-light-network.md`

- [ ] Update controls and rules for free placement, key `3`, camera movement, five waves, and eight directions.
- [ ] Run the complete headless test suite and require `TESTS PASSED`.
- [ ] Run a timed headless main-scene smoke test and confirm there are no parser/runtime errors.
- [ ] Search for remaining fixed-slot/four-direction assumptions and remove obsolete gameplay references.
- [ ] Mark every completed plan checkbox and record verification commands/results.

## Execution Record

- 完成：1400×1400 正方形战场与八方向入口。
- 完成：自由种植、可种植光脉芽、双资源成本和自动父节点选择。
- 完成：储光、低光、休眠状态以及网络重建后的恢复。
- 完成：五波八方向阵型与无限模式八方向生成。
- 完成：镜头移动、拖动、缩放、聚焦和边界限制。
- 完成：光网雷达、威胁方向和点击聚焦。
- 验证：`Godot --headless --path . -s tests/test_runner.gd` 输出 `TESTS PASSED`。
- 验证：`Godot --headless --path . -s tests/integration_smoke.gd` 输出 `INTEGRATION PASSED`。
- 验证：`Godot --headless --path . --quit-after 120` 退出码为 0。
