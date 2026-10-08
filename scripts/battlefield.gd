extends Node2D

const TerrainMapScript = preload("res://scripts/terrain_map.gd")
const BattlefieldSpec = preload("res://scripts/battlefield_spec.gd")

const WORLD_RECT := BattlefieldSpec.WORLD_RECT
const CENTER := BattlefieldSpec.CENTER
const CORE_BLOCK_RADIUS := BattlefieldSpec.CORE_BLOCK_RADIUS
const EDGE_MARGIN := BattlefieldSpec.EDGE_MARGIN

var direction_vectors := [Vector2.UP, Vector2(1, -1).normalized(), Vector2.RIGHT, Vector2(1, 1).normalized(), Vector2.DOWN, Vector2(-1, 1).normalized(), Vector2.LEFT, Vector2(-1, -1).normalized()]
var spawn_positions: Array[Vector2] = []
var preview_position := Vector2.ZERO
var preview_radius := 25.0
var preview_valid := false
var preview_visible := false
var preview_supply_radius := 0.0
var preview_parent_position := Vector2.ZERO
var preview_has_parent := false
var aim_position := Vector2.ZERO
var aiming := false
var network_lines: Array[Dictionary] = []
var terrain_shift := 0
var background_art: Sprite2D
var foreground_art: Sprite2D
var entrance_decor_layer: Node2D
var terrain_map: Node2D

func _init() -> void:
	z_index = -1
	terrain_map = TerrainMapScript.new()
	terrain_map.name = "TerrainMap"
	add_child(terrain_map)
	spawn_positions = BattlefieldSpec.get_spawn_positions()

func _ready() -> void:
	_setup_art()
	set_process(true)
	queue_redraw()

func _setup_art() -> void:
	# The battlefield is assembled from TerrainMap's tile layers so weather can
	# replace individual cells without swapping or masking a full-screen image.
	background_art = null
	entrance_decor_layer = Node2D.new()
	entrance_decor_layer.name = "EntranceDecorLayer"
	entrance_decor_layer.z_index = 15
	add_child(entrance_decor_layer)
	# Do not place ART_FG_GreenhouseMist here. That legacy PNG is an opaque
	# full-scene render (including the old grey soil), rather than a transparent
	# mist overlay, so even a low alpha would tint and visually replace the
	# modular ground tiles. Weather and foreground feedback are drawn by their
	# dedicated layers and remain world-anchored.
	foreground_art = null

func get_spawn_position(direction: int) -> Vector2:
	return spawn_positions[posmod(direction, spawn_positions.size())]

func is_inside_plantable_area(point: Vector2) -> bool:
	if not WORLD_RECT.grow(-EDGE_MARGIN).has_point(point):
		return false
	if not terrain_map.is_plantable_at(point):
		return false
	return point.distance_to(CENTER) >= CORE_BLOCK_RADIUS

func is_position_clear(point: Vector2, radius: float, occupied_positions: Array) -> bool:
	if not is_inside_plantable_area(point):
		return false
	for occupied in occupied_positions:
		if point.distance_to(Vector2(occupied)) < radius * 2.0 + BattlefieldSpec.scale_distance(8.0):
			return false
	return true

func set_placement_preview(point: Vector2, radius: float, valid: bool, supply_radius := 0.0, parent_position := Vector2.ZERO, has_parent := false) -> void:
	preview_position = point
	preview_radius = radius
	preview_valid = valid
	preview_visible = true
	preview_supply_radius = supply_radius
	preview_parent_position = parent_position
	preview_has_parent = has_parent
	queue_redraw()

func clear_placement_preview() -> void:
	preview_visible = false
	preview_has_parent = false
	queue_redraw()

func set_network_lines(lines: Array[Dictionary]) -> void:
	network_lines = lines
	queue_redraw()

func set_terrain_shift(value: int) -> void:
	terrain_shift = value
	queue_redraw()

func set_aim_preview(point: Vector2, value: bool) -> void:
	aim_position = point
	aiming = value
	queue_redraw()

func warn_spawn(direction: int, duration := 0.9) -> void:
	# Spawn warnings are communicated by the first appearance alert in the HUD.
	pass

func _draw() -> void:
	# Static dressing is part of the continuous terrain surface. Keep this
	# draw pass dedicated to gameplay feedback so scattered marks do not return.
	if terrain_shift > 0:
		for i in range(terrain_shift + 1):
			var angle := float(i) * TAU / float(terrain_shift + 1)
			var ridge := CENTER + Vector2(cos(angle), sin(angle)) * 124.0
			draw_arc(ridge, 38.0, 0.0, TAU, 48, Color(0.25, 0.38, 0.34, 0.38), 3.2)
	for line in network_lines:
		var color := Color("e5b94b") if bool(line.get("connected", true)) else Color("55465f")
		if bool(line.get("overloaded", false)):
			color = Color("d8963e")
		draw_line(Vector2(line["from"]), Vector2(line["to"]), Color(color, 0.25), 12.0)
		draw_line(Vector2(line["from"]), Vector2(line["to"]), color, 3.0)
	if preview_visible:
		var preview_color := Color("e5b94b") if preview_valid else Color("8e3d4a")
		if preview_supply_radius > 0.0:
			draw_circle(preview_position, preview_supply_radius, Color(preview_color, 0.055))
			draw_arc(preview_position, preview_supply_radius, 0, TAU, 72, Color(preview_color, 0.38), 2.0)
		if preview_has_parent:
			draw_line(preview_parent_position, preview_position, Color(preview_color, 0.8), 3.0)
		draw_circle(preview_position, preview_radius, Color(preview_color, 0.18))
		draw_arc(preview_position, preview_radius, 0, TAU, 36, preview_color, 3.0)
	if aiming:
		draw_circle(aim_position, 150.0, Color(0.96, 0.62, 0.23, 0.10))
		draw_arc(aim_position, 150.0, 0, TAU, 64, Color("f59e45"), 3.0)
		draw_line(aim_position - Vector2(12, 0), aim_position + Vector2(12, 0), Color("fff0b0"), 2.0)
		draw_line(aim_position - Vector2(0, 12), aim_position + Vector2(0, 12), Color("fff0b0"), 2.0)

func reset_slots() -> void:
	clear_placement_preview()
	aiming = false
	network_lines.clear()
	queue_redraw()
