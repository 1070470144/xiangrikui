extends SceneTree

func _initialize() -> void:
	call_deferred("capture_menu")

func capture_menu() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var main := scene.instantiate()
	root.add_child(main)
	await process_frame
	var menu = main.current_screen
	if menu == null:
		push_error("main menu was not created")
		quit(1)
		return
	menu.set_motion_enabled(false)
	var page := "home"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--page="):
			page = argument.trim_prefix("--page=")
	match page:
		"account": menu._show_account_switcher()
		"records": menu._show_night_records()
		"codex": menu._show_codex()
		"settings": menu._show_settings()
		_: menu._show_home()
	for _frame in range(4):
		await process_frame
	quit(0)
