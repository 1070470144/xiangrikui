extends RefCounted

const Balance = preload("res://scripts/balance.gd")
const Spec = preload("res://scripts/battlefield_spec.gd")
var rng := RandomNumberGenerator.new()
var reachable: Dictionary = {}
var fallback: Array[Vector2] = []
var ring_fallback: Dictionary = {}
var terrain: Node

const RINGS := [
	{"min":210.0, "max":325.0},
	{"min":330.0, "max":1000.0},
	{"min":1010.0, "max":1400.0},
]

func prepare(map: Node, target: Vector2) -> void:
	terrain = map
	reachable.clear()
	fallback.clear()
	ring_fallback.clear()
	for index in RINGS.size(): ring_fallback[index] = []
	if map == null: return
	var start: Vector2i = map.world_to_cell(target)
	var cells: Array[Vector2i] = [start]
	reachable[start] = true
	var cursor := 0
	while cursor < cells.size():
		var cell := cells[cursor]
		cursor += 1
		for step in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = cell + step
			if reachable.has(next) or not map.is_valid_cell(next): continue
			if map.get_terrain_at(map.cell_to_world_center(next)) not in ["soil", "swamp"]: continue
			reachable[next] = true
			cells.append(next)
	for i in 720:
		var angle := float(i) * TAU / 720.0
		for ring_index in RINGS.size():
			var ring: Dictionary = RINGS[ring_index]
			var point := Spec.CENTER + Vector2.from_angle(angle) * ((float(ring.min) + float(ring.max)) * 0.5)
			if valid(point):
				ring_fallback[ring_index].append(point)
				if ring_index == 2: fallback.append(point)

func valid(point: Vector2) -> bool:
	if not Spec.WORLD_RECT.has_point(point): return false
	return terrain == null or (reachable.has(terrain.world_to_cell(point)) and terrain.get_terrain_at(point) in ["soil", "swamp"])

func sample(angle: float, used: Array[Vector2]) -> Vector2:
	return sample_ring(angle, used, 2)

func sample_ring(angle: float, used: Array[Vector2], preferred_ring: int) -> Vector2:
	var ring_order: Array[int] = [preferred_ring]
	for index in RINGS.size():
		if index not in ring_order: ring_order.append(index)
	for ring_index in ring_order:
		var ring: Dictionary = RINGS[ring_index]
		for attempt in 24:
			var point := Spec.CENTER + Vector2.from_angle(angle + rng.randf_range(-PI / 15.0, PI / 15.0)) * rng.randf_range(float(ring.min), float(ring.max))
			if valid(point) and separated(point, used): return point
		var ring_points: Array = ring_fallback.get(ring_index, []) as Array
		var candidates: Array[Vector2] = []
		for point in ring_points:
			if _near_angle(point, angle) and separated(point, used): candidates.append(point)
		if not candidates.is_empty(): return candidates[rng.randi_range(0, candidates.size() - 1)]
	var candidates: Array[Vector2] = []
	for point in fallback:
		if _near_angle(point, angle) and separated(point, used): candidates.append(point)
	if not candidates.is_empty(): return candidates[rng.randi_range(0, candidates.size() - 1)]
	push_error("No reachable perimeter spawn available")
	return Vector2.INF

func sample_outer_ring(angle: float, used: Array[Vector2], preferred_ring: int) -> Vector2:
	var ring_order: Array[int] = [preferred_ring]
	for index in [2, 1]:
		if index not in ring_order: ring_order.append(index)
	for ring_index in ring_order:
		var ring: Dictionary = RINGS[ring_index]
		for attempt in 24:
			var point := Spec.CENTER + Vector2.from_angle(angle + rng.randf_range(-PI / 15.0, PI / 15.0)) * rng.randf_range(float(ring.min), float(ring.max))
			if valid(point) and separated(point, used): return point
		var ring_points: Array = ring_fallback.get(ring_index, []) as Array
		var candidates: Array[Vector2] = []
		for point in ring_points:
			if _near_angle(point, angle) and separated(point, used): candidates.append(point)
		if not candidates.is_empty(): return candidates[rng.randi_range(0, candidates.size() - 1)]
	push_error("No reachable outer-ring spawn available")
	return Vector2.INF

