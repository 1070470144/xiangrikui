extends SceneTree

const Game = preload("res://scripts/game.gd")
const Mother = preload("res://scripts/mother_flower.gd")
const Plant = preload("res://scripts/plant.gd")
const LightNode = preload("res://scripts/light_node.gd")
const Spec = preload("res://scripts/battlefield_spec.gd")

func _initialize() -> void:
	var game := Game.new()
	var mother := Mother.new()
	game.add_child(mother)
	mother.position = Spec.CENTER
	game.mother_flower = mother
	for i in 9:
		var plant := Plant.new()
		plant.configure(Plant.Kind.PRISM if i % 2 else Plant.Kind.THORN, 0)
		game.add_child(plant)
		plant.position = Spec.CENTER + Vector2(30, 0)
		game.plants.append(plant)
	game._rebuild_network()
	assert(game.mother_plant_load == 8)
	assert(game.plants[8].power_source == null)
	assert(game.find_best_parent(Spec.CENTER, 2) == null)
	assert(game.find_best_parent_excluding(Spec.CENTER, 0, null, false) == mother)
	game.plants[0].health = 0
	game._rebuild_network()
	assert(game.plants[8].power_source == mother)
	var nearby := LightNode.new()
	game.add_child(nearby)
	nearby.position = Spec.CENTER + Vector2(40, 0)
	game.light_nodes.append(nearby)
	game._rebuild_network()
	assert(nearby.parent_source == mother)
	for plant in game.plants:
		if plant.health > 0: assert(plant.power_source == mother)
	var node := LightNode.new()
	game.add_child(node)
	node.position = Spec.CENTER + Vector2(200, 0)
	game.light_nodes.append(node)
	for i in 5:
		var plant := Plant.new()
		plant.configure(Plant.Kind.PRISM, 0)
		game.add_child(plant)
		plant.position = node.position + Vector2(100, 0)
		game.plants.append(plant)
	game._rebuild_network()
	assert(node.load == 4)
	assert(game.plants[-1].power_source == null)
	var relay := LightNode.new()
	game.add_child(relay)
	relay.position = node.position + Vector2(170, 0)
	game.light_nodes.append(relay)
	game._rebuild_network()
	assert(relay.parent_source == node)
	assert(game.plants[-1].power_source == relay)
	assert(relay.load <= 4 and node.load <= 4)
	var original_parent: Node = relay.parent_source
	var shortcut := LightNode.new()
	game.add_child(shortcut)
	shortcut.position = relay.position + Vector2(-10, 0)
	game.light_nodes.append(shortcut)
	var saved_plant_parents: Dictionary = {}
	for plant in game.plants:
		if plant.health > 0 and plant.power_source != null: saved_plant_parents[plant] = plant.power_source
	game._rebuild_network()
	assert(relay.parent_source == original_parent)
	for plant in saved_plant_parents: assert(plant.power_source == saved_plant_parents[plant])
	game.light_nodes.reverse()
	game._rebuild_network()
	assert(relay.parent_source == original_parent)
	for plant in saved_plant_parents: assert(plant.power_source == saved_plant_parents[plant])
	# Remove all root links: old connected flags must not keep a relay cycle alive.
	node.health = 0
	nearby.health = 0
	relay.set_parent_source(shortcut)
	shortcut.set_parent_source(relay)
	game._rebuild_network()
	assert(not relay.is_connected_to_light and not shortcut.is_connected_to_light)
	for plant in game.plants:
		assert(plant.power_source != relay and plant.power_source != shortcut)
	node.health = node.max_health
	game._rebuild_network()
	assert(node.parent_source == mother and relay.is_connected_to_light and shortcut.is_connected_to_light)
	var sprout := preload("res://scripts/temporary_battle_object.gd").new()
	game.add_child(sprout)
	sprout.configure("card_temporary_sprout", Spec.CENTER + Vector2(210, 100), {"health":80.0,"supply_radius":170.0,"capacity":4})
	game._rebuild_network()
	var sprout_parent: Node = sprout.parent_source
	assert(sprout_parent != null)
	for i in 5:
		var plant := Plant.new()
		plant.configure(Plant.Kind.PRISM, 0)
		game.add_child(plant)
		plant.position = sprout.position + Vector2(0, 160)
		game.plants.append(plant)
	game._rebuild_network()
	assert(sprout.parent_source == sprout_parent and sprout.load == 4)
	assert(game.plants[-1].power_source == null)
	assert(preload("res://scripts/content_data.gd").get_card("card_temporary_sprout").capacity == 4)
	game.free()
	print("NETWORK_CAPACITY_PASS")
	quit()
