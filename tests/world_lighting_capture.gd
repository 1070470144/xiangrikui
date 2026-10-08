extends SceneTree

var game: Node2D
var failures: Array[String] = []
var capture := false

func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func run() -> void:
	var contracts := preload("res://tests/test_game_flow.gd").new()
	contracts.test_world_lighting_contract()
	contracts.test_game_state_contract()
	failures.append_array(contracts.failures)
	failures.append_array(preload("res://tests/test_fog_reveal.gd").new().run())
	root.size = Vector2i(1280, 720)
	game = load("res://scripts/game.gd").new()
	root.add_child(game)
	await process_frame
	game.choose_mother_card("sun_arrow")
	game.set_process(false)
	game.hud.hide_mother_choices()
	game.light_energy = 200
	game.seeds = 50
	var center: Vector2 = game.battlefield.CENTER
	game._place_light_node(center + Vector2(170, 0))
	game._place_light_node(center + Vector2(320, 60))
	game._place_plant_at(center + Vector2(240, -70), game.Selection.THORN)
	game._place_plant_at(center + Vector2(320, 150), game.Selection.PRISM)
	var enemy: Node2D = game.EnemyScript.new()
	enemy.position = center + Vector2(-240, -80)
	game.add_child(enemy)
	enemy.set_process(false)
	game.world_camera.set_process(false)
	game.world_camera.zoom = Vector2.ONE
	game.world_camera.position = center + Vector2(60, 0)
	game.world_camera.position_smoothing_enabled = false
	await process_frame
	check(game.world_lighting.daylight_amount == 1.0, "initial daylight")
	check(game.light_nodes.size() == 2 and game.plants.size() == 2, "representative actors placed")
	if game.light_nodes.size() != 2 or game.plants.size() != 2:
		push_error("lighting fixture placement failed")
		quit(1)
		return
	check(game.battlefield.terrain_map.contact_shadows.bodies.size() == 6, "all living bodies cast contact shadows")
	check(game.plants[0].animation_sprite.use_parent_material, "animated plant receives lighting")
	check(enemy.art_sprite.use_parent_material, "enemy receives lighting")
	check(game.mother_flower.motion_sprite.use_parent_material, "mother animation receives lighting")
	check(game.hud is CanvasLayer, "HUD remains on independent canvas layer")
	check(game.world_lighting.get_reveal_sources().size() == 5, "mother, plants and nodes reveal fog; enemies do not")
	for plant in game.plants: plant.set_process(false)
	await save_view("day")
	game.begin_night()
	game.world_lighting.set_process(false)
	check(game.world_lighting.daylight_amount == 1.0, "night starts without a jump")
	game.world_lighting._process(0.75)
	check(is_equal_approx(game.world_lighting.daylight_amount, 0.5), "transition midpoint")
	await save_view("transition")
	game.world_lighting._process(0.75)
	check(game.world_lighting.daylight_amount == 0.0, "night completes in 1.5 seconds")
	check(game.battlefield.terrain_map.ground_tile_map.material.get_shader_parameter("light_count") == 3, "ground receives all active lights")
	var powered_tint: Color = game.world_lighting.get_surface_tint(game.light_nodes[1].global_position)
	await save_view("night")
	# Camera transforms must move the view without changing world lighting inputs.
	var ground_material: ShaderMaterial = game.battlefield.terrain_map.ground_tile_map.material
	var origin: Vector2 = ground_material.get_shader_parameter("world_origin")
	var sources: PackedVector4Array = ground_material.get_shader_parameter("local_lights")
	var camera_position: Vector2 = game.world_camera.position
	var screen_point: Vector2 = game.plants[0].get_global_transform_with_canvas().origin
	game.world_camera.position += Vector2(160, 80)
	game.world_camera.zoom = Vector2(0.8, 0.8)
	game.world_camera.force_update_scroll()
	await process_frame
	game.world_lighting._process(0.0)
	check(not screen_point.is_equal_approx(game.plants[0].get_global_transform_with_canvas().origin), "camera pan and zoom change the view")
	check(ground_material.get_shader_parameter("world_origin") == origin, "camera movement preserves ground sampling origin")
	check(ground_material.get_shader_parameter("local_lights") == sources, "camera movement preserves world light positions")
	game.world_camera.position = camera_position
	game.world_camera.zoom = Vector2.ONE
	game.world_camera.force_update_scroll()
	game.light_nodes[1].take_damage(1000.0)
	game.world_lighting._process(0.0)
	check(game.battlefield.terrain_map.ground_tile_map.material.get_shader_parameter("light_count") == 2, "broken source stops lighting ground")
	var broken_tint: Color = game.world_lighting.get_surface_tint(game.light_nodes[1].global_position)
	check(broken_tint.r < powered_tint.r, "broken source reduces nearby warmth")
	await save_view("night-broken")
	game.night_fog.set_active(true)
	game.night_fog._process(2.0)
	game.world_lighting._process(0.0)
	check(game.night_fog.visible, "weather fog visible at night")
	await save_view("night-fog")
	await test_fog_expansion()
	game.begin_day()
	check(game.world_lighting.get_lighting_state().target_daylight == 1.0, "begin_day restores daylight target")
	game.world_lighting._process(1.5)
	check(game.world_lighting.daylight_amount == 1.0 and not game.night_fog.visible, "day returns without fog")
	game.settle_failure()
	check(game.world_lighting.get_lighting_state().target_daylight == 0.0, "failure selects night")
	check(not game.daylight_glow.is_active(), "failure disables daytime shafts")
	game.night_fog.set_active(true)
	game.settle_victory()
	check(game.world_lighting.get_lighting_state().target_daylight == 1.0, "victory selects dawn")
	check(game.daylight_glow.is_active() and not game.night_fog.is_active(), "victory synchronizes weather and shafts")
	game.reset_model()
	check(game.world_lighting.daylight_amount == 1.0, "reset immediately returns day")
	check(game.night_fog._reveal_sources.is_empty(), "game reset clears old reveal sources immediately")
	game.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	print("WORLD_LIGHTING_PASS" if failures.is_empty() else "WORLD_LIGHTING_FAILED")
	quit(0 if failures.is_empty() else 1)

