extends SceneTree
func _initialize() -> void:
	var game = load("res://scripts/game.gd").new()
	game.phase = game.Phase.NIGHT; game.weather = "thunderstorm"
	for i in 5:
		var plant = load("res://scripts/plant.gd").new()
		plant.configure(plant.Kind.THORN,0); game.add_child(plant); game.plants.append(plant)
	game._on_thunder_struck()
	var dead := 0
	for plant in game.plants:
		if plant.health <= 0: dead += 1
	assert(dead >= 1 and dead <= 2)
	assert(game.thunder_empower_time == 5)
	assert(game.get_weather_enemy_attack_multiplier() == 1.3)
	assert(game.get_weather_enemy_attack_interval_multiplier() == 0.8)
	game.weather_seal_time = 5
	game._on_thunder_struck()
	var after := 0
	for plant in game.plants:
		if plant.health <= 0: after += 1
	assert(after == dead)
	game.free()
	print("THUNDER_STRIKE_PASS")
	quit()
