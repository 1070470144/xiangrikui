extends RefCounted

const CELL_SIZE := 256.0
var _cells: Dictionary = {}
var _entries: Dictionary = {}
var _sequence := 0
var _hostiles: Array[Node] = []
var _dirty := true
var _hostile_count := 0
var query_usec := 0
var query_candidates := 0

func clear() -> void:
	_cells.clear(); _entries.clear(); _hostiles = []; _sequence = 0; _dirty = true
	query_usec = 0; query_candidates = 0
	_hostile_count = 0

func _cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / CELL_SIZE), floori(point.y / CELL_SIZE))

func register(enemy: Node2D) -> void:
	var id := enemy.get_instance_id()
	if _entries.has(id): return
	var cell := _cell(enemy.global_position)
	_entries[id] = {"node": enemy, "cell": cell, "order": _sequence, "hostile": not enemy.friendly}
	_sequence += 1
	if not enemy.friendly: _hostile_count += 1
	if not _cells.has(cell): _cells[cell] = {}
	_cells[cell][id] = enemy
	_dirty = true

func unregister(enemy: Node) -> void:
	var id := enemy.get_instance_id()
	if not _entries.has(id): return
	var cell: Vector2i = _entries[id].cell
	if _entries[id].hostile: _hostile_count -= 1
	_cells[cell].erase(id)
	if _cells[cell].is_empty(): _cells.erase(cell)
	_entries.erase(id)
	_dirty = true

func sync(enemy: Node2D) -> void:
	var id := enemy.get_instance_id()
	if not _entries.has(id): return
	var entry: Dictionary = _entries[id]
	var hostile: bool = not enemy.friendly
	if bool(entry.hostile) != hostile:
		_hostile_count += 1 if hostile else -1
		entry.hostile = hostile
		_dirty = true
	var cell := _cell(enemy.global_position)
	if cell == entry.cell: return
	_cells[entry.cell].erase(id)
	if _cells[entry.cell].is_empty(): _cells.erase(entry.cell)
	if not _cells.has(cell): _cells[cell] = {}
	_cells[cell][id] = enemy
	entry.cell = cell

func hostiles() -> Array[Node]:
	if _dirty:
		# Publish a new snapshot: deaths during an attack cannot mutate its iteration.
		_hostiles = []
		for entry in _entries.values():
			if entry.hostile and is_instance_valid(entry.node): _hostiles.append(entry.node)
		_dirty = false
	return _hostiles

func count() -> int:
	return _hostile_count

func query_rect(rect: Rect2) -> Array[Node]:
	var started := Time.get_ticks_usec()
	var result: Array[Node] = []
	var low := _cell(rect.position)
	var high := _cell(rect.end)
	for y in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			for id in _cells.get(Vector2i(x, y), {}):
				query_candidates += 1
				var entry: Dictionary = _entries[id]
				var enemy: Node2D = entry.node
				if entry.hostile and is_instance_valid(enemy) and enemy.health > 0.0:
					var p := enemy.global_position
					if p.x >= rect.position.x and p.y >= rect.position.y and p.x <= rect.end.x and p.y <= rect.end.y: result.append(enemy)
	result.sort_custom(_before)
	query_usec += Time.get_ticks_usec() - started
	return result

func _before(a: Node, b: Node) -> bool:
	return int(_entries[a.get_instance_id()].order) < int(_entries[b.get_instance_id()].order)

func query_radius(center: Vector2, radius: float) -> Array[Node]:
	var result: Array[Node] = []
	if radius < 0.0: return result
	for enemy in query_rect(Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)):
		if center.distance_squared_to(enemy.global_position) <= radius * radius: result.append(enemy)
	return result

func nearest(center: Vector2, excluded: Node = null) -> Node2D:
	var started := Time.get_ticks_usec()
	var cells: Array = []
	for cell in _cells:
		var low: Vector2 = Vector2(cell) * CELL_SIZE
		var closest := center.clamp(low, low + Vector2.ONE * CELL_SIZE)
		cells.append({"cell": cell, "distance": center.distance_squared_to(closest)})
	cells.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.distance) < float(b.distance))
	var best := INF
	var order := 9223372036854775807
	var result: Node2D
	for candidate_cell in cells:
		if float(candidate_cell.distance) > best: break
		for id in _cells[candidate_cell.cell]:
			query_candidates += 1
			var entry: Dictionary = _entries[id]
			var enemy: Node2D = entry.node
			if enemy == excluded or not entry.hostile or not is_instance_valid(enemy) or enemy.health <= 0.0: continue
			var distance := center.distance_squared_to(enemy.global_position)
			if distance < best or distance == best and int(entry.order) < order:
				best = distance; order = int(entry.order); result = enemy
	query_usec += Time.get_ticks_usec() - started
	return result
