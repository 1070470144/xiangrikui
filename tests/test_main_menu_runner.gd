extends SceneTree

func _initialize() -> void:
	var suite_script := load("res://tests/test_main_menu.gd") as Script
	var failures: Array[String] = suite_script.new().run()
	if failures.is_empty():
		print("MAIN MENU TESTS PASSED")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
