extends RefCounted

const WORLD_SIZE := 2880.0
const WORLD_RECT := Rect2(0, 0, WORLD_SIZE, WORLD_SIZE)
const CENTER := Vector2(WORLD_SIZE * 0.5, WORLD_SIZE * 0.5)
const SCALE := 0.4
const GRID_SIZE := Vector2i(72, 72)
const CELL_SIZE := WORLD_SIZE / float(GRID_SIZE.x)
const EDGE_MARGIN := 0.0
const CORE_BLOCK_RADIUS := 42.0
const SPAWN_DISTANCE := 1400.0

static func scale_distance(value: float) -> float:
	return value * SCALE

static func get_spawn_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for direction in [Vector2.UP, Vector2(1, -1).normalized(), Vector2.RIGHT, Vector2(1, 1).normalized(), Vector2.DOWN, Vector2(-1, 1).normalized(), Vector2.LEFT, Vector2(-1, -1).normalized()]:
		positions.append(CENTER + direction * SPAWN_DISTANCE)
	return positions
