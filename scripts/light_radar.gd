extends Control

const BattlefieldSpec = preload("res://scripts/battlefield_spec.gd")

signal focus_requested(world_position: Vector2)

const WORLD_RECT := BattlefieldSpec.WORLD_RECT
var node_snapshots: Array = []
var line_snapshots: Array = []
var threat_levels := PackedFloat32Array([0, 0, 0, 0, 0, 0, 0, 0])

func _ready() -> void:
	custom_minimum_size = Vector2(140, 140)
	size = Vector2(140, 140)
	mouse_filter = Control.MOUSE_FILTER_STOP

func world_to_radar(point: Vector2) -> Vector2:
	return Vector2(point.x / WORLD_RECT.size.x * 140.0, point.y / WORLD_RECT.size.y * 140.0)

func radar_to_world(point: Vector2) -> Vector2:
	return Vector2(point.x / 140.0 * WORLD_RECT.size.x, point.y / 140.0 * WORLD_RECT.size.y)

func update_snapshot(nodes: Array, lines: Array, threats: PackedFloat32Array) -> void:
	node_snapshots = nodes
	line_snapshots = lines
	threat_levels = threats
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		focus_requested.emit(radar_to_world(event.position))

func _draw() -> void:
	draw_circle(Vector2(70, 70), 68, Color(0.025, 0.035, 0.065, 0.88))
	draw_arc(Vector2(70, 70), 67, 0, TAU, 64, Color("8f7339"), 2.0)
	for line in line_snapshots:
		var color := Color("e5b94b") if bool(line.get("connected", true)) else Color("66546d")
		draw_line(world_to_radar(Vector2(line["from"])), world_to_radar(Vector2(line["to"])), color, 1.5)
	for node in node_snapshots:
		var color := Color("e5b94b") if bool(node.get("connected", true)) else Color("8e3d4a")
		draw_circle(world_to_radar(Vector2(node["position"])), 3.0, color)
	draw_circle(Vector2(70, 70), 5.0, Color("fff0b0"))
	for i in range(8):
		if threat_levels[i] <= 0.0: continue
		var angle := -PI * 0.5 + float(i) * TAU / 8.0
		var point := Vector2(70, 70) + Vector2(cos(angle), sin(angle)) * 59.0
		draw_circle(point, 3.0 + threat_levels[i] * 4.0, Color(0.75, 0.2, 0.25, 0.85))
