extends SceneTree

const Roster = preload("res://scripts/plant_roster.gd")
const Plant = preload("res://scripts/plant.gd")
const Enemy = preload("res://scripts/enemy.gd")
var failures: Array[String] = []
var checks := 0
var game: Node
var enemy_a: Node2D
var enemy_b: Node2D
var enemy_c: Node2D

func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func specimen(kind: int) -> Node2D:
	var plant := Plant.new(); plant.kind = kind; root.add_child(plant); plant.set_process(false); return plant
func run() -> void:
	game = preload("res://scripts/game.gd").new(); root.add_child(game); game.set_process(false)
	await process_frame
	game.mother_choice_pending = false; game.hud.hide_mother_choices()
	check(game.get_carried_plant_ids().size() == 5, "Default five filled slots")
	check(Roster.DEPLOY_IDS.size() == 15, "Existing five plus ten plants")
	check(not game.set_carried_plant_ids(Roster.DEPLOY_IDS.slice(0,6)), "Sixth plant rejected at gameplay API")
	check(not game.set_carried_plant_ids(["deploy_storm","deploy_storm"]), "Duplicate species rejected")
	check(not game.set_carried_plant_ids([]), "Empty loadout rejected")
	check(game.set_carried_plant_ids(["deploy_storm","deploy_gale","deploy_sunwell","deploy_ember","deploy_slumber"]), "New five selected")
	game.hud.show_plant_loadout(game.get_carried_plant_ids())
	var overlay: Node = game.hud.plant_loadout_overlay
	check(overlay.slot_labels.size() == 5 and overlay.choices.size() == 15, "Five physical slots and full catalogue")
	check(overlay._selected().size() == 5, "Loadout opens with active selection")
	overlay.choices[10].button_pressed = true
	check(overlay._selected().size() == 5 and not overlay.choices[10].button_pressed, "UI rejects sixth pick")
	game.hud.hide_plant_loadout()
	check(not game.can_deploy_plant(game.Selection.THORN), "Uncarried species denied")
	game.phase = game.Phase.NIGHT
	check(not game.set_carried_plant_ids(["deploy_storm"]), "Night cannot change loadout")
	check(not game.can_deploy_plant(game.Selection.STORM), "Night cannot plant")
	game.reset_model()
	check(game.get_carried_plant_ids() == game.carried_plant_ids and game.carried_plant_ids[0] == "deploy_thorn", "Reset restores default slots")
	game.mother_choice_pending = false
	for index in range(5,15):
		game.set_carried_plant_ids([Roster.DEPLOY_IDS[index]])
		game.progression.run_seeds = 10
		var selection: int = Roster.SELECTIONS[index]; var position := Vector2.INF
		for angle_index in range(24):
			var candidate := Vector2(1440,1440)+Vector2.from_angle(TAU*angle_index/24.0)*150.0
			if game.can_place_plant(candidate,selection): position = candidate; break
		check(position != Vector2.INF, "New species valid supplied placement " + Roster.FLOWER_IDS[index])
		if position == Vector2.INF: continue
		var count: int = game.plants.size(); game._place_plant_at(position,selection)
		check(game.plants.size() == count+1 and game.plants[-1].kind == index and game.progression.run_seeds == 8, "Actual deployment kind and single seed spend " + Roster.FLOWER_IDS[index])
		var placed: Node = game.plants.pop_back(); placed.free()
		game._rebuild_network()
	for i in range(3):
		var enemy := Enemy.new(); enemy.configure_by_id("shadow_beast",Vector2(90+i*35,0)); root.add_child(enemy); enemy.set_process(false)
		if i == 0: enemy_a = enemy
		elif i == 1: enemy_b = enemy
		else: enemy_c = enemy
	var storm := specimen(Plant.Kind.STORM); storm._attack_special(enemy_a)
	check(enemy_a.health < enemy_a.max_health and enemy_b.health < enemy_b.max_health and enemy_c.health < enemy_c.max_health, "Chain reaches three live enemies")
	var gale := specimen(Plant.Kind.GALE); var before := enemy_a.position; gale._attack_special(enemy_a)
	check(enemy_a.position.distance_to(before) > 30, "Gale pushes actual enemy")
	var ember := specimen(Plant.Kind.EMBER); ember._attack_special(enemy_a)
	check(enemy_a.burn_time > 0.0, "Ember applies ticking burn")
	var slumber := specimen(Plant.Kind.SLUMBER); slumber._attack_special(enemy_a)
	check(enemy_a.stun_time > 0.0, "Slumber controls enemy")
	var stone := specimen(Plant.Kind.STONE); stone.take_damage(100)
	check(is_equal_approx(stone.health,stone.max_health-60), "Stone reduces actual damage")
	var patient := specimen(Plant.Kind.THORN); patient.health = 50; patient.apply_corrosion(4,8)
	var cleanse := specimen(Plant.Kind.CLEANSE); cleanse._activate_support()
	check(patient.corrosion_time == 0.0 and patient.health > 50, "Cleanse removes corrosion and heals")
	var drum := specimen(Plant.Kind.DRUM); drum._activate_support()
	check(patient.get_effective_interval_multiplier() < 1, "Drum grants actual attack speed")
	patient._process(3.0)
	check(patient.inspiration_multiplier == 1.0, "Inspiration expires without source")
	var sunwell := specimen(Plant.Kind.SUNWELL); var energy := [0]
	sunwell.energy_generated.connect(func(amount: int): energy[0] += amount)
	check(not sunwell._activate_support() and energy[0] == 0, "Sunwell cannot farm daylight")
	sunwell.combat_active = true; sunwell._activate_support()
	check(energy[0] == 2, "Sunwell produces specified night energy")
	sunwell.power_state = Plant.PowerState.DORMANT; sunwell._process(8.0)
	check(energy[0] == 2, "Dormant support cannot produce energy")
	for enemy in [enemy_a,enemy_b,enemy_c]: enemy.health = enemy.max_health
	var spear := specimen(Plant.Kind.SPEAR); spear._attack_special(enemy_a)
	check(enemy_c.health < enemy_c.max_health, "Spear pierces collinear targets")
	for enemy in [enemy_a,enemy_b,enemy_c]: enemy.health = enemy.max_health
	var burst := specimen(Plant.Kind.BURST); burst._attack_special(enemy_b)
	check(enemy_a.health < enemy_a.max_health and enemy_c.health < enemy_c.max_health, "Burst affects actual nearby enemies")
	print("PLANT_EXPANSION checks=%d failures=%d" % [checks,failures.size()])
	for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
