extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = load("res://tests/test_deck_builder_model.gd").new().run()
	failures.append_array(await load("res://tests/test_deck_builder_ui.gd").new().run())
	failures.append_array(await load("res://tests/test_deck_builder_interactions.gd").new().run())
	if failures.is_empty():
		print("DECK BUILDER TESTS PASSED")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
