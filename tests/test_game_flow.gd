extends RefCounted

var failures: Array[String] = []

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func run() -> Array[String]:
	test_battlefield_contract()
	test_daylight_glow_contract()
	test_night_fog_contract()
	test_world_lighting_contract()
	test_game_state_contract()
	test_card_ui_contract()
	test_free_placement_costs_and_waves()
	return failures

func test_battlefield_contract() -> void:
	var script := _load_script("res://scripts/battlefield.gd")
	if script == null:
		return
	var battlefield: Node = script.new()
	battlefield._ready()
	expect(battlefield.find_child("EntranceDecorLayer", true, false) != null, "battlefield must expose a separate entrance decoration layer")
	expect(battlefield.WORLD_RECT.size == Vector2(2880, 2880), "battlefield must use a square 2880 world")
	expect(battlefield.spawn_positions.size() == 8, "battlefield must expose eight entrances")
	var unique_spawns: Dictionary = {}
	for position in battlefield.spawn_positions:
		unique_spawns[position] = true
	expect(unique_spawns.size() == 8, "all eight entrances must be unique")
	expect(battlefield.is_inside_plantable_area(battlefield.CENTER + Vector2(220, 0)), "middle ring land must be plantable")
	expect(not battlefield.is_inside_plantable_area(battlefield.CENTER), "mother flower core must block planting")
	expect(battlefield.is_inside_plantable_area(Vector2(10, 10)), "entire battlefield including the edge must allow deployment")
	expect(battlefield.is_inside_plantable_area(Vector2(2800, 2800)), "far battlefield corner must allow deployment")
	expect(not battlefield.is_inside_plantable_area(Vector2(-1, 10)), "outside world must block planting")
	for entrance in battlefield.spawn_positions:
		expect(battlefield.WORLD_RECT.has_point(entrance), "eight entrances must remain inside world")
		expect(entrance.distance_to(battlefield.CENTER) > 1300.0, "eight entrances must be near world perimeter")
	expect(not battlefield.is_position_clear(battlefield.CENTER + Vector2(220, 0), 24.0, [battlefield.CENTER + Vector2(230, 0)]), "nearby occupied positions must block planting")
	expect(battlefield.is_position_clear(battlefield.CENTER + Vector2(220, 0), 24.0, [battlefield.CENTER + Vector2(400, 0)]), "distant occupied positions must allow planting")
	var swamp_point: Vector2 = battlefield.CENTER + Vector2(220, 0)
	var swamp_cell: Vector2i = battlefield.terrain_map.world_to_cell(swamp_point)
	var swamp_cells: Array[Vector2i] = [swamp_cell]
	battlefield.terrain_map.apply_terrain_patch(swamp_cells, "swamp")
	expect(not battlefield.is_inside_plantable_area(swamp_point), "swamp terrain must block battlefield placement")
	battlefield.free()

func test_game_state_contract() -> void:
	var script := _load_script("res://scripts/game.gd")
	if script == null:
		return
	var game: Node = script.new()
	game.reset_model()
	game.world_lighting = preload("res://scripts/world_lighting.gd").new()
	game.add_child(game.world_lighting)
	expect(game.phase == 0, "new game must begin in day phase")
	expect(game.wave_index == 0, "new game must begin before first wave")
	expect(game.spend_energy(40), "game must allow affordable sunburst cost")
	expect(game.light_energy == 15, "sunburst must subtract exactly 40 energy")
	expect(not game.spend_energy(40), "game must reject unaffordable energy cost")
	game.regenerate_energy(1.5)
	expect(game.light_energy == 16, "daylight regeneration must restore one energy per second")
	for i in range(4):
		game.regenerate_energy(0.25)
	expect(game.light_energy == 17, "fractional frame regeneration must accumulate")
	expect(game.choose_mother_card("sun_arrow"), "day choice must be made before the first night")
	game.begin_night()
	expect(game.phase == 1 and game.wave_index == 1, "begin_night must enter first night")
	expect(game.world_lighting.get_lighting_state().target_daylight == 0.0, "night selects unified lighting")
	game.world_lighting.advance(1.5)
	expect(game.world_lighting.daylight_amount == 0.0, "night lighting settles after 1.5 seconds")
	expect(game.get_combat_hand().size() == 4, "first night draws the four opening tactical cards")
	expect(game.has_method("get_hud_battle_state"), "game must expose structured live HUD state")
	if game.has_method("get_hud_battle_state"):
		var hud_state: Dictionary = game.get_hud_battle_state()
		expect(hud_state.get("phase") == "night", "structured HUD state must report current phase")
		expect(int(hud_state.get("remaining_enemies", -1)) == game.spawn_queue.size(), "HUD enemy count must include the live spawn queue")
		expect(int(hud_state.get("sunburst_cost", -1)) == int(game.get_sunburst_profile()["cost"]), "HUD must use the evolved sunburst cost")
	game.begin_day()
	game.world_lighting.advance(1.5)
	expect(game.world_lighting.daylight_amount == 1.0, "begin_day restores unified lighting")
	game.free()

