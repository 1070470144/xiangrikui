extends RefCounted

var failures: Array[String] = []

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func run() -> Array[String]:
	test_mother_flower_damage()
	test_light_node_break_and_repair()
	test_light_node_card_healing()
	test_light_node_capacity_and_parent()
	test_unpowered_plant_cannot_attack()
	test_plant_stored_light_states()
	test_node_overload_speeds_connected_plant()
	test_light_node_overload_and_suppression_stack()
	test_enemy_damage_and_reward()
	return failures

func test_mother_flower_damage() -> void:
	var script := _load_script("res://scripts/mother_flower.gd")
	if script == null:
		return
	var flower: Node = script.new()
	flower.reset_state()
	flower.take_damage(25.0)
	expect(is_equal_approx(flower.health, flower.max_health - 25.0), "mother flower damage must subtract health")
	flower.free()

func test_light_node_break_and_repair() -> void:
	var script := _load_script("res://scripts/light_node.gd")
	if script == null:
		return
	var node: Node = script.new()
	node.reset_state()
	node.take_damage(node.max_health)
	expect(not node.is_connected_to_light, "destroyed light node must disconnect")
	expect(node.repair(60.0), "destroyed light node must be repairable")
	expect(node.is_connected_to_light, "repaired light node must reconnect")
	node.free()

func test_light_node_card_healing() -> void:
	var script := _load_script("res://scripts/light_node.gd")
	if script == null: return
	var node: Node = script.new(); node.reset_state(); node.take_damage(50.0)
	expect(node.heal(25.0) and node.health == 75.0, "card healing must restore light-node health through the shared heal API")
	node.free()

func test_light_node_capacity_and_parent() -> void:
	var script := _load_script("res://scripts/light_node.gd")
	if script == null:
		return
	var parent: Node = script.new()
	var node: Node = script.new()
	node.set_parent_source(parent)
	expect(node.parent_source == parent, "light node must retain its selected parent")
	expect(node.capacity == 4, "light node must provide four load capacity")
	expect(node.can_accept(4), "empty light node must accept its full capacity")
	node.set_load(3)
	expect(node.can_accept(1), "light node must accept remaining capacity")
	expect(not node.can_accept(2), "light node must reject load above capacity")
	parent.free()
	node.free()

func test_unpowered_plant_cannot_attack() -> void:
	var script := _load_script("res://scripts/plant.gd")
	if script == null:
		return
	var plant: Node = script.new()
	plant.configure(1, 0)
	plant.set_powered(false)
	expect(not plant.can_attack(), "unpowered plant must not attack")
	plant.free()

func test_plant_stored_light_states() -> void:
	var script := _load_script("res://scripts/plant.gd")
	if script == null:
		return
	var plant: Node = script.new()
	plant.configure(0, 0)
	plant.set_powered(false)
	expect(plant.power_state == plant.PowerState.STORED, "newly disconnected plant must use stored light")
	expect(plant.has_combat_power(), "stored-light plant must keep combat power")
	plant.advance_power_state(3.1)
	expect(plant.power_state == plant.PowerState.LOW_LIGHT, "stored light must decay into low light")
	plant.advance_power_state(4.1)
	expect(plant.power_state == plant.PowerState.DORMANT, "low light must decay into dormancy")
	plant.set_powered(true)
	expect(plant.power_state == plant.PowerState.POWERED, "reconnected plant must recover full power")
	plant.free()

func test_node_overload_speeds_connected_plant() -> void:
	var plant_script := _load_script("res://scripts/plant.gd")
	var node_script := _load_script("res://scripts/light_node.gd")
	if plant_script == null or node_script == null: return
	var plant: Node = plant_script.new(); plant.configure(0, 0)
	var node: Node = node_script.new(); node.reset_state(); plant.set_power_source(node)
	expect(plant.get_effective_interval_multiplier() == 1.0, "normal light node must not alter plant speed")
	node.apply_overload(10.0)
	expect(plant.get_effective_interval_multiplier() == 0.8, "overloaded node must speed connected plants by twenty percent")
	node.overload_time = 0.0
	expect(plant.get_effective_interval_multiplier() == 1.0, "plant speed must recover when overload ends")
	plant.free(); node.free()

func test_light_node_overload_and_suppression_stack() -> void:
	var script := _load_script("res://scripts/light_node.gd")
	if script == null: return
	var node: Node = script.new(); node.reset_state(); node.apply_overload(10.0); node.apply_supply_suppression(0.70, 2.0)
	expect(is_equal_approx(node.supply_radius, 168.0), "suppression must multiply the overloaded 240 radius")
	node.advance_effects(2.1)
	expect(is_equal_approx(node.supply_radius, 240.0), "ending suppression must preserve active overload")
	node.advance_effects(8.0)
	expect(is_equal_approx(node.supply_radius, 190.0), "ending overload must restore base supply radius")
	node.free()

func test_enemy_damage_and_reward() -> void:
	var script := _load_script("res://scripts/enemy.gd")
	if script == null:
		return
	var enemy: Node = script.new()
	enemy.configure(0, Vector2.ZERO)
	var initial_health: float = enemy.health
	enemy.take_damage(15.0)
	expect(is_equal_approx(enemy.health, initial_health - 15.0), "enemy damage must subtract health")
	expect(enemy.light_reward > 0, "enemy must carry a positive light reward")
	enemy.free()

func _load_script(path: String) -> Script:
	var script := ResourceLoader.load(path, "Script", ResourceLoader.CACHE_MODE_REPLACE) as Script
	if script == null or not script.can_instantiate():
		failures.append("script failed to compile: %s" % path)
		return null
	return script
