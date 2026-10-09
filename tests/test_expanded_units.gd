extends RefCounted

const Plant = preload("res://scripts/plant.gd")
const Enemy = preload("res://scripts/enemy.gd")
var failures: Array[String] = []

class RankedTarget extends Node2D:
	var last_amount := 0.0
	var last_rank := ""
	var last_melee := false
	func take_damage(amount: float) -> void: last_amount = amount
	func take_enemy_damage(amount: float, rank: String, melee: bool, _attacker: Node = null) -> void: last_amount = amount; last_rank = rank; last_melee = melee

func expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func run() -> Array[String]:
	test_flower_configurations()
	test_enemy_configurations()
	test_enemy_special_abilities()
	test_game_enemy_signal_handlers()
	test_temporary_sprout_extends_light_network()
	test_enemy_attack_forwards_ranked_damage()
	test_enemy_mother_status_api()
	test_enemy_terrain_speed()
	test_husk_charge_impact()
	test_lantern_support_and_prism_priority()
	test_sun_devourer_windup_and_interrupt()
	return failures

func test_enemy_terrain_speed() -> void:
	var terrain_script := ResourceLoader.load("res://scripts/terrain_map.gd") as Script
	var terrain: Node = terrain_script.new()
	var enemy: Node = Enemy.new(); enemy.configure(Enemy.Kind.SHADOW_BEAST, Vector2(700, 250))
	enemy.set_terrain_map(terrain)
	var cell: Vector2i = terrain.world_to_cell(enemy.global_position)
	var cells: Array[Vector2i] = [cell]
	terrain.apply_terrain_patch(cells, "swamp")
	expect(is_equal_approx(enemy.get_terrain_speed_multiplier(), 0.55), "enemy must sample swamp movement multiplier from terrain")
	enemy.apply_slow("test", 0.20, 1.0)
	expect(is_equal_approx(enemy.get_effective_move_speed(), enemy.move_speed * 0.55 * 0.80), "terrain and status slow must multiply together")
	enemy.free(); terrain.free()

func test_flower_configurations() -> void:
	var expected := [Plant.Kind.THORN, Plant.Kind.PRISM, Plant.Kind.LANTERN, Plant.Kind.FROST, Plant.Kind.HONEYDEW]
	for kind in expected:
		var plant: Node = Plant.new(); plant.configure(kind, 0)
		expect(plant.max_health > 0.0, "every flower must have health")
		expect(plant.kind == kind, "flower kind must remain configured")
		plant.free()

func test_enemy_configurations() -> void:
	var expected := [Enemy.Kind.SHADOW_BEAST, Enemy.Kind.EROSION_BUG, Enemy.Kind.HUSK_RAM, Enemy.Kind.SPORE_MOTH, Enemy.Kind.LANTERN_EATER, Enemy.Kind.ROT_CALLER, Enemy.Kind.SPLIT_SHADE, Enemy.Kind.SHELL_SCARAB, Enemy.Kind.ROOT_COLOSSUS, Enemy.Kind.SUN_DEVOURER]
	for kind in expected:
		var enemy: Node = Enemy.new(); enemy.configure(kind, Vector2.ZERO)
		expect(enemy.max_health > 0.0 and enemy.light_reward >= 0, "every enemy must have valid stats")
		enemy.free()
	var boss: Node = Enemy.new(); boss.configure(Enemy.Kind.SUN_DEVOURER, Vector2.ZERO)
	expect(boss.get_rank() == "boss", "sun devourer must be a boss")
	boss.free()

