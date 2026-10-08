extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []
	for path in ["res://tests/test_combat_deck.gd", "res://tests/test_card_effects.gd", "res://tests/test_run_progression.gd", "res://tests/test_game_flow.gd"]:
		var suite := load(path) as Script
		failures.append_array(suite.new().run())
	for failure in failures: push_error(failure)
	print("CARD FLOW REGRESSIONS PASSED" if failures.is_empty() else "CARD FLOW REGRESSIONS FAILED")
	quit(0 if failures.is_empty() else 1)
