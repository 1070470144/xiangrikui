extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.world_camera.set_process(false)
	game.world_camera.position_smoothing_enabled = false
	game.mother_choice_pending = false
	game.hud.hide_mother_choices()
	game.choose_mother_card("sun_arrow")
	game.light_energy = 200
	game.seeds = 50
	var center: Vector2 = game.battlefield.CENTER
	game._place_light_node(center + Vector2(170, 0))
	game._place_plant_at(center + Vector2(210, -60), game.Selection.THORN)
	var enemy = game.EnemyScript.new()
	game.add_child(enemy)
	enemy.position = center + Vector2(-180, -100)
	enemy.set_process(false)
	game.phase = game.Phase.NIGHT
	game.weather = "thunderstorm"
	game.wave_index = 4
	game.spawn_queue.assign([{"time":99999.0, "kind":"shadow", "direction":0}])
	game.world_lighting.set_phase(false, 0.0)
	game._process(0.0)
	game.world_lighting._process(0.0)
	game.world_lighting.set_process(false)
	game.acid_rain_fx.set_process(false)
	game.thunderstorm_fx.set_process(false)
	DirAccess.make_dir_recursive_absolute("res://output/weather/composite_v1")
	for size in [Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = size
		root.content_scale_size = size
		game.world_camera.position = center
		game.world_camera.force_update_scroll()
		game.hud.update_battle_state(game.get_hud_battle_state())
		for i in range(24):
			game.acid_rain_fx._process(1.0 / 12.0)
			if i == 8:
				game.thunderstorm_fx.lightning_playing = true
				game.thunderstorm_fx.lightning_phase = 0.0
			game.thunderstorm_fx._process(1.0 / 12.0)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://output/weather/composite_v1/%dx%d-%02d.png" % [size.x, size.y, i])
	print("COMPOSITE_WEATHER_CAPTURE_PASSED")
	quit(0)