func test_card_ui_contract() -> void:
	var script := _load_script("res://scripts/game.gd")
	if script == null:
		return
	var game: Node = script.new()
	game.call("_build_world")
	game.hud.call("_build_ui")
	game.reset_model()
	expect(game.world_threat_feedback != null, "game must create world threat feedback")
	game.threat_levels = PackedFloat32Array([0.0, 0.2, 0.5, 0.0, 0.0, 0.0, 0.0, 0.0])
	if game.has_method("_update_readability_feedback"):
		game._update_readability_feedback()
		var states: Array[Dictionary] = game.world_threat_feedback.get_warning_states()
		expect(states[1]["severity"] == 1 and states[2]["severity"] == 2, "game must forward live threat state")
	else:
		expect(false, "game must update world readability feedback")
	expect(game.hud.find_child("MotherChoicePanel", true, false) != null, "new game must render the three mother-card choices")
	expect(game.hud.find_child("CombatHandPanel", true, false) != null, "new game must render the player's combat hand")
	var hand_panel := game.hud.find_child("CombatHandPanel", true, false) as Control
	expect(hand_panel.position.y >= 500.0, "combat hand must be anchored at the bottom of the screen")
	expect(game.hud.has_signal("mother_card_requested") and game.hud.has_signal("combat_card_requested"), "card UI must emit playable card selections")
	expect(game.world_camera.has_method("consume_click_was_dragged"), "left-drag camera movement must be distinguishable from battlefield clicks")
	expect(game.hud.find_child("SelectionPanel", true, false) != null, "battle HUD must expose a lower-left selection instrument")
	expect(game.hud.find_child("RadarFrame", true, false) != null, "battle HUD must frame the upper-right radar")
	expect(game.mother_flower.get_node_or_null("WorldHealthBar") != null, "mother flower must display a world-space health bar")
	game.hud.mother_card_requested.emit("sun_arrow")
	game.hud.wave_requested.emit()
	expect(game.phase == game.Phase.NIGHT and game.wave_index == 1, "choosing a mother card then pressing the night button must start night one")
	game.free()

func test_free_placement_costs_and_waves() -> void:
	var script := _load_script("res://scripts/game.gd")
	if script == null:
		return
	var game: Node = script.new()
	expect(game.get_light_sprout_cost(false) == 15, "day light sprout must cost 15 energy")
	expect(game.get_light_sprout_cost(true) == 23, "night emergency sprout must cost 23 energy")
	expect(game.get_plant_seed_cost(0) == 1, "thorn must cost one seed")
	expect(game.get_plant_seed_cost(1) == 2, "prism must cost two seeds")
	expect(game.waves.size() == 7, "campaign must contain seven nights")
	game.set_run_seed(42)
	game.reset_model()
	game.choose_mother_card("sun_arrow")
	game.begin_night()
	var first_positions: Dictionary = {}
	for entry in game.spawn_queue: first_positions[entry.spawn_position] = true
	expect(first_positions.size() == 18, "first night must use random individual spawn points")
	expect(game.waves[1].size() == 32, "second night must schedule exactly 32 enemies")
	expect(game.get_night_rule(3).get("weather") == "acid_rain", "third night must use acid rain")
	expect(game.get_night_rule(4).get("weather") == "thunderstorm", "fourth night must use thunderstorm")
	expect(game.has_method("_on_terrain_patch_applied"), "game must handle terrain patches as an isolated event")
	expect(game.get_night_rule(5).get("boss") == "root_colossus", "fifth night must contain the first boss")
	expect(game.get_night_rule(5).get("weather") == "fog", "fifth night must combine heavy fog with the root colossus")
	expect(game.get_night_rule(6).get("resupply", false), "sixth night must be a resupply night")
	expect(game.get_night_rule(7).get("boss") == "sun_devourer", "seventh night must contain the final boss")
	expect(not game.should_show_night_fog(1), "clear first night must not show the eclipse fog")
	expect(not game.should_show_night_fog(3), "acid-rain night must not show the eclipse fog")
	expect(game.should_show_night_fog(5), "the fifth-night root colossus battle must show heavy fog")
	expect(not game.should_show_night_fog(7), "the seventh-night eclipse must not reuse the fifth-night heavy fog")
	var enemy_script := _load_script("res://scripts/enemy.gd")
	if enemy_script != null:
		var first_boss: Node = enemy_script.new()
		first_boss.configure(2, Vector2.ZERO)
		expect(first_boss.max_health >= 400.0, "fifth-night boss must have boss-scale health")
		var final_boss: Node = enemy_script.new()
		final_boss.configure(3, Vector2.ZERO)
		expect(final_boss.max_health > first_boss.max_health, "final boss must be stronger than first boss")
		first_boss.free()
		final_boss.free()
	var battlefield_script := _load_script("res://scripts/battlefield.gd")
	if battlefield_script != null:
		var field: Node = battlefield_script.new()
		field.set_terrain_shift(2)
		expect(field.terrain_shift == 2, "thunderstorm must advance terrain state")
		field.free()
	var directions: Dictionary = {}
	for wave in game.waves:
		for entry in wave:
			directions[int(entry["direction"])] = true
	expect(directions.size() == 8, "wave formations must use all eight directions")
	game.free()