func test_enemy_special_abilities() -> void:
	var ram: Node = Enemy.new(); ram.configure(Enemy.Kind.HUSK_RAM, Vector2.ZERO)
	expect(ram.can_start_charge(180.0), "husk ram must charge at documented distance")
	expect(not ram.can_start_charge(80.0), "husk ram must not charge at close range")
	var moth: Node = Enemy.new(); moth.configure(Enemy.Kind.SPORE_MOTH, Vector2.ZERO)
	expect(moth.get_corrosion_profile() == {"damage":2.0, "duration":4.0}, "spore moth must expose corrosion profile")
	var eater: Node = Enemy.new(); eater.configure(Enemy.Kind.LANTERN_EATER, Vector2.ZERO)
	expect(is_equal_approx(eater.get_supply_multiplier(), 0.70), "lantern eater must suppress supply radius by thirty percent")
	var caller: Node = Enemy.new(); caller.configure(Enemy.Kind.ROT_CALLER, Vector2.ZERO)
	var ally: Node = Enemy.new(); ally.configure(Enemy.Kind.SHADOW_BEAST, Vector2.ZERO); caller.apply_support_buff(ally)
	expect(ally.move_buff_ratio == 0.20 and ally.attack_buff_ratio == 0.15, "rot caller must buff allied speed and attack")
	var split: Node = Enemy.new(); split.configure(Enemy.Kind.SPLIT_SHADE, Vector2.ZERO)
	expect(split.get_split_count() == 2, "split shade must create two remnants")
	var shell: Node = Enemy.new(); shell.configure(Enemy.Kind.SHELL_SCARAB, Vector2.ZERO)
	expect(shell.calculate_incoming_damage(100.0, true, false) == 60.0, "shell scarab must reduce frontal damage by forty percent")
	expect(shell.calculate_incoming_damage(100.0, true, true) == 100.0, "area damage must bypass shell frontal armor")
	shell.global_position = Vector2(100, 0); shell.target = RankedTarget.new(); shell.target.global_position = Vector2.ZERO
	expect(shell.is_frontal_source(Vector2.ZERO), "damage arriving from the attack direction must be frontal")
	expect(not shell.is_frontal_source(Vector2(200, 0)), "damage arriving from behind must bypass frontal armor")
	shell.target.free(); shell.target = null
	for unit in [ram, moth, eater, caller, ally, split, shell]: unit.free()

func test_game_enemy_signal_handlers() -> void:
	var game_script := ResourceLoader.load("res://scripts/game.gd", "Script", ResourceLoader.CACHE_MODE_REPLACE) as Script
	if game_script == null or not game_script.can_instantiate(): failures.append("game must compile for enemy integration"); return
	var game: Node = game_script.new()
	game._on_enemy_split_requested(Vector2(20, 30), 2)
	var remnants := 0
	for child in game.get_children():
		if "enemy_id" in child and child.enemy_id == "split_remnant":
			remnants += 1
			expect(child.max_health == 24.0 and child.move_speed == 75.0 and child.light_reward == 0, "split remnants must use their independent combat profile")
	expect(remnants == 2, "split shade death must create two remnants")
	var plant: Node = Plant.new(); plant.configure(Plant.Kind.THORN, 0); plant.global_position = Vector2.ZERO; game.add_child(plant); game.plants.clear(); game.plants.append(plant)
	var node_script := ResourceLoader.load("res://scripts/light_node.gd") as Script
	var light_node: Node = node_script.new(); light_node.global_position = Vector2.ZERO; game.add_child(light_node); game.light_nodes.clear(); game.light_nodes.append(light_node)
	game._on_enemy_area_damage_requested(Vector2.ZERO, 100.0, 20.0)
	expect(plant.health == plant.max_health - 20.0 and light_node.health == light_node.max_health - 20.0, "enemy area damage must hit plants and light nodes")
	plant.set_powered(false); plant.power_state_time = 3.0
	game._on_enemy_dark_sun_requested(2.0)
	expect(plant.power_state_time == 1.0, "dark sun must remove stored-light duration from plants")
	game.free()

func test_temporary_sprout_extends_light_network() -> void:
	var game_script := ResourceLoader.load("res://scripts/game.gd", "Script", ResourceLoader.CACHE_MODE_REPLACE) as Script
	var temporary_script := ResourceLoader.load("res://scripts/temporary_battle_object.gd", "Script", ResourceLoader.CACHE_MODE_REPLACE) as Script
	if game_script == null or temporary_script == null: failures.append("temporary network scripts must compile"); return
	var game: Node = game_script.new()
	var mother := Node2D.new(); mother.global_position = Vector2.ZERO; game.add_child(mother); game.mother_flower = mother
	var sprout: Node = temporary_script.new(); game.add_child(sprout); sprout.configure("card_temporary_sprout", Vector2(300, 0), {"health":80.0,"supply_radius":170.0,"capacity":4}); sprout.set_parent_source(mother)
	var parent: Node = game.find_best_parent(Vector2(410, 0), 2)
	expect(parent == sprout, "temporary sprout must act as a real light-network parent")
	expect(game.find_best_parent(Vector2(410, 0), 1, false) == null, "permanent light nodes must not chain from temporary sprouts")
	sprout.set_parent_source(null)
	expect(game.find_best_parent(Vector2(410, 0), 2) == null, "disconnected temporary sprouts must stop supplying plants")
	game.free()

