extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	if not value: failures.append(message)

func run() -> void:
	var menu = load("res://scripts/main_menu.gd").new()
	menu.set_motion_enabled(false)
	root.add_child(menu)
	await process_frame
	var motion = menu.background_motion
	expect(motion.available and motion.frames.size() >= 48, "all background animation pages and frames must load")
	expect(not motion.visible and not motion.is_processing(), "reduced motion must stop background playback")
	expect(motion.mouse_filter == Control.MOUSE_FILTER_IGNORE, "background must never intercept menu clicks")
	menu.set_motion_enabled(true)
	expect(motion.visible and motion.is_processing(), "background must resume when motion is enabled")
	motion.set_process(false)
	motion.elapsed = 0.0
	motion._process(0.25)
	expect(motion.current_frame() == 3, "playback must follow manifest fps")
	motion.elapsed = float(motion.frames.size()) / motion.fps - 0.01
	motion._process(0.02)
	expect(motion.current_frame() == 0, "last frame must wrap to the loop start")
	for frame in motion.frames:
		var texture: Texture2D = motion.pages[int(frame.page)]
		expect(Rect2(Vector2.ZERO, texture.get_size()).encloses(Rect2(float(frame.x), float(frame.y), float(frame.w), float(frame.h))), "atlas frame must stay inside texture bounds")
	var primary = menu.find_child("PrimaryStartButton", true, false)
	expect(primary != null, "animated background must retain primary menu action")
	expect(motion.get_index() < menu.page_stack.get_index(), "animation must stay behind menu pages")
	menu._show_settings()
	var reduced: CheckButton
	# Last CheckButton is the reduced-motion preference.
	var toggles: Array[Node] = menu.find_children("*", "CheckButton", true, false)
	if not toggles.is_empty(): reduced = toggles[-1]
	expect(reduced != null, "settings must expose reduced-motion toggle")
	if reduced != null:
		reduced.button_pressed = true
		expect(not menu.motion_enabled and not motion.visible, "actual settings toggle must disable animation")
		reduced.button_pressed = false
		expect(menu.motion_enabled and motion.visible, "actual settings toggle must resume animation")
	menu.set_motion_enabled(false)
	menu._show_home()
	expect(not motion.visible and motion.elapsed == 0.0, "page changes must respect reduced-motion preference")
	if failures.is_empty():
		print("MAIN_MENU_BACKGROUND_MOTION_TESTS_PASSED")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)
