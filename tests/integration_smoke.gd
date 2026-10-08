extends SceneTree

var failures: Array[String] = []

func expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func _initialize() -> void:
	call_deferred("run_smoke")

func run_smoke() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	if scene == null: push_error("main scene failed to load"); quit(1); return
	var main := scene.instantiate()
	root.add_child(main)
	await process_frame
	main.start_game()
	await process_frame
	var game: Node = main.current_screen
	expect(game.battlefield.WORLD_RECT.size == Vector2(2880, 2880), "battlefield must use the shared 2880 world")
	expect(game.battlefield.spawn_positions.size() == 8, "battlefield must have eight entrances")
	expect(game.world_camera != null, "game must create movable world camera")
	expect(game.hud.radar != null, "HUD must create light-network radar")
	expect(game.hud.light_sprout_button != null, "HUD must expose light sprout action")
	expect(game.choose_mother_card("sun_arrow"), "integration run must choose the first-day mother direction")
	game._select_plant(game.Selection.LIGHT_SPROUT)
	var node_point: Vector2 = Vector2(game.battlefield.CENTER) + Vector2(170, 0)
	game._handle_click(node_point)
	expect(game.light_nodes.size() == 1, "free click must plant a light sprout")
	expect(game.light_energy == 40, "day light sprout must spend fifteen energy")
	game._select_plant(game.Selection.THORN)
	game._handle_click(node_point + Vector2(120, 0))
	expect(game.plants.size() == 1, "plant must be placeable inside supplied land")
	expect(game.seeds == 4, "thorn placement must spend one seed")
	game.begin_night()
	expect(not game.night_fog.is_active(), "clear first night must not activate the eclipse fog")
	game._select_plant(game.Selection.LIGHT_SPROUT)
	var energy_before: int = int(game.light_energy)
	game._handle_click(node_point + Vector2(0, 150))
	expect(game.light_energy == energy_before - 23, "night emergency sprout must spend twenty-three energy")
	game.spawn_clock = 32.0
	game._process_spawns()
	expect(get_nodes_in_group("enemies").size() == game.waves[0].size(), "first formation must spawn its configured enemies")
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await process_frame
	game.wave_index = 5
	game.phase = game.Phase.DAY
	game.light_energy = 10
	game.progression.run_seeds = 1
	game.progression.earned_seeds = 0
	game.seeds = 1
	game.mother_flower.health = 100.0
	game.begin_night()
	expect(game.phase == game.Phase.DAY and game.wave_index == 6, "night six must remain a non-combat resupply day")
	expect(game.light_energy == 50 and game.seeds == 6, "resupply night must grant forty energy and five seeds")
	expect(game.mother_flower.health == 160.0, "resupply night must heal mother flower by sixty")
	game.wave_index = 7
	game.phase = game.Phase.NIGHT
	game._finish_wave()
	expect(game.phase == game.Phase.VICTORY, "clearing final boss night must cause victory")
	game.queue_free()
	await process_frame
	if failures.is_empty(): print("INTEGRATION PASSED"); quit(0); return
	for failure in failures: push_error(failure)
	quit(1)