func separated(point: Vector2, used: Array[Vector2]) -> bool:
	for other in used:
		if point.distance_to(other) < 24.0: return false
	return true

func _near_angle(point: Vector2, angle: float) -> bool:
	return absf(wrapf((point - Spec.CENTER).angle() - angle, -PI, PI)) <= PI / 15.0

static func sector(point: Vector2) -> int:
	return posmod(roundi((point - Spec.CENTER).angle() / (PI / 4.0)) + 2, 8)

func build(night: int, seed_value: int) -> Array[Dictionary]:
	rng.seed = seed_value
	var config: Dictionary = Balance.NIGHT_CONFIGS[night - 1]
	var normals: Array[int] = []
	var elites: Array[int] = []
	var bosses: Array[int] = []
	var weight := 0.0
	for kind in config.counts:
		for i in (mini(1, int(config.counts[kind])) if kind == 3 and night == 7 else int(config.counts[kind])):
			weight += float(Balance.ENEMIES[kind].reward)
			if kind in [2, 3]: bosses.append(kind)
			elif kind in [0, 1]: normals.append(kind)
			else: elites.append(kind)
	_shuffle(normals)
	_shuffle(elites)
	var queue: Array[Dictionary] = []
	var batch := 0
	var cursor := 0
	var total_batches := maxi(5, ceili(float(normals.size()) / 4.0))
	var batch_index := 0
	var first_wave_angle := rng.randf_range(0.0, TAU)
	while cursor < normals.size():
		var size := mini(rng.randi_range(2, 5), normals.size() - cursor)
		if normals.size() - cursor - size == 1 and size > 2: size -= 1
		var progress := float(batch_index) / maxf(float(total_batches - 1), 1.0)
		var time := float(config.duration) * (0.06 + progress * 0.78)
		var angle := _wave_angle(night, batch_index, first_wave_angle)
		var used: Array[Vector2] = []
		var preferred_ring := 2 if progress < 0.34 else (1 if progress < 0.68 else (0 if rng.randf() < 0.28 else 1))
		for member in size:
			var point := sample_ring(angle, used, preferred_ring)
			used.append(point)
			queue.append(_entry(normals[cursor], time, point, batch, config, weight))
			cursor += 1
			time += rng.randf_range(0.12, 0.32)
		batch += 1
		batch_index += 1
	for i in elites.size():
		var progress := 0.52 + 0.40 * float(i + 1) / maxf(float(elites.size()), 1.0)
		var time := float(config.duration) * progress
		queue.append(_entry(elites[i], time, sample_outer_ring(_wave_angle(night, i, first_wave_angle), [], 1), batch, config, weight))
		batch += 1
	for i in bosses.size():
		var progress := 0.68 + 0.22 * float(i + 1) / maxf(float(bosses.size()), 1.0)
		queue.append(_entry(bosses[i], float(config.duration) * progress, sample_outer_ring(rng.randf_range(0.0, TAU), [], 2), batch, config, weight))
		batch += 1
	queue.sort_custom(func(a: Dictionary, b: Dictionary): return a.time < b.time)
	return queue

func _wave_angle(night: int, batch_index: int, first_wave_angle: float) -> float:
	if night == 1:
		return first_wave_angle + rng.randf_range(-PI / 18.0, PI / 18.0)
	if night == 2:
		var side := 0 if batch_index % 2 == 0 else 1
		return first_wave_angle + float(side) * PI + rng.randf_range(-PI / 12.0, PI / 12.0)
	return rng.randf_range(0.0, TAU)

func _shuffle(items: Array[int]) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var item := items[i]
		items[i] = items[j]
		items[j] = item

func _entry(kind: int, time: float, point: Vector2, batch: int, config: Dictionary, weight: float) -> Dictionary:
	return {"kind":kind, "time":minf(time, config.duration), "spawn_position":point, "direction":sector(point), "batch":batch,
		"health_multiplier":config.health if kind in [0, 1] else 1.0,
		"damage_multiplier":config.damage if kind in [0, 1] else 1.0,
		"reward":float(config.budget) * float(Balance.ENEMIES[kind].reward) / maxf(weight, 1.0)}
