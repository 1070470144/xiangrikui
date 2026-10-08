extends SceneTree

func _initialize() -> void:
	var radar = load("res://scripts/threat_compass.gd").new()
	assert(radar.has_method("update_enemies"), "radar needs live enemy snapshots")
	assert(radar.world_to_radar(Vector2(1440, 1440)).is_equal_approx(Vector2(70, 70)))
	for point in [Vector2.ZERO, Vector2(2880, 0), Vector2(0, 2880), Vector2(2880, 2880)]:
		assert(radar.world_to_radar(point).distance_to(Vector2(70, 70)) + 4.0 <= 63.01)
	var positions := PackedVector2Array([Vector2(100, 200)])
	radar.update_enemies(positions, PackedVector2Array())
	positions[0] = Vector2(300, 400)
	radar.update_enemies(positions, positions)
	assert(radar.enemy_positions[0] == Vector2(300, 400))
	assert(radar.boss_positions[0] == Vector2(300, 400))
	positions.resize(5000)
	radar.update_enemies(positions, PackedVector2Array())
	assert(radar.enemy_positions.size() == 5000, "never sample or aggregate enemies")
	assert(radar.ENEMY_RADIUS == 1.5)
	radar.update_enemies(PackedVector2Array(), PackedVector2Array())
	assert(radar.enemy_positions.is_empty() and radar.boss_positions.is_empty())
	radar.free()
	var game = load("res://scripts/game.gd").new()
	var hud = load("res://scripts/hud.gd").new()
	var compass = load("res://scripts/threat_compass.gd").new()
	hud.threat_compass = compass
	game.hud = hud
	var enemy = load("res://scripts/enemy.gd").new()
	enemy.position = Vector2(400, 500)
	enemy.enemy_id = "root_crown_colossus"
	game.enemy_index.register(enemy)
	game._refresh_enemy_radar()
	assert(compass.enemy_positions.size() == 1 and compass.boss_positions.size() == 1)
	enemy.position = Vector2(800, 600)
	game._refresh_enemy_radar()
	assert(compass.enemy_positions[0] == enemy.position)
	enemy.health = 0
	game._refresh_enemy_radar()
	assert(compass.enemy_positions.is_empty() and compass.boss_positions.is_empty())
	game.enemy_index.unregister(enemy)
	enemy.free()
	game.hud = null
	game.free()
	hud.free()
	compass.free()
	print("ENEMY RADAR TESTS PASSED")
	quit()
