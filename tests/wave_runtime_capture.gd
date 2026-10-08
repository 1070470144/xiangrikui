extends SceneTree

const Game = preload("res://scripts/game.gd")
const Balance = preload("res://scripts/balance.gd")
const Spec = preload("res://scripts/battlefield_spec.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var report: Array = []
	for night in [1, 4, 7]:
		var game := Game.new()
		game.set_run_seed(8080)
		root.add_child(game)
		game.choose_mother_card("sun_arrow")
		game.set_process(false)
		game.wave_index = night - 1
		game.mother_choice_pending = false
		game.mother_flower.max_health = 1000000.0
		game.mother_flower.health = 1000000.0
		game.begin_night()
		game.hud.hide()
		var expected := game.spawn_queue.duplicate(true)
		game.spawn_clock = Balance.NIGHT_CONFIGS[night - 1].duration + 1.0
		game._process_spawns()
		var enemies := get_nodes_in_group("enemies")
		assert(enemies.size() == Balance.WAVES[night - 1].size())
		for index in enemies.size():
			var enemy: Node = enemies[index]
			var values: Dictionary = preload("res://scripts/content_data.gd").get_enemy(enemy.enemy_id)
			assert(is_equal_approx(enemy.max_health, values.health * expected[index].health_multiplier))
			assert(is_equal_approx(enemy.attack_damage, values.damage * expected[index].damage_multiplier))
			assert(is_equal_approx(enemy.light_reward, expected[index].reward))
		game.world_camera.set_process(false)
		game.world_camera.position = Spec.CENTER
		game.world_camera.zoom = Vector2.ONE * 0.18
		for frame in 60: await process_frame
		var started := Time.get_ticks_usec()
		var worst := 0.0
		for frame in 180:
			var stamp := Time.get_ticks_usec()
			await process_frame
			worst = maxf(worst, float(Time.get_ticks_usec() - stamp) / 1000.0)
		var fps := 180000000.0 / float(Time.get_ticks_usec() - started)
		report.append({"night":night, "alive":enemies.size(), "fps":fps, "worst_frame_ms":worst, "mode":"all scheduled enemies simultaneously, perimeter overview"})
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/wave-night-%d.png" % night)
		for enemy in get_nodes_in_group("enemies"): enemy.queue_free()
		await process_frame
		assert(game.spawn_queue.is_empty() and get_nodes_in_group("enemies").is_empty())
		game._process(0.0)
		assert(game.phase == (Game.Phase.VICTORY if night == 7 else Game.Phase.DAY))
		game.queue_free()
		await process_frame
	var file := FileAccess.open("res://tmp/wave-runtime-review.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("WAVE_RUNTIME_PASS ", JSON.stringify(report))
	quit()
