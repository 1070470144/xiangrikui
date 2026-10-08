extends SceneTree

const Director = preload("res://scripts/wave_director.gd")
const Balance = preload("res://scripts/balance.gd")
const Game = preload("res://scripts/game.gd")
const Terrain = preload("res://scripts/terrain_map.gd")
const Spec = preload("res://scripts/battlefield_spec.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var terrain := Terrain.new()
	var director := Director.new()
	director.prepare(terrain, Spec.CENTER)
	for seed_value in 12:
		for night in range(1, 8):
			var queue := director.build(night, seed_value)
			assert(queue == director.build(night, seed_value), "Fixed seed must replay")
			var counts: Dictionary = {}
			var batches: Dictionary = {}
			var reward := 0.0
			var previous := -1.0
			for entry in queue:
				counts[entry.kind] = counts.get(entry.kind, 0) + 1
				reward += entry.reward
				assert(entry.time >= previous and entry.time <= Balance.NIGHT_CONFIGS[night - 1].duration)
				previous = entry.time
				var point: Vector2 = entry.spawn_position
				assert(director.valid(point))
				var radius := point.distance_to(Spec.CENTER)
				assert((radius >= 419.99 and radius <= 650.01) or (radius >= 1079.99 and radius <= 1220.01) or (radius >= 1279.99 and radius <= 1400.01))
				assert(entry.direction == Director.sector(point))
				for fixed in Spec.get_spawn_positions(): assert(point.distance_to(fixed) > 0.01)
				if not batches.has(entry.batch): batches[entry.batch] = []
				for other in batches[entry.batch]: assert(point.distance_to(other) >= 24.0)
				batches[entry.batch].append(point)
				if radius < 650.0: assert(entry.kind in [0, 1], "elite and boss spawns must stay outside the inner ring")
				if entry.kind in [2, 3]: assert(entry.time >= Balance.NIGHT_CONFIGS[night - 1].duration * 0.68)
				if entry.kind not in [0, 1]: assert(entry.health_multiplier == 1.0 and entry.damage_multiplier == 1.0)
			assert(counts == Balance.NIGHT_CONFIGS[night - 1].counts)
			for batch in batches:
				assert(batches[batch].size() <= 5)
				if batches[batch].size() > 1: assert(batches[batch].size() >= 2)
			assert(is_equal_approx(reward, float(Balance.NIGHT_CONFIGS[night - 1].budget)))
	assert(director.build(1, 1) != director.build(1, 2))
	# An impassable strip excludes disconnected outer cells from the perimeter pool.
	for y in Spec.GRID_SIZE.y: terrain.current_cells[Vector2i(60, y)] = "void"
	director.prepare(terrain, Spec.CENTER)
	assert(not director.valid(Vector2(2780, 1440)))
	for entry in director.build(7, 123): assert(director.valid(entry.spawn_position))
	var used: Array[Vector2] = []
	for i in 5:
		var point := director.sample(0.0, used)
		assert(point.is_finite() and director.valid(point) and director.separated(point, used))
		used.append(point)
	var game := Game.new()
	game.set_run_seed(777)
	game.reset_model()
	game.choose_mother_card("sun_arrow")
	game.begin_night()
	assert(game.spawn_queue.size() == 240)
	game.light_energy = 0
	for entry in game.spawn_queue: game._on_enemy_died(entry.reward, Spec.CENTER)
	assert(game.light_energy == 60)
	game.reset_model()
	assert(game.run_seed == 777)
	game.wave_index = 5
	game.mother_choice_pending = false
	game.begin_night()
	assert(game.wave_index == 6 and game.phase == Game.Phase.DAY and game.spawn_queue.is_empty())
	game.free()
	terrain.free()
	print("WAVE_DIRECTOR_PASS seeds=12 nights=7 counts paths spacing rewards reproducible")
	quit()
