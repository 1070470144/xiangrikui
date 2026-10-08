extends Control

const BattlefieldSpec = preload("res://scripts/battlefield_spec.gd")
const ENEMY_RADIUS := 1.5
const BOSS_RADIUS := 4.0
var enemy_positions := PackedVector2Array()
var boss_positions := PackedVector2Array()

var threat_levels := PackedFloat32Array([0, 0, 0, 0, 0, 0, 0, 0])
var boss_direction := -1
var boss_active := false
var direction_label_text := "N,E,S,W":
	set(value):
		direction_label_text = value
		queue_redraw()

func _ready() -> void:
	custom_minimum_size = Vector2(140, 140)
	size = Vector2(140, 140)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func update_threats(threats: PackedFloat32Array, new_boss_direction := -1) -> void:
	threat_levels = threats.duplicate()
	boss_direction = new_boss_direction
	queue_redraw()

func set_boss_active(value: bool) -> void:
	boss_active = value
	queue_redraw()

func world_to_radar(point: Vector2) -> Vector2:
	var rect: Rect2 = BattlefieldSpec.WORLD_RECT
	var bounded := point.clamp(rect.position, rect.end)
	var scale_factor := 59.0 / (rect.size * 0.5).length()
	return Vector2(70, 70) + (bounded - rect.get_center()) * scale_factor

func update_enemies(positions: PackedVector2Array, bosses: PackedVector2Array) -> void:
	enemy_positions = positions.duplicate()
	boss_positions = bosses.duplicate()
	queue_redraw()

func _draw() -> void:
	var center := Vector2(70, 70)
	draw_circle(center, 66, Color(0.015, 0.025, 0.055, 0.92))
	for radius in [24.0, 43.0, 63.0]: draw_arc(center, radius, 0, TAU, 64, Color("564a35"), 1.0)
	for i in range(8):
		var angle := -PI * 0.5 + float(i) * TAU / 8.0
		var direction := Vector2(cos(angle), sin(angle))
		draw_line(center + direction * 18, center + direction * 61, Color(0.28, 0.28, 0.25, 0.5), 1.0)
	var direction_labels := direction_label_text.split(",")
	var label_positions := [Vector2(67, 1), Vector2(126, 64), Vector2(67, 122), Vector2(3, 64)]
	for i in range(mini(direction_labels.size(), label_positions.size())):
		draw_string(get_theme_default_font(), label_positions[i], direction_labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("d8c58a"))
	for position in enemy_positions:
		draw_circle(world_to_radar(position), ENEMY_RADIUS, Color("ef4444"))
	draw_circle(center, 6, Color("f2c94c"))
	for position in boss_positions:
		var point := world_to_radar(position)
		draw_circle(point, BOSS_RADIUS, Color("ff6655"))
		var label_offset := Vector2(-36, -7) if point.x > 70 else Vector2(6, -7)
		draw_string(get_theme_default_font(), point + label_offset, "BOSS", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("ff6655"))
