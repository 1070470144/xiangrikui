extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []
	for path in ["res://tests/test_tilemap_contract.gd", "res://tests/test_terrain_map.gd", "res://tests/test_terrain_events.gd", "res://tests/test_battlefield_spec.gd"]:
		var suite = load(path).new()
		failures.append_array(suite.run())
	if failures.is_empty():
		print("MODULAR TERRAIN TESTS PASSED")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)
