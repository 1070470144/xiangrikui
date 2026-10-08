extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280,720)
	var game := preload("res://scripts/game.gd").new(); root.add_child(game)
	for i in range(4): await process_frame
	game.set_process(false)
	assert(game.choose_mother_card("sun_arrow"))
	for rank in range(1,7):
		game.mother_choice_pending = true
		assert(game.choose_mother_card("mother_corona_%02d" % rank))
	game.mother_flower.set_process(false)
	game.mother_choice_pending = false
	game.hud.hide_mother_choices()
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/imagegen/previews/mother-evolved-battle-1280x720.png")
	print("MOTHER_FORMS_CAPTURE_PASS")
	quit(0)
