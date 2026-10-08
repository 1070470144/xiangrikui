extends RefCounted

var failures: Array[String] = []

func expect(value: bool, message: String) -> void:
	if not value: failures.append(message)

func run() -> Array[String]:
	var script := ResourceLoader.load("res://scripts/terrain_map.gd", "Script", ResourceLoader.CACHE_MODE_REPLACE) as Script
	if script == null or not script.can_instantiate():
		return ["terrain map script must compile"]
	var terrain: Node = script.new()
	expect(terrain.world_to_cell(Vector2(0, 0)) == Vector2i(0, 0), "world origin must map to first terrain cell")
	expect(terrain.world_to_cell(Vector2(2879, 2879)) == Vector2i(71, 71), "world edge must map to last terrain cell")
	expect(terrain.get_terrain_at(Vector2(1440, 1440)) == "soil", "center terrain must start as soil")
	for y in range(terrain.GRID_SIZE.y):
		for x in range(terrain.GRID_SIZE.x):
			expect(str(terrain.initial_cells.get(Vector2i(x, y), "")) == "soil", "every initial terrain cell must be soil")
	var soil_point := Vector2(1440, 140)
	expect(terrain.get_terrain_at(soil_point) == "soil", "north approach must start as soil without a road")
	expect(terrain.is_plantable_at(soil_point), "initial soil must be plantable")
	var cell: Vector2i = terrain.world_to_cell(soil_point)
	var cells: Array[Vector2i] = [cell]
	terrain.preview_terrain_patch(cells, "swamp", 5.0)
	expect(terrain.get_terrain_at(soil_point) == "soil", "preview must not change terrain rules")
	terrain.apply_terrain_patch(cells, "swamp")
	expect(terrain.get_terrain_at(soil_point) == "swamp", "applied patch must change terrain")
	expect(not terrain.is_plantable_at(soil_point), "swamp must block planting")
	expect(is_equal_approx(terrain.get_movement_multiplier(soil_point), 0.55), "swamp movement multiplier must be configurable at 0.55")
	terrain.restore_temporary_terrain()
	expect(terrain.get_terrain_at(soil_point) == "soil", "temporary terrain must restore to soil")
	terrain.free()
	return failures
