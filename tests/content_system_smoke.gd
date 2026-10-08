extends SceneTree

const ContentData = preload("res://scripts/content_data.gd")
const Plant = preload("res://scripts/plant.gd")

var failures: Array[String] = []

func expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func _initialize() -> void:
	call_deferred("run_smoke")

func run_smoke() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	if scene == null: push_error("main scene failed to load"); quit(1); return
	var main := scene.instantiate(); root.add_child(main); await process_frame
	main.start_game(); await process_frame
	var game: Node = main.current_screen
	for path_id in ["sun_arrow", "root_heart", "dawn_pulse"]:
		game.reset_model()
		expect(game.choose_mother_card(path_id), "mother path must be selectable: %s" % path_id)
		for day in range(6):
			game.begin_day()
			var choices: Array[String] = game.get_mother_choices()
			expect(choices.size() == 3, "each later white day must offer three branch upgrades")
			if not choices.is_empty(): expect(game.choose_mother_card(choices[0]), "daily mother upgrade must be selectable")
		expect(game.mother_evolution.selected_upgrades.size() == 6, "mother path must receive six later upgrades")
	game.reset_model(); game.choose_mother_card("sun_arrow")
	for kind in range(10): game._spawn_enemy(kind, kind % 8)
	await process_frame
	var seen := {}
	for enemy in get_nodes_in_group("enemies"): seen[enemy.enemy_id] = true
	expect(seen.size() == 10, "campaign runtime must spawn every configured enemy kind")
	for enemy in get_nodes_in_group("enemies"): enemy.queue_free()
	await process_frame
	var card_ids: Array[String] = ["card_sun_pierce","card_weather_seal","card_time_stasis","card_root_wall","card_sun_mine","card_lure_bud","card_emergency_light","card_focus_mark","card_root_snare","card_emergency_dew","card_local_repair_rain","card_golden_domain"]
	game.combat_deck.start_run(card_ids, 1); game.combat_deck.hand.clear()
	for card_id in ["card_weather_seal","card_time_stasis","card_root_wall","card_golden_domain"]: game.combat_deck.hand.append(card_id)
	game.phase = game.Phase.NIGHT; game.light_energy = 100
	expect(game.play_combat_card("card_weather_seal", Vector2.ZERO).get("ok", false), "rare weather card must resolve")
	expect(game.play_combat_card("card_time_stasis", Vector2.ZERO).get("ok", false), "legendary global card must resolve")
	expect(game.play_combat_card("card_root_wall", game.battlefield.CENTER + Vector2(200, 100)).get("ok", false), "common ground card must resolve")
	await _verify_all_cards(game)
	game.reset_model(); game.choose_mother_card("root_heart"); game.wave_index = 1; game.progression.gain_run_seeds(4); game.seeds = game.progression.run_seeds
	var retreat: Dictionary = game.retreat_run(); expect(retreat.get("meta_seeds_gained", 0) == 4, "safe retreat must extract all earned seeds")
	var exported: Dictionary = game.export_profile()
	var clone: Node = game.get_script().new(); clone.import_profile(exported)
	expect(clone.export_profile().get("meta_seeds", 0) == exported.get("meta_seeds", -1), "progression must survive export and import")
	clone.progression.start_run(5); clone.progression.gain_run_seeds(9)
	expect(clone.settle_failure().get("meta_seeds_gained", 0) == 1, "failure must extract ten percent with minimum one")
	clone.progression.start_run(5); clone.progression.gain_run_seeds(7)
	expect(clone.settle_victory().get("meta_seeds_gained", 0) == 7, "victory must extract all earned seeds")
	clone.free(); game.queue_free(); await process_frame
	if failures.is_empty(): print("CONTENT SYSTEMS PASSED"); quit(0); return
	for failure in failures: push_error(failure)
	quit(1)

func _verify_all_cards(game: Node) -> void:
	game.reset_model(); game.choose_mother_card("sun_arrow")
	var node_point: Vector2 = game.battlefield.CENTER + Vector2(150, 0)
	game._place_light_node(node_point)
	var plant_point: Vector2 = node_point + Vector2(90, 0)
	game._place_plant_at(plant_point, game.Selection.THORN)
	var base_plant: Node = game.plants[0]; var base_node: Node = game.light_nodes[0]
	for card in ContentData.COMBAT_CARDS:
		var id := str(card["id"]); game.light_energy = 100
		game.phase = game.Phase.DAY if str(card["phase"]) == "day" else game.Phase.NIGHT
		game.combat_deck.hand.clear(); game.combat_deck.hand.append(id)
		var target: Variant = Vector2(game.battlefield.CENTER) + Vector2(170, 70)
		var target_type := str(card["target_type"])
		if target_type == "enemy":
			var enemy: Node = game.EnemyScript.new(); game.add_child(enemy); enemy.configure(game.EnemyScript.Kind.SHADOW_BEAST, game.battlefield.CENTER + Vector2(100, 0)); enemy.set_targets(game.mother_flower, game.light_nodes); target = enemy
		elif target_type == "plant":
			target = base_plant
		elif target_type == "node":
			base_node.take_damage(20.0); target = base_node
		elif target_type == "plant_or_node":
			base_plant.take_damage(20.0); target = base_plant
		elif target_type == "global":
			target = Vector2.ZERO
		if id == "card_transplant_shovel": target = {"plant":base_plant,"position":plant_point + Vector2(0, 70)}
		if id in ["card_local_repair_rain", "card_golden_rain"]: base_plant.take_damage(20.0); target = base_plant.global_position
		if id == "card_temporary_sprout": target = game.battlefield.CENTER + Vector2(180, 0)
		if id == "card_phantom_bloom": target = base_plant
		if id == "card_garden_resurrection":
			var dead: Node = Plant.new(); dead.global_position = game.battlefield.CENTER + Vector2(-220, 220); game.add_child(dead); dead.configure(Plant.Kind.THORN, 0); game.plants.append(dead); dead.take_damage(dead.max_health)
		var result: Dictionary = game.play_combat_card(id, target)
		expect(result.get("ok", false), "combat card must resolve with a legal target: %s" % id)
		for enemy in get_nodes_in_group("enemies"): enemy.queue_free()
		await process_frame
