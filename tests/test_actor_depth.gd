extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	game.set_run_seed(777)
	root.add_child(game)
	assert(game.y_sort_enabled)
	assert(game.mother_flower.z_index == 0)
	assert(game.battlefield.z_index < game.mother_flower.z_index)
	var plant = load("res://scripts/plant.gd").new()
	game.add_child(plant)
	await process_frame
	assert(plant.z_index == 0 and plant.attack_fx.z_index == 0)
	assert(game.mother_flower.get_parent() == plant.get_parent())
	var enemy = load("res://scripts/enemy.gd").new()
	game.add_child(enemy)
	await process_frame
	assert(enemy.z_index == 0 and enemy.get_parent() == plant.get_parent())
	var light = load("res://scripts/light_node.gd").new()
	game.add_child(light)
	await process_frame
	assert(light.z_index == 0 and light.get_parent() == plant.get_parent())
	game.queue_free()
	await process_frame
	print("ACTOR DEPTH TESTS PASSED")
	quit()
