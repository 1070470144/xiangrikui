extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	game.set_run_seed(777)
	root.add_child(game)
	current_scene = game
	await create_timer(1.0).timeout
	game.choose_mother_card("sun_arrow")
	game.hud.hide_mother_choices()
	game.world_camera.position_smoothing_enabled = false
	game.world_camera.position = game.mother_flower.position
	game.world_camera.zoom = Vector2.ONE * 1.5
	game.mother_flower.on_night_started()
	game.phase = game.Phase.NIGHT
	var enemy = load("res://scripts/enemy.gd").new()
	enemy.position = game.mother_flower.position + Vector2(170, -25)
	game.add_child(enemy)
	enemy.health = 10000.0
	enemy.max_health = 10000.0
	enemy.set_process(false)
	game._register_enemy(enemy)
	for i in range(48):
		await create_timer(1.0/24.0).timeout
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		image.save_png("res://tmp/sun-arrow-capture-%03d.png" % i)
	print("SUN ARROW CAPTURE PASSED")
	quit()
