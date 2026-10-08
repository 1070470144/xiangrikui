extends SceneTree

var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.mother_flower.set_process(false)
	game.mother_choice_pending = false
	game.hud.hide_mother_choices()
	game.spawn_queue.assign([{"time":99999.0, "kind":"shadow", "direction":0}])
	var enemy = game.EnemyScript.new()
	game.add_child(enemy)
	enemy.set_process(false)
	var base_speed: float = enemy.move_speed
	var base_damage: float = enemy.attack_damage
	var plant = game.PlantScript.new()
	game.add_child(plant)
	plant.set_process(false)
	var node = game.LightNodeScript.new()
	game.add_child(node)
	node.set_process(false)
	game.phase = game.Phase.NIGHT
	game.weather = "thunderstorm"
	game._process(0.01)
	expect(game.acid_rain_fx.active and game.thunderstorm_fx.active, "fourth night activates both layers")
	expect(is_equal_approx(game.get_weather_enemy_attack_multiplier(), 1.10), "acid enemy attack +10 percent")
	expect(is_equal_approx(enemy.get_effective_move_speed(), enemy.move_speed * 1.10), "enemy actual movement +10 percent")
	enemy.friendly = true
	expect(is_equal_approx(enemy.get_effective_move_speed(), enemy.move_speed), "friendly enemy excludes hostile boost")
	enemy.friendly = false
	game.mother_flower.health = 100.0
	game.mother_flower.heal(20.0)
	expect(is_equal_approx(game.mother_flower.health, 117.0), "mother healing -15 percent")
	plant.health = 20.0
	plant.heal(20.0)
	expect(is_equal_approx(plant.health, 37.0), "plant healing -15 percent")
	node.health = 20.0
	node.repair(20.0)
	expect(is_equal_approx(node.health, 37.0), "node repair -15 percent")
	enemy.target = game.mother_flower
	enemy.position = game.mother_flower.position
	var before: float = game.mother_flower.health
	enemy._process(0.01)
	expect(is_equal_approx(before - game.mother_flower.health, enemy.attack_damage * 1.10), "actual enemy impact +10 percent")
	before = game.mother_flower.health
	var shift: int = game.terrain_shift
	game.environmental_tick = 0.0
	game.thunderstorm_terrain_tick = 0.0
	for i in range(4): game._process_weather(1.0)
	expect(is_equal_approx(before - game.mother_flower.health, 4.0), "storm applies exactly four acid ticks in four seconds")
	expect(game.terrain_shift == (shift + 1) % 4, "acid ticks preserve independent storm terrain tick")
	game.weather_seal_time = 10.0
	before = game.mother_flower.health
	game._process_weather(1.0)
	expect(is_equal_approx(before, game.mother_flower.health), "seal stops acid damage")
	assert_neutral(game, "seal")
	game.weather_seal_time = 0.0
	game.weather = "fog"
	game._process(0.01)
	expect(is_equal_approx(plant.get_effective_interval_multiplier(), 1.15), "fog actual attack interval +15 percent")
	expect(not game.acid_rain_fx.active and not game.thunderstorm_fx.active, "fog excludes rain effects")
	var fog = game.night_fog
	fog.reset_spread()
	expect(is_equal_approx(fog.get_spread_radius(), 1400.0), "fog starts at outer ring seven")
	fog._process(22.5)
	expect(is_equal_approx(fog.get_spread_radius(), 900.0), "fog moves gradually inwards")
	fog._process(22.5)
	expect(is_equal_approx(fog.get_spread_radius(), 400.0), "fog reaches nearest ring two")
	for phase in [game.Phase.DAY, game.Phase.VICTORY, game.Phase.FAILURE, game.Phase.RETREATED]:
		game.phase = phase
		assert_neutral(game, "inactive phase")
	game.phase = game.Phase.NIGHT
	game.weather = "acid_rain"
	expect(is_equal_approx(game.get_weather_enemy_attack_multiplier(), 1.10), "third night attack boost")
	expect(is_equal_approx(game.get_weather_enemy_speed_multiplier(), 1.0) and is_equal_approx(game.get_weather_heal_multiplier(), 1.0), "third night excludes lightning penalties")
	game.weather = "clear"
	assert_neutral(game, "clear weather")
	game.reset_model()
	assert_neutral(game, "restart")
	expect(is_equal_approx(enemy.move_speed, base_speed) and is_equal_approx(enemy.attack_damage, base_damage), "weather preserves base enemy configuration")
	if failures.is_empty():
		print("WEATHER_MODIFIER_TESTS_PASSED")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func assert_neutral(game: Node, reason: String) -> void:
	for value in [game.get_weather_enemy_attack_multiplier(), game.get_weather_enemy_speed_multiplier(), game.get_weather_heal_multiplier(), game.get_weather_plant_interval_multiplier()]:
		expect(is_equal_approx(value, 1.0), reason + " restores weather modifiers")