func test_night_fog_contract() -> void:
	var script := _load_script("res://scripts/night_fog.gd")
	if script == null:
		return
	var fog: Node = script.new()
	expect(not fog.is_active(), "night fog must begin disabled")
	expect(fog.get_world_size() == Vector2(2880, 2880), "night fog must cover the resized battlefield")
	expect(fog.get_light_center() == Vector2(1440, 1440), "night fog must follow the resized battlefield center")
	expect(fog.get_reveal_radius() == 90.0, "night fog reveal must scale with the battlefield")
	expect(fog.get_edge_opacity() >= 0.95, "night fog must fully obscure the battlefield edges")
	expect(fog.get_fog_brightness() >= 0.22, "night fog must read as visible mist instead of a black mask")
	fog.set_active(true)
	expect(fog.is_active(), "night fog must activate for night phase")
	fog.set_active(false)
	expect(not fog.is_active(), "night fog must deactivate for day phase")
	fog.free()

func test_daylight_glow_contract() -> void:
	var script := _load_script("res://scripts/daylight_glow.gd")
	if script == null:
		return
	var glow: Node = script.new()
	expect(glow.is_active(), "daylight glow must begin active")
	expect(glow.get_max_opacity() <= 0.30, "daylight glow must remain subtle")
	expect(glow.uses_directional_shafts(), "daylight must use directional volumetric shafts instead of radial rays")
	glow.set_active(false)
	expect(not glow.is_active(), "daylight glow must deactivate at night")
	glow.free()

func _load_script(path: String) -> Script:
	var script := ResourceLoader.load(path, "Script", ResourceLoader.CACHE_MODE_REPLACE) as Script
	if script == null or not script.can_instantiate():
		failures.append("script failed to compile: %s" % path)
		return null
	return script

func test_world_lighting_contract() -> void:
	var light := preload("res://scripts/world_lighting.gd").new()
	expect(light.daylight_amount == 1.0, "controller starts in day")
	light.set_phase(false)
	expect(light.daylight_amount == 1.0, "phase switch has no initial jump")
	light.advance(0.75)
	expect(is_equal_approx(light.daylight_amount, 0.5), "smooth transition midpoint")
	light.set_phase(true)
	expect(is_equal_approx(light.daylight_amount, 0.5), "reversing transition keeps current intensity")
	light.advance(1.5)
	expect(light.daylight_amount == 1.0, "reversed transition reaches daylight")
	light.set_phase(false, 0.0)
	var night: Dictionary = light.get_lighting_state()
	light.set_phase(true, 0.0)
	var day: Dictionary = light.get_lighting_state()
	expect(night.ambient_color.r < day.ambient_color.r, "night ambient light is dimmer")
	expect(night.shadow_strength < day.shadow_strength, "night directional shadows are weaker")
	light.set_phase(false)
	for i in range(200):
		light.advance(0.01)
		expect(is_finite(light.daylight_amount) and light.daylight_amount >= 0.0 and light.daylight_amount <= 1.0, "transition remains finite and bounded")
	light.set_phase(false)
	light.advance(-1.0)
	expect(light.daylight_amount == 0.0, "repeated phase and negative delta remain stable")
	var ground := FileAccess.get_file_as_string("res://assets/tilesets/continuous_ground.gdshader")
	for parameter in ["sun_direction", "ambient_color", "daylight_amount", "local_lights", "world_origin"]:
		expect(ground.contains(parameter), "ground lighting supports " + parameter)
	light.free()