func test_fog_expansion() -> void:
	var fog: Node = game.night_fog
	fog.set_process(false)
	# Establish a mother-only baseline, then let actual powered actors open fog.
	fog.clear_reveal_sources()
	var mother_sources: Array[Dictionary] = [{"id":game.mother_flower.get_instance_id(), "position":game.mother_flower.global_position, "radius":90.0}]
	fog.set_reveal_sources(mother_sources)
	fog._process(0.5)
	await save_view("fog-before-expansion")
	game.world_lighting._process(0.0)
	fog._process(0.5)
	check(fog._reveal_sources.size() == 4, "broken node excluded from vision, living plants included")
	await save_view("fog-expanded")
	var image_before: PackedByteArray = fog._reveal_image.get_data()
	var camera_position: Vector2 = game.world_camera.position
	game.world_camera.position += Vector2(120, 60)
	game.world_camera.zoom = Vector2(0.7, 0.7)
	game.world_camera.force_update_scroll()
	await process_frame
	game.world_lighting._process(0.0)
	fog._process(0.1)
	check(fog._reveal_image.get_data() == image_before, "camera pan and zoom preserve the world reveal mask")
	game.world_camera.position = camera_position
	game.world_camera.zoom = Vector2.ONE
	game.world_camera.force_update_scroll()
	for plant in game.plants:
		plant.set_powered(false)
	check(game.world_lighting.get_reveal_sources().size() == 4, "stored light continues revealing fog")
	for plant in game.plants:
		plant.advance_power_state(plant.power_state_time)
	check(game.world_lighting.get_reveal_sources().size() == 4, "low light continues revealing fog")
	for plant in game.plants:
		plant.advance_power_state(plant.power_state_time)
	game.light_nodes[0].is_connected_to_light = false
	game.world_lighting._process(0.0)
	fog._process(0.25)
	check(fog._reveal_sources.size() == 4, "dormant plants and disconnected node retain only fading vision")
	fog._process(0.25)
	check(fog._reveal_sources.size() == 1, "dormancy and disconnection return fog after 0.5 seconds")
	await save_view("fog-power-lost")
	game.light_nodes[0].is_connected_to_light = true
	for plant in game.plants: plant.set_powered(true)
	game.world_lighting._process(0.0)
	fog._process(0.5)
	check(fog._reveal_image.get_data() == image_before, "restored power reopens exactly the original region")
	await save_view("fog-power-restored")
	game.plants[0].health = 0.0
	game.world_lighting._process(0.0)
	fog._process(0.5)
	check(fog._reveal_sources.size() == 3, "dead plant stops revealing even if power remains")
	game.plants[0].health = game.plants[0].max_health
	game.world_lighting._process(0.0)
	fog._process(0.5)

func save_view(label: String) -> void:
	if not capture: return
	game.hud.update_battle_state(game.get_hud_battle_state())
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://output/lighting")
	root.get_texture().get_image().save_png("res://output/lighting/" + label + ".png")
