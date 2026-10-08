extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var menu := preload("res://scripts/main_menu.gd").new()
	root.add_child(menu)
	menu.set_motion_enabled(false)
	menu.local_profile["level_progress"] = 3
	menu.local_profile["player_name"] = "温室守护者"
	menu.local_profile["play_time_minutes"] = 48
	menu._show_night_records()
	await process_frame
	var page := menu.page_stack.get_node("七夜记录Page")
	var selected := 4
	var destination := "res://art_source/evidence/night_records_runtime.png"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--night="): selected = int(argument.trim_prefix("--night="))
		if argument.begins_with("--capture="): destination = argument.trim_prefix("--capture=")
	page.select_night(selected)
	for frame in 4: await process_frame
	var viewport_bounds := root.get_viewport().get_visible_rect()
	for button in page.chapters:
		if not viewport_bounds.encloses(button.get_global_rect()):
			push_error("night chapter clipped"); quit(1); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination).get_base_dir())
	root.get_viewport().get_texture().get_image().save_png(destination)
	print("NIGHT RECORDS CAPTURE=", destination)
	quit(0)
