extends SceneTree

const Mother = preload("res://scripts/mother_flower.gd")
const MotherMotion = preload("res://scripts/mother_animation_library.gd")
var checks := 0

func _initialize() -> void: call_deferred("run")

func run() -> void:
	for test_path in ["res://tests/test_mother_evolution.gd", "res://tests/test_mother_danger_feedback.gd"]:
		var failures = load(test_path).new().run()
		assert(failures.is_empty(), str(failures))
	var frames := MotherMotion.load_frames()
	assert(frames != null and frames.get_frame_count("idle") > 0)
	assert(frames.get_animation_speed("idle") == 12.0)
	assert(MotherMotion.load_manifest("res://missing-manifest.json") == null)
	var invalid := "user://invalid-mother-manifest.json"
	var file := FileAccess.open(invalid, FileAccess.WRITE)
	file.store_string('{"status":"passed","fps":12,"frame_paths":["res://missing-frame.png"]}')
	file.close()
	assert(MotherMotion.load_manifest(invalid) == null)
	DirAccess.remove_absolute(invalid)
	var game := preload("res://scripts/game.gd").new()
	root.add_child(game)
	for i in range(5): await process_frame
	game.set_process(false)
	game.world_camera.set_process(false)
	game.world_camera.set_process_unhandled_input(false)
	game.mother_choice_pending = false
	game.hud.hide_mother_choices()
	var mother = game.mother_flower
	mother.set_process(false)
	for size in [Vector2i(1152,648),Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = size
		game.world_camera.focus_world(mother.global_position)
		game.world_camera.reset_smoothing()
		for state in ["healthy", "damaged", "critical", "evolved", "reset"]:
			mother.reset_state()
			if state == "damaged": mother.health = mother.max_health * 0.5
			if state == "critical": mother.health = mother.max_health * 0.2
			if state == "evolved":
				assert(mother.choose_path("sun_arrow"))
				assert(mother.choose_evolution("mother_corona_01"))
			mother._update_art_texture(mother.health / mother.max_health)
			mother._process(0.0)
			game.hud.update_battle_state(game.get_hud_battle_state())
			var animated := true
			assert(mother.motion_sprite.visible and mother.motion_sprite.is_playing())
			assert(not mother.art_sprite.visible)
			assert(mother.motion_sprite.rotation == 0.0)
			checks += 1
			for i in range(5): await process_frame
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://output/imagegen/previews/mother-realism-%s-%dx%d.png" % [state,size.x,size.y])
	print("MOTHER_REALISM_PASS: %d state/resolution checks, manifest and evolution/danger suites" % checks)
	quit(0)
