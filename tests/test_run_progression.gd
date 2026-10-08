extends RefCounted

var failures: Array[String] = []

func expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func run() -> Array[String]:
	var script := ResourceLoader.load("res://scripts/game.gd", "Script", ResourceLoader.CACHE_MODE_REPLACE) as Script
	if script == null or not script.can_instantiate(): return ["game script must compile"]
	var game: Node = script.new(); game.reset_model()
	expect(game.has_method("get_mother_choices") and game.get_mother_choices().size() == 3, "new run must expose three mother directions")
	expect(game.mother_choice_pending, "first white day must require a mother choice")
	expect(game.has_signal("mother_choices_available"), "game must expose mother-card choices to the HUD")
	game.begin_night()
	expect(game.wave_index == 0 and game.phase == game.Phase.DAY, "night must not start before the daily mother choice")
	expect(game.choose_mother_card("sun_arrow"), "first white day must accept one mother direction")
	expect(not game.mother_choice_pending, "daily mother choice must close after one selection")
	expect(not game.choose_mother_card("mother_sunseed_01"), "same white day must not accept a second mother card")
	expect(game.get_mother_choices().size() == 3, "chosen path must expose three branch upgrades")
	expect(game.get_combat_hand().is_empty(), "first day must keep tactical cards in the draw pile")
	expect(not game.mulligan_combat_card("card_sun_pierce"), "daytime cannot trigger a tactical replacement draw")
	expect(game.can_retreat(), "every white day, including the first, must allow retreat")
	var first_day_game: Node = script.new(); first_day_game.reset_model(); var first_retreat: Dictionary = first_day_game.retreat_run()
	expect(first_retreat.get("meta_seeds_gained", -1) == 0, "first-day retreat must not extract initial seeds")
	first_day_game.free()
	var earned_before: int = game.progression.earned_seeds
	game._on_enemy_died(5, Vector2.ZERO)
	expect(game.progression.earned_seeds == earned_before, "enemy kills must reward light only, never meta seeds")
	game.wave_index = 1
	expect(not game.mulligan_combat_card("card_sun_pierce"), "later white days must not allow opening mulligan")
	expect(game.spend_run_seeds(2) and game.seeds == game.progression.run_seeds, "game seed spending must stay synchronized with progression")
	game.wave_index = 1; game.phase = game.Phase.DAY; game.progression.gain_run_seeds(3); game.seeds = game.progression.run_seeds
	expect(game.can_retreat(), "later white days must allow retreat")
	var result: Dictionary = game.retreat_run()
	expect(result.get("meta_seeds_gained") == 3 and game.phase == game.Phase.RETREATED, "retreat must settle all extractable seeds")
	game.free()
	test_meta_growth_applies_to_run_stats(script)
	test_sunburst_evolution_profile(script)
	test_temporary_content_cleanup(script)
	test_selected_deck_survives_run_reset(script)
	return failures

func test_meta_growth_applies_to_run_stats(game_script: Script) -> void:
	var game: Node = game_script.new()
	game.import_profile({"mother_meta_levels":{"max_health":3,"starting_energy":3,"day_regen":3,"sunburst_damage":3}})
	game.reset_model()
	expect(game.light_energy == 64, "starting-energy growth must apply at run start")
	expect(game.get_starting_mother_health() == 330.0, "maximum-health growth must apply at run start")
	expect(game.get_day_energy_regen() == 1.15, "day-regeneration growth must replace the base rate")
	expect(game.get_base_sunburst_damage() == 102.0, "sunburst growth must replace the base damage")
	game.free()

func test_sunburst_evolution_profile(game_script: Script) -> void:
	var game: Node = game_script.new(); game.reset_model(); game.choose_mother_card("sun_arrow")
	for rank in range(1, 7):
		game.begin_day(); game.choose_mother_card("mother_sunburst_%02d" % rank)
	var profile: Dictionary = game.get_sunburst_profile()
	expect(profile["cost"] == 35 and profile["damage"] == 115.0 and profile["radius"] == 170.0, "sunburst branch must alter cost, damage and radius")
	expect(profile["kill_energy"] == 2 and profile["refund_cap"] == 10, "sunburst kills must refund capped energy")
	expect(profile["afterglow_duration"] == 5.0 and profile["echo_damage_ratio"] == 0.55, "sunburst must expose afterglow and echo behavior")
	game.free()

func test_temporary_content_cleanup(game_script: Script) -> void:
	var temporary_script := ResourceLoader.load("res://scripts/temporary_battle_object.gd") as Script
	var plant_script := ResourceLoader.load("res://scripts/plant.gd") as Script
	var game: Node = game_script.new()
	var object: Node = temporary_script.new(); game.add_child(object); object.configure("card_root_wall", Vector2.ZERO, {"duration":18.0})
	var phantom: Node = plant_script.new(); phantom.configure(0, 0); phantom.temporary_lifetime = 20.0; game.add_child(phantom); game.plants.append(phantom)
	game.clear_temporary_battle_content()
	expect(not is_instance_valid(object), "temporary battle objects must be removed at run boundaries")
	expect(not is_instance_valid(phantom), "temporary phantom plants must be removed at run boundaries")
	game.free()

func test_selected_deck_survives_run_reset(game_script: Script) -> void:
	var deck: Array[String] = ["card_sun_pierce","card_sun_pierce","card_root_snare","card_root_snare","card_emergency_dew","card_emergency_dew","card_root_wall","card_root_wall","card_sun_mine","card_sun_mine","card_emergency_light","card_focus_mark"]
	var game: Node = game_script.new(); game.import_profile({"selected_deck":deck}); game.reset_model()
	var actual: Array[String] = []
	for id in game.combat_deck.draw_pile: actual.append(id)
	for id in game.combat_deck.hand: actual.append(id)
	actual.sort(); var expected := deck.duplicate(); expected.sort()
	expect(actual == expected, "a valid saved deck must remain the active run deck after reset")
	game.free()
