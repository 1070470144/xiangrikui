extends "res://tests/test_card_drag_integration.gd"

func fixture(ids: Array[String], phase: int = 1, energy: int = 100) -> void:
	await super.fixture(ids, phase, energy)
	game.world_camera.zoom = Vector2.ONE * 1.35
	game.world_camera.force_update_scroll()
	await frame()

func pointer(point: Vector2) -> void:
	await motion(screen(point), true)
	# Fixture freezes simulation, so refresh only the normal read-only pointer pass.
	game._update_pointer_preview()
	await frame()

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await frame()
	await RenderingServer.frame_post_draw
	var directory := "res://output/imagegen/previews"
	DirAccess.make_dir_recursive_absolute(directory)
	viewport.get_texture().get_image().save_png(directory + "/battle-ui-v6-" + name + ".png")

func run() -> void:
	var world := Vector2(1550, 1340)
	await fixture(["card_transplant_shovel"], 0)
	game.world_camera.zoom = Vector2.ONE * 1.35
	game.world_camera.force_update_scroll()
	await start_control(game.hud.thorn_button)
	await pointer(world)
	check(game.drag_world_preview.visible, "Native plant drag shows world preview")
	check(game.drag_world_preview.ghost.texture == load("res://assets/plants/ART_PLANT_ThornFlower_Powered.png"), "Ghost is the actual plant art")
	check(game.drag_world_preview.ghost.scale == Vector2.ONE * 0.58, "Ghost retains planted sprite world scale")
	check(game.drag_world_preview.valid and game.drag_world_preview.global_position.distance_to(world) < 0.1, "Valid ghost follows actual transformed mouse coordinate")
	check(game.drag_world_preview.effect_radius == 0.0, "Thorn does not invent a placement effect area")
	check(game.plants.is_empty() and game.progression.run_seeds == 5, "Preview neither plants nor spends seeds")
	await capture("plant-drag")
	await pointer(Vector2(1440,1440))
	check(not game.drag_world_preview.valid, "Blocked mother core is red and invalid")
	await capture("invalid-plant")
	await drop(screen(world))
	check(not game.drag_world_preview.visible and game.plants.size() == 1, "Valid release plants exactly once and clears ghost")

	await fixture(["card_transplant_shovel"], 0)
	await start_control(game.hud.light_sprout_button)
	await pointer(world)
	check(game.drag_world_preview.effect_radius == 190.0 and game.drag_world_preview.has_parent, "Light sprout preview displays real supply radius and network connection")
	game.light_energy = 0
	game._update_pointer_preview()
	check(not game.drag_world_preview.valid, "Insufficient energy invalidates live preview")
	await drop(screen(world))
	check(game.light_nodes.is_empty(), "Invalid plant drag never spawns node")

	var radii := {"card_root_snare":70.0,"card_sun_arrow_rain":70.0,"card_root_wall":160.0,"card_local_repair_rain":100.0,"card_golden_domain":210.0,"card_sun_mine":65.0,"card_temporary_sprout":170.0}
	for id in radii:
		await fixture([id])
		await start()
		await pointer(world)
		check(game.drag_world_preview.visible and game.drag_world_preview.valid, id + " valid range preview")
		check(game.drag_world_preview.effect_radius == radii[id], id + " matches resolver effect radius")
		untouched(100, [id], id + " preview")
		if id == "card_root_snare": await capture("area-drag")
		await button(true, MOUSE_BUTTON_RIGHT)
		game._update_pointer_preview()
		check(not game.drag_world_preview.visible, "Right cancel clears preview immediately")
		await drop(screen(world))
		untouched(100, [id], id + " cancelled")

	await fixture(["card_sun_pierce"])
	var enemy := TargetEnemy.new()
	enemy.position = world; enemy.add_to_group("enemies"); game.add_child(enemy)
	await start()
	await pointer(world + Vector2(12,12))
	check(game.drag_world_preview.valid and game.drag_world_preview.global_position == enemy.global_position, "Single enemy card snaps feedback to actual target")
	check(game.drag_world_preview.effect_radius == 0.0, "Single target card shows no fictitious AoE")
	await drop(screen(world))
	check(enemy.health == 58.0 and not game.drag_world_preview.visible, "Enemy card release retains damage and clears preview")

	await fixture(["card_weather_seal"])
	await start()
	await pointer(world)
	check(game.drag_world_preview.global_target and game.drag_world_preview.effect_radius == 0.0, "Global effects label entire battlefield without a fictitious finite range")
	check(game.weather_seal_time == 0.0, "Global drag preview cannot cast")
	game.mother_choice_pending = true
	game._update_pointer_preview()
	check(not game.drag_world_preview.visible, "Modal clears live world feedback")
	await drop(screen(world))
	untouched(100, ["card_weather_seal"], "Modal during drag")

	await fixture(["card_golden_rain"])
	await start()
	await pointer(world)
	game.phase = 0
	game._update_pointer_preview()
	check(not game.drag_world_preview.visible, "Phase change clears preview")
	await drop(screen(world))
	untouched(100, ["card_golden_rain"], "Any-phase card still rejected if phase changes during drag")
	if failures.is_empty(): print("DRAG WORLD PREVIEW PASSED (0 failures)")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
