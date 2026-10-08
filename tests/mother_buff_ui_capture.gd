extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var capture_size := Vector2i(1280,720)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			capture_size = Vector2i(int(parts[0]),int(parts[1]))
	root.size = capture_size
	var game := load("res://scripts/game.gd").new() as Node2D
	root.add_child(game)
	for i in range(5): await process_frame
	game.set_process(false)
	var suffix := "-%dx%d" % [capture_size.x,capture_size.y]
	var options: Array[String] = ["sun_arrow","root_heart","dawn_pulse"]
	game.hud.show_mother_choices(options)
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/imagegen/previews/mother-buff-paths"+suffix+".png")
	options = ["mother_corona_05","mother_sunburst_06","mother_sunseed_04"]
	game.hud.show_mother_choices(options)
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/imagegen/previews/mother-buff-effects"+suffix+".png")
	var present := preload("res://scripts/mother_upgrade_presentation.gd")
	for entry in preload("res://scripts/content_data.gd").MOTHER_UPGRADES:
		assert(not present.description(entry.id).is_empty())
	for card in game.hud.mother_choice_row.get_children():
		var paper := card.find_child("EffectPaper",true,false) as PanelContainer
		var effect := card.find_child("Effect",true,false) as Label
		assert(paper.get_rect().size.y >= effect.get_minimum_size().y)
		assert(card.get_global_rect().position.y >= 0)
		assert(card.get_global_rect().end.y <= capture_size.y)
	var button := game.hud.mother_choice_row.get_child(0) as Button
	var received := []
	game.hud.mother_card_requested.connect(func(id): received.append(id))
	var move := InputEventMouseMotion.new(); move.position = button.get_global_rect().get_center(); root.push_input(move)
	await process_frame
	var down := InputEventMouseButton.new(); down.button_index = MOUSE_BUTTON_LEFT; down.pressed = true; down.position = move.position; root.push_input(down)
	await process_frame
	var up := InputEventMouseButton.new(); up.button_index = MOUSE_BUTTON_LEFT; up.pressed = false; up.position = move.position; root.push_input(up)
	await process_frame
	assert(received.size() == 1)
	assert(received[0] == "mother_corona_05")
	print("MOTHER_BUFF_UI_PASS 54 descriptions, geometry, real mouse choice ",capture_size)
	quit()