func test_enemy_attack_forwards_ranked_damage() -> void:
	var enemy: Node = Enemy.new(); enemy.configure(Enemy.Kind.ROOT_COLOSSUS, Vector2.ZERO)
	var target := RankedTarget.new(); target.global_position = Vector2.ZERO
	enemy.target = target; enemy._attack_cooldown = 0.0; enemy._process(0.01)
	expect(target.last_amount == enemy.attack_damage and target.last_rank == "boss" and target.last_melee, "enemy attacks must forward rank and melee source to mother defenses")
	enemy.free(); target.free()

func test_enemy_mother_status_api() -> void:
	var enemy: Node = Enemy.new(); enemy.configure(Enemy.Kind.SHADOW_BEAST, Vector2(10, 0))
	enemy.apply_burn(3.0, 3.0); enemy.advance_statuses(1.0)
	expect(enemy.health == enemy.max_health - 3.0, "mother burn must deal periodic damage")
	enemy.apply_mother_mark(1.15, 3.0); var before: float = enemy.health; enemy.take_mother_damage(20.0)
	expect(is_equal_approx(enemy.health, before - 23.0), "mother mark must amplify only mother-originated damage")
	enemy.apply_stun(1.0)
	expect(enemy.is_controlled(), "stun must stop enemy actions")
	enemy.push_from(Vector2.ZERO, 30.0)
	expect(is_equal_approx(enemy.global_position.x, 40.0), "pulse push must move normal enemies away from mother")
	enemy.free()

func test_husk_charge_impact() -> void:
	var ram: Node = Enemy.new(); ram.configure(Enemy.Kind.HUSK_RAM, Vector2.ZERO)
	var target := RankedTarget.new(); target.global_position = Vector2(40, 0)
	ram.target = target; ram.charge_time = 0.5; ram._attack_cooldown = 0.0; ram._process(0.01)
	expect(target.last_amount == 24.0, "husk ram charge impact must deal twenty-four damage")
	expect(ram.stun_time >= 0.79 and ram.charge_time == 0.0, "husk ram must self-stun after charge impact")
	ram.free(); target.free()

func test_lantern_support_and_prism_priority() -> void:
	var plant: Node = Plant.new(); plant.configure(Plant.Kind.THORN, 0); plant.set_lantern_supported(true); plant.set_powered(false)
	expect(plant.power_state_time == 8.0, "lantern support must extend stored light to eight seconds")
	var prism: Node = Plant.new(); prism.configure(Plant.Kind.PRISM, 0); prism.global_position = Vector2.ZERO
	var normal: Node = Enemy.new(); normal.configure(Enemy.Kind.SHADOW_BEAST, Vector2(10, 0))
	var elite: Node = Enemy.new(); elite.configure(Enemy.Kind.HUSK_RAM, Vector2(100, 0))
	var boss: Node = Enemy.new(); boss.configure(Enemy.Kind.ROOT_COLOSSUS, Vector2(180, 0))
	expect(prism.select_target([normal, elite, boss]) == boss, "prism flower must prioritize bosses over nearer enemies")
	boss.health = 0.0
	expect(prism.select_target([normal, elite, boss]) == elite, "prism flower must prioritize elites when no boss is alive")
	for unit in [plant, prism, normal, elite, boss]: unit.free()

func test_sun_devourer_windup_and_interrupt() -> void:
	var node_script := ResourceLoader.load("res://scripts/light_node.gd") as Script
	var light_node: Node = node_script.new(); light_node.reset_state()
	var boss: Node = Enemy.new(); boss.configure(Enemy.Kind.SUN_DEVOURER, Vector2.ZERO); boss.light_nodes.clear(); boss.light_nodes.append(light_node); boss.special_cooldown = 0.0
	boss.advance_special(0.1)
	expect(boss.ability_windup > 1.0 and light_node.health == light_node.max_health, "sun devourer breath must begin a 1.2 second windup")
	boss.advance_special(1.0)
	expect(light_node.health == light_node.max_health, "dark breath must not damage during windup")
	boss.advance_special(0.2)
	expect(light_node.health == light_node.max_health - 35.0, "completed dark breath must damage its chosen light node")
	boss.advance_special(0.7) # Finish the existing recovery before starting another cast.
	boss.special_cooldown = 0.0; boss.advance_special(0.1)
	expect(boss.interrupt_ability() and boss.ability_windup == 0.0, "sun devourer windup must be interruptible")
	var health_after_interrupt: float = light_node.health; boss.advance_special(1.3)
	expect(light_node.health == health_after_interrupt, "interrupted breath must not deal delayed damage")
	boss.free(); light_node.free()
