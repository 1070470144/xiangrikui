extends SceneTree

func _initialize() -> void:
	var game := preload("res://scripts/game.gd").new()
	var boss := preload("res://scripts/enemy.gd").new()
	boss.configure(boss.Kind.SUN_DEVOURER, Vector2.ZERO)
	game.phase = game.Phase.NIGHT
	for angle in [0.0, PI / 4.0, PI]:
		var plant := preload("res://scripts/plant.gd").new()
		plant.configure(plant.Kind.STONE, 0)
		game.add_child(plant)
		plant.position = Vector2.from_angle(angle) * 200.0
		game.plants.append(plant)
	game._on_boss_laser_requested(Vector2.ZERO, 0.0, PI / 2.0, 1000.0, 24.0, boss)
	assert(game.plants[0].health == 0.0 and game.plants[1].health == 0.0)
	assert(game.plants[2].health > 0.0)
	assert(game.plants[0].revive())
	boss.summon_cooldown = 0.0
	boss.advance_boss(0.01)
	assert(boss.boss_skill == "summon")
	assert(boss.interrupt_ability() and boss.summon_cooldown == 20.0)
	boss.boss_cast_position = Vector2.ZERO
	boss.laser_angle = 0.0; boss.laser_remaining = 3.0
	boss._advance_laser(3.0)
	assert(boss.laser_remaining == 0.0 and boss.laser_cooldown == 35.0)
	boss.free(); game.free()
	print("SUN_BOSS_PASS")
	quit()
