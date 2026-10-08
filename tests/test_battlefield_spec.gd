extends RefCounted

var failures: Array[String] = []

func expect(value: bool, message: String) -> void:
	if not value: failures.append(message)

func run() -> Array[String]:
	var script := ResourceLoader.load("res://scripts/battlefield_spec.gd", "Script", ResourceLoader.CACHE_MODE_REPLACE) as Script
	if script == null or not script.can_instantiate():
		return ["battlefield spec script must compile"]
	expect(script.WORLD_RECT == Rect2(0, 0, 2880, 2880), "battlefield spec must expose a 2880 square world")
	expect(script.CENTER == Vector2(1440, 1440), "battlefield spec must expose the world center")
	expect(script.GRID_SIZE == Vector2i(72, 72), "battlefield spec must preserve the 72 by 72 terrain grid")
	expect(is_equal_approx(script.CELL_SIZE, 40.0), "battlefield spec must scale terrain cells to 40 world units")
	expect(is_equal_approx(script.scale_distance(100.0), 40.0), "battlefield spec must scale legacy distances by 0.4")
	var entrances: Array[Vector2] = script.get_spawn_positions()
	expect(entrances.size() == 8, "battlefield spec must expose eight entrances")
	for entrance in entrances:
		expect(script.WORLD_RECT.has_point(entrance), "battlefield entrances must remain inside the world")
		expect(entrance.distance_to(script.CENTER) > 1300.0, "battlefield entrances must remain near the perimeter")
	return failures
