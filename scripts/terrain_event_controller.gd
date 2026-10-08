extends Node

const BattlefieldSpec = preload("res://scripts/battlefield_spec.gd")

signal patch_warning_started(cells: Array[Vector2i], duration: float)
signal patch_applied(cells: Array[Vector2i])

const FIRST_EVENT_DELAY := 15.0
const EVENT_INTERVAL := 20.0
const WARNING_DURATION := 5.0

var terrain_map: Node
var rng := RandomNumberGenerator.new()
var run_seed := 1
var weather := "clear"
var events_remaining := 0
var time_until_event := INF
var warning_time_left := 0.0
var pending_cells: Array[Vector2i] = []

func configure(map: Node, seed_value: int) -> void:
	terrain_map = map
	run_seed = seed_value
	rng.seed = seed_value
	stop_and_restore()

func event_count_for_weather(value: String) -> int:
	if value not in ["acid_rain", "thunderstorm"]: return 0
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = run_seed + value.hash()
	return local_rng.randi_range(2, 3)

func start_weather(value: String) -> void:
	weather = value
	events_remaining = event_count_for_weather(value)
	time_until_event = FIRST_EVENT_DELAY if events_remaining > 0 else INF
	warning_time_left = 0.0
	pending_cells.clear()

func stop_and_restore() -> void:
	weather = "clear"
	events_remaining = 0
	time_until_event = INF
	warning_time_left = 0.0
	pending_cells.clear()
	if is_instance_valid(terrain_map): terrain_map.restore_temporary_terrain()

func advance(delta: float) -> void:
	if events_remaining <= 0 or not is_instance_valid(terrain_map): return
	if warning_time_left > 0.0:
		warning_time_left = maxf(0.0, warning_time_left - delta)
		terrain_map.update_preview(warning_time_left)
		if warning_time_left <= 0.0:
			terrain_map.apply_terrain_patch(pending_cells, "swamp")
			patch_applied.emit(pending_cells.duplicate())
			pending_cells.clear()
			events_remaining -= 1
			time_until_event = EVENT_INTERVAL if events_remaining > 0 else INF
		return
	time_until_event -= delta
	if time_until_event <= 0.0:
		var patch_size := rng.randi_range(2, 3)
		pending_cells = choose_patch_cells(patch_size)
		if pending_cells.is_empty():
			events_remaining = 0
			return
		warning_time_left = WARNING_DURATION
		terrain_map.preview_terrain_patch(pending_cells, "swamp", warning_time_left)
		patch_warning_started.emit(pending_cells.duplicate(), warning_time_left)

func choose_patch_cells(size: int) -> Array[Vector2i]:
	if not is_instance_valid(terrain_map): return []
	var candidates: Array[Vector2i] = []
	for y in range(1, terrain_map.GRID_SIZE.y - size):
		for x in range(1, terrain_map.GRID_SIZE.x - size):
			var cells: Array[Vector2i] = []
			var valid := true
			for offset_y in range(size):
				for offset_x in range(size):
					var cell := Vector2i(x + offset_x, y + offset_y)
					if is_protected_cell(cell): valid = false
					cells.append(cell)
			if valid: candidates.append(Vector2i(x, y))
	if candidates.is_empty(): return []
	var origin := candidates[rng.randi_range(0, candidates.size() - 1)]
	var result: Array[Vector2i] = []
	for y in range(size):
		for x in range(size): result.append(origin + Vector2i(x, y))
	return result

func is_protected_cell(cell: Vector2i) -> bool:
	var center: Vector2 = terrain_map.cell_to_world_center(cell) if is_instance_valid(terrain_map) else Vector2(cell) * BattlefieldSpec.CELL_SIZE + Vector2.ONE * BattlefieldSpec.CELL_SIZE * 0.5
	if center.distance_to(BattlefieldSpec.CENTER) < 144.0: return true
	var entrances := BattlefieldSpec.get_spawn_positions()
	for entrance in entrances:
		if center.distance_to(entrance) < 58.0: return true
	return false
