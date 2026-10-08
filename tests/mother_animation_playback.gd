extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	root.size = Vector2i(640,480)
	var mother = preload("res://scripts/mother_flower.gd").new()
	mother.position = Vector2(320,260)
	root.add_child(mother)
	for i in range(3): await process_frame
	var first_frame: int = mother.motion_sprite.frame
	await create_timer(0.3).timeout
	assert(mother.motion_sprite.is_playing())
	assert(mother.motion_sprite.frame != first_frame, "healthy video must advance actual frames")
	for state in ["damaged", "critical", "evolved"]:
		mother.reset_state()
		if state == "damaged": mother.health = mother.max_health * 0.5
		if state == "critical": mother.health = mother.max_health * 0.2
		if state == "evolved":
			assert(mother.choose_path("sun_arrow"))
			assert(mother.choose_evolution("mother_corona_01"))
		mother._update_art_texture(mother.health / mother.max_health)
		await create_timer(0.7).timeout
		assert(mother.motion_sprite.visible and mother.motion_sprite.is_playing())
		var frame_before: int = mother.motion_sprite.frame
		var before: Image
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			before = root.get_texture().get_image()
		await create_timer(0.6).timeout
		assert(mother.motion_sprite.frame != frame_before, "visible plant must advance actual frames")
		if before != null:
			await RenderingServer.frame_post_draw
			var after := root.get_texture().get_image()
			assert(before.get_data() != after.get_data(), "visible plant must change across time")
			before.save_png("res://tmp/mother-motion-%s-before.png" % state)
			after.save_png("res://tmp/mother-motion-%s-after.png" % state)
	mother.reset_state()
	assert(mother.motion_sprite.visible and mother.motion_sprite.is_playing())
	print("MOTHER_PLAYBACK_PASS: video frame advancement, damaged/critical/evolved visible motion, reset")
	quit(0)
