extends RefCounted

const MotherEvolution = preload("res://scripts/mother_evolution.gd")
const ContentData = preload("res://scripts/content_data.gd")
const MotherFlower = preload("res://scripts/mother_flower.gd")
var failures: Array[String] = []

func expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func run() -> Array[String]:
	test_path_and_sequential_choices()
	test_representative_modifiers()
	test_every_upgrade_has_runtime_effects()
	test_mother_runtime_hooks()
	return failures

func test_path_and_sequential_choices() -> void:
	var state := MotherEvolution.new()
	expect(state.get_choices() == ["sun_arrow", "root_heart", "dawn_pulse"], "first day must offer three directions")
	expect(state.choose_path("dawn_pulse"), "valid direction must lock")
	expect(not state.choose_path("sun_arrow"), "direction cannot change in a run")
	expect(state.get_choices() == ["mother_charge_01", "mother_quelling_01", "mother_morningstar_01"], "first branch ranks must be offered")
	expect(state.choose_upgrade("mother_charge_01"), "offered upgrade must apply")
	expect(not state.choose_upgrade("mother_charge_03"), "upgrade cannot skip prerequisite")
	expect(state.get_choices()[0] == "mother_charge_02", "chosen branch must advance sequentially")
	for id in ["mother_charge_02", "mother_charge_03", "mother_charge_04", "mother_charge_05", "mother_charge_06"]: expect(state.choose_upgrade(id), "branch rank must advance")
	expect(state.selected_upgrades.size() == 6 and not state.choose_upgrade("mother_quelling_01"), "run must stop after six upgrades")

func test_representative_modifiers() -> void:
	var sun := MotherEvolution.new(); sun.choose_path("sun_arrow")
	sun.choose_upgrade("mother_sunburst_01"); sun.choose_upgrade("mother_sunburst_02")
	expect(sun.get_sunburst_cost(40) == 35 and sun.get_sunburst_damage(90.0) == 115.0, "sun path must modify mother sunburst")
	var root := MotherEvolution.new(); root.choose_path("root_heart")
	root.choose_upgrade("mother_receptacle_01"); root.choose_upgrade("mother_receptacle_02")
	expect(root.get_mother_max_health(300.0) == 400.0 and is_equal_approx(root.get_damage_reduction(), 0.13), "root path must modify only mother defenses")
	var dawn := MotherEvolution.new(); dawn.choose_path("dawn_pulse")
	dawn.choose_upgrade("mother_charge_01"); dawn.choose_upgrade("mother_morningstar_01")
	expect(dawn.get_pulse_energy() == 4 and dawn.get_pulse_damage() == 16.0, "dawn path must modify pulse")

func test_every_upgrade_has_runtime_effects() -> void:
	var state := MotherEvolution.new()
	expect(state.has_method("get_upgrade_effects"), "mother evolution must expose runtime effects for upgrades")
	if not state.has_method("get_upgrade_effects"): return
	for upgrade in ContentData.MOTHER_UPGRADES:
		var effects: Dictionary = state.get_upgrade_effects(str(upgrade["id"]))
		expect(not effects.is_empty(), "mother upgrade must have runtime effects: %s" % upgrade["id"])
	var full_sunseed := MotherEvolution.new(); full_sunseed.choose_path("sun_arrow")
	for rank in range(1, 7): full_sunseed.choose_upgrade("mother_sunseed_%02d" % rank)
	expect(full_sunseed.get_mother_attack_damage() == 23.0, "sunseed damage upgrade must apply")
	expect(full_sunseed.get_mother_attack_range() == 265.0, "sunseed range upgrade must apply")
	expect(is_equal_approx(full_sunseed.get_mother_attack_interval(), 1.32), "sunseed attack-speed upgrade must apply")
	expect(full_sunseed.get_effect_value("attack_extra_every", 0) == 4 and full_sunseed.get_effect_value("attack_pierce_ratio", 0.0) == 0.65, "advanced sunseed behavior must be active")
	var full_quelling := MotherEvolution.new(); full_quelling.choose_path("dawn_pulse")
	for rank in range(1, 7): full_quelling.choose_upgrade("mother_quelling_%02d" % rank)
	expect(full_quelling.get_effect_value("pulse_slow_ratio", 0.0) == 0.15, "quelling slow must apply")
	expect(full_quelling.get_effect_value("pulse_interrupt", false), "quelling pulse must interrupt abilities")
	expect(full_quelling.get_effect_value("pulse_stun_normal", 0.0) == 1.0, "final quelling pulse must stun normal enemies")

func test_mother_runtime_hooks() -> void:
	var flower: Node = MotherFlower.new(); flower.reset_state(); flower.choose_path("root_heart")
	for rank in range(1, 7): flower.choose_evolution("mother_receptacle_%02d" % rank)
	flower.on_night_started()
	expect(flower.max_health == 450.0 and flower.shield == 60.0, "full receptacle branch must grant health and night shield")
	flower.take_enemy_damage(100.0, "boss", false)
	expect(flower.health == 447.0 and flower.shield == 0.0, "boss reduction, periodic block and shield must all apply")
	var sap: Node = MotherFlower.new(); sap.reset_state(); sap.choose_path("root_heart")
	for rank in range(1, 6): sap.choose_evolution("mother_sap_%02d" % rank)
	sap.health = sap.max_health - 10.0; sap.heal(40.0)
	expect(sap.health == sap.max_health and sap.shield == 30.0, "sap overheal must become capped shield")
	sap.health = sap.max_health - 50.0; sap.on_day_started()
	expect(sap.health == sap.max_health - 10.0, "sap day-start upgrade must heal forty")
	var counter: Node = MotherFlower.new(); counter.reset_state(); counter.choose_path("root_heart")
	for rank in range(1, 6): counter.choose_evolution("mother_counterroot_%02d" % rank)
	var captured := {"reflected":0.0,"burst":0.0}
	counter.reflected_damage_requested.connect(func(_attacker: Node, damage: float): captured["reflected"] = damage)
	counter.secondary_damage_requested.connect(func(_center: Vector2, _radius: float, damage: float): captured["burst"] = damage)
	var attacker := Node.new(); counter.take_enemy_damage(32.0, "normal", true, attacker)
	expect(captured["reflected"] == 6.0, "counterroot must reflect six damage to melee attackers")
	expect(captured["burst"] == 30.0, "losing thirty health in three seconds must trigger root burst")
	attacker.free(); counter.free()
	flower.free(); sap.free()
