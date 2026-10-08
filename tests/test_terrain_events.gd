extends RefCounted

var failures: Array[String] = []

func expect(value: bool, message: String) -> void:
	if not value: failures.append(message)

func run() -> Array[String]:
	var terrain_script := ResourceLoader.load("res://scripts/terrain_map.gd", "Script", ResourceLoader.CACHE_MODE_REPLACE) as Script
	var event_script := ResourceLoader.load("res://scripts/terrain_event_controller.gd", "Script", ResourceLoader.CACHE_MODE_REPLACE) as Script
	if terrain_script == null or event_script == null or not terrain_script.can_instantiate() or not event_script.can_instantiate():
		return ["terrain event scripts must compile"]
	var terrain: Node = terrain_script.new()
	var controller: Node = event_script.new()
	controller.configure(terrain, 77)
	expect(controller.event_count_for_weather("acid_rain") in [2, 3], "acid rain must schedule two or three terrain events")
	expect(controller.event_count_for_weather("thunderstorm") in [2, 3], "thunderstorm must schedule two or three terrain events")
	expect(controller.event_count_for_weather("clear") == 0, "clear weather must not schedule terrain events")
	var first: Array[Vector2i] = controller.choose_patch_cells(2)
	controller.configure(terrain, 77)
	var repeated: Array[Vector2i] = controller.choose_patch_cells(2)
	expect(first == repeated, "same run seed must choose the same terrain patch")
	expect(first.size() == 4, "size two patch must contain four connected cells")
	for cell in first:
		expect(cell.x >= 0 and cell.x < 72 and cell.y >= 0 and cell.y < 72, "terrain event cells must stay inside the map")
		expect(not controller.is_protected_cell(cell), "terrain event must avoid protected core and entrances")
	controller.free(); terrain.free()
	return failures
