extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []
	for path in ["res://tests/test_balance.gd", "res://tests/test_run_progression.gd", "res://tests/test_core_rules.gd", "res://tests/test_expanded_units.gd"]:
		failures.append_array(load(path).new().run())
	if failures.is_empty():
		print("WAVE_REGRESSIONS_PASS balance progression core expanded_units")
		quit()
	else:
		for failure in failures: push_error(failure)
		quit(1)
