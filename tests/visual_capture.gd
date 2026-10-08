extends SceneTree

const EffectScript = preload("res://scripts/effects.gd")

func _initialize() -> void:
	call_deferred("capture_combat")

func capture_combat() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game := scene.instantiate()
	root.add_child(game)
	await process_frame
	game._place_plant(0, 0)
	game._place_plant(2, 1)
	game._place_plant(5, 0)
	game._place_plant(7, 1)
	game.wave_index = 1
	game.begin_night()
	game.spawn_clock = 20.0
	game._process_spawns()
	var showcase_positions := [
		Vector2(245, 245), Vector2(875, 245), Vector2(255, 445),
		Vector2(880, 440), Vector2(350, 175), Vector2(790, 175),
	]
	var enemies := get_nodes_in_group("enemies")
	for i in range(mini(enemies.size(), showcase_positions.size())):
		enemies[i].global_position = showcase_positions[i]
	game.light_nodes[0].take_damage(100.0)
	var effect := EffectScript.new()
	game.add_child(effect)
	effect.configure(Vector2(840, 345), 125.0)
	for _frame in range(9):
		await process_frame
	quit(0)
