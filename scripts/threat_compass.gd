extends Control

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

func _draw() -> void:
	var center := Vector2(70, 70)
	draw_circle(center, 66, Color(0.015, 0.025, 0.055, 0.92))
	for radius in [24.0, 43.0, 63.0]: draw_arc(center, radius, 0, TAU, 64, Color("564a35"), 1.0)
	for i in range(8):
		var angle := -PI * 0.5 + float(i) * TAU / 8.0
		var direction := Vector2(cos(angle), sin(angle))
		draw_line(center + direction * 18, center + direction * 61, Color(0.28, 0.28, 0.25, 0.5), 1.0)
		var level := threat_levels[i] if i < threat_levels.size() else 0.0
		if level > 0.0:
			var marker := center + direction * 54
			draw_circle(marker, 3.5 + level * 5.0, Color(0.82, 0.18, 0.20, 0.92))
			draw_arc(marker, 7.0 + level * 5.0, 0, TAU, 18, Color("f1684f"), 1.5)
	var direction_labels := direction_label_text.split(",")
	var label_positions := [Vector2(67, 1), Vector2(126, 64), Vector2(67, 122), Vector2(3, 64)]
	for i in range(mini(direction_labels.size(), label_positions.size())):
		draw_string(get_theme_default_font(), label_positions[i], direction_labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("d8c58a"))
	draw_circle(center, 6, Color("f2c94c"))
	if boss_active:
		var index := boss_direction if boss_direction >= 0 else _strongest_direction()
		var angle := -PI * 0.5 + float(index) * TAU / 8.0
		var point := center + Vector2(cos(angle), sin(angle)) * 72.0
		draw_circle(point, 8, Color("9d1f25"))
		draw_string(get_theme_default_font(), point + Vector2(10, 4), "BOSS", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("ff6655"))

func _strongest_direction() -> int:
	var result := 0
	var strongest := -1.0
	for i in range(threat_levels.size()):
		if threat_levels[i] > strongest:
			strongest = threat_levels[i]
			result = i
	return result
