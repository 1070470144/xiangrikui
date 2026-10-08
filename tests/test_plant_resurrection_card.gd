extends SceneTree

class Garden:
	extends Node
	var plants: Array[Node] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var garden := Garden.new()
	root.add_child(garden)
	for i in range(4):
		var plant := preload("res://scripts/plant.gd").new()
		plant.kind = i
		plant.position = Vector2(i * 100, 100)
		garden.add_child(plant)
		plant.set_process(false)
		plant.take_damage(100000.0)
		plant.death_order = i + 1
		garden.plants.append(plant)
	var resolver := preload("res://scripts/card_effect_resolver.gd").new()
	assert(resolver._resurrect_plants(garden) == 3)
	assert(garden.plants[0].health == 0.0)
	for i in range(1, 4):
		var plant = garden.plants[i]
		plant.set_process(false)
		assert(plant.reviving and plant.animation_sprite.animation == "revive")
		assert(not plant.can_attack())
	await create_timer(1.4).timeout
	for i in range(1, 4):
		assert(not garden.plants[i].reviving and garden.plants[i].animation_sprite.animation == "idle")
	garden.free()
	print("PLANT_RESURRECTION_CARD_PASS revived=3")
	quit()
