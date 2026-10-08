extends Node2D

## A small soil lip is rendered after the plant sprite so exposed roots disappear
## into the ground instead of floating above it.
func _draw() -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(-39, 13), Vector2(-30, 8), Vector2(0, 6), Vector2(30, 8), Vector2(39, 13),
		Vector2(31, 20), Vector2(-31, 20)
	]), Color(0.08, 0.12, 0.09, 0.92))
	draw_arc(Vector2(0, 12), 32.0, PI, TAU, 20, Color(0.28, 0.38, 0.22, 0.9), 2.0, true)
