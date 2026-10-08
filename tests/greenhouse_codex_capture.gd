extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var menu := preload("res://scripts/main_menu.gd").new()
	root.add_child(menu)
	menu.set_motion_enabled(false)
	menu._show_codex()
	var view := menu.page_stack.get_node("温室图鉴Page")
	var destination := "res://art_source/evidence/greenhouse_codex_runtime.png"
	for argument in OS.get_cmdline_user_args():
		if argument == "--monsters": view.select_category(1)
		if argument == "--second": view.select_entry(1)
		if argument.begins_with("--capture="): destination = argument.trim_prefix("--capture=")
	for frame in 4: await process_frame
	assert(view.hero.size == Vector2(451, 369))
	assert(root.get_viewport().get_visible_rect().encloses(view.stats.get_global_rect()))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination).get_base_dir())
	root.get_viewport().get_texture().get_image().save_png(destination)
	print("CODEX CAPTURE=", destination)
	quit(0)
