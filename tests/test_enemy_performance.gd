extends SceneTree

const Index = preload("res://scripts/enemy_spatial_index.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Game = preload("res://scripts/game.gd")
const Director = preload("res://scripts/wave_director.gd")
const Spec = preload("res://scripts/battlefield_spec.gd")
const Animations = preload("res://scripts/monster_animation_library.gd")

class Body extends Node2D:
	var health := 100.0
	var friendly := false

class CountingGame extends "res://scripts/game.gd":
	var consumed: Array[Dictionary] = []
	func _spawn_enemy(_kind: int, _direction: int, entry: Dictionary = {}) -> void:
		consumed.append(entry)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	test_index()
	test_queue()
	await test_lifecycle()
	print("ENEMY_PERFORMANCE_PASS spatial queries, lifecycle, queue order/budget and async state")
	quit()

func test_index() -> void:
	var index := Index.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7123
	var bodies: Array[Node] = []
	for i in 1000:
		var body := Body.new()
		body.position = Vector2(rng.randf_range(-512, 2880), rng.randf_range(-512, 2880))
		bodies.append(body)
		index.register(body)
	for i in 100:
		var center := Vector2(rng.randf_range(-512, 2880), rng.randf_range(-512, 2880))
		var radius := rng.randf_range(0, 700)
		var expected: Array[Node] = []
		var nearest: Node2D
		var best := INF
		for body in bodies:
			var distance := center.distance_squared_to(body.position)
			if distance <= radius * radius: expected.append(body)
			if distance < best: nearest = body; best = distance
		assert(index.query_radius(center, radius) == expected, "Local query preserves full-scan order and membership")
		assert(index.nearest(center) == nearest, "Nearest search preserves full-scan result")
		var rect := Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
		var in_rect: Array[Node] = []
		for body in bodies:
			var point: Vector2 = body.position
			if point.x >= rect.position.x and point.x <= rect.end.x and point.y >= rect.position.y and point.y <= rect.end.y: in_rect.append(body)
		assert(index.query_rect(rect) == in_rect, "Piercing broad phase preserves full-scan order and membership")
	var first: Node2D = bodies[0]
	first.position = Vector2(256, 256)
	index.sync(first)
	assert(first in index.query_radius(first.position, 0))
	assert(first in index.query_rect(Rect2(0, 0, 256, 256)), "Upper rectangle edge remains inclusive")
	var snapshot := index.hostiles()
	first.friendly = true
	index.sync(first)
	assert(index.count() == 999 and first not in index.query_radius(first.position, 5000))
	assert(snapshot.size() == 1000, "Published iteration snapshot is immutable across changes")
	first.friendly = false; index.sync(first)
	assert(index.count() == 1000)
	index.unregister(first)
	index.unregister(first)
	assert(index.count() == 999)
	for body in bodies: body.free()
	index.clear()
	assert(index.count() == 0)
	var older := Body.new()
	var newer := Body.new()
	older.position = Vector2(-256, 0); newer.position = Vector2(256, 0)
	index.register(older); index.register(newer)
	assert(index.nearest(Vector2.ZERO) == older, "Equal distances preserve spawn order across cells")
	assert(index.query_radius(Vector2.ZERO, 256) == [older, newer])
	older.friendly = true; index.sync(older)
	assert(index.nearest(Vector2.ZERO) == newer and index.count() == 1)
	index.clear(); older.free(); newer.free()

func test_queue() -> void:
	var director := Director.new()
	director.prepare(null, Spec.CENTER)
	var original := director.build(7, 777)
	var game := CountingGame.new()
	game.spawn_queue = original.duplicate(true)
	game._update_threats_from_queue()
	game.spawn_clock = 0.0
	game._process_spawns()
	assert(game.consumed.is_empty(), "Future entries must remain queued")
	var expected_reward := 0.0
	for entry in original: expected_reward += float(entry.reward)
	while game.get_remaining_spawn_count() > 0:
		game.spawn_clock += 0.25
		var before := game.consumed.size()
		game._process_spawns()
		assert(game.consumed.size() - before <= 8)
		for entry in game.consumed.slice(before): assert(float(entry.time) <= game.spawn_clock)
	assert(game.consumed == original, "No missing, reordered or modified entries")
	assert(game.spawn_queue.is_empty() and game._queue_batches.is_empty())
	var reward := 0.0
	for entry in game.consumed: reward += float(entry.reward)
	assert(is_equal_approx(reward, expected_reward))
	for threat in game.threat_levels: assert(threat < 0.001)
	game.free()

func test_lifecycle() -> void:
	var game := Game.new()
	var enemy := Enemy.new()
	enemy.configure(Enemy.Kind.SHADOW_BEAST, Vector2.ZERO)
	game.add_child(enemy)
	game._register_enemy(enemy)
	assert(enemy.configuration_count == 1)
	enemy.push_from(Vector2(-1, 0), 600)
	assert(enemy in game.query_enemies_in_radius(Vector2(600, 0), 0))
	assert(enemy.convert_to_friendly(2))
	assert(game._get_active_enemy_count() == 0)
	enemy.friendly_time = 0.001
	enemy._process(0.01)
	assert(game._get_active_enemy_count() == 1)
	enemy.take_damage(10000)
	assert(game._get_active_enemy_count() == 0 and game.active_enemies.is_empty())
	game.free()
	var live := Enemy.new()
	live.configure(Enemy.Kind.SHADOW_BEAST, Vector2.ZERO)
	root.add_child(live)
	live.set_process(false)
	assert(live.configuration_count == 1, "Ready must not reconfigure an initialized enemy")
	live.health = 31; live._attack_cooldown = 0.7; live._attack_pose = 0.1; live._animation_clock = 0.05
	Animations.request_species("shadow_beast")
	var deadline := Time.get_ticks_msec() + 30000
	while Animations.get_frames("shadow_beast") == null and Time.get_ticks_msec() < deadline: await process_frame
	assert(Animations.get_frames("shadow_beast") != null)
	assert(live.animation_frames != null and live.health == 31 and live._attack_cooldown == 0.7 and live._animation_clock == 0.05)
	live.take_damage(10000)
	var death_clock := live._animation_clock
	live._on_animation_ready("shadow_beast")
	assert(live.health <= 0 and live._animation_clock == death_clock, "Late readiness must not restart a dead enemy")
	live.queue_free()
	await process_frame
