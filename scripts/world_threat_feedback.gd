extends Node2D

const BattlefieldSpec = preload("res://scripts/battlefield_spec.gd")
const NORMAL_THRESHOLD := 0.01
const SEVERE_THRESHOLD := 0.35
const FADE_SPEED := 2.5
const DISPLAY_RADIUS := 380.0

var _states: Array[Dictionary] = []
var _time := 0.0

func _init() -> void:
	for position in BattlefieldSpec.get_spawn_positions():
		_states.append({"position": position, "intensity": 0.0, "visibility": 0.0, "severity": 0, "boss": false})

func update_snapshot(threats: PackedFloat32Array, boss_direction := -1) -> void:
	for index in range(_states.size()):
		var value := clampf(threats[index] if index < threats.size() else 0.0, 0.0, 1.0)
		var state := _states[index]
		state["intensity"] = value
		state["severity"] = 0 if value < NORMAL_THRESHOLD else (2 if value >= SEVERE_THRESHOLD else 1)
		state["boss"] = index == boss_direction and value >= NORMAL_THRESHOLD
		if value >= NORMAL_THRESHOLD:
			state["visibility"] = 1.0
		_states[index] = state
	queue_redraw()

func advance_feedback(delta: float) -> void:
	_time += delta
	for index in range(_states.size()):
		var state := _states[index]
		if float(state["intensity"]) < NORMAL_THRESHOLD:
			state["visibility"] = maxf(0.0, float(state["visibility"]) - delta * FADE_SPEED)
		_states[index] = state
	queue_redraw()

func _process(delta: float) -> void:
	advance_feedback(delta)

func get_warning_states() -> Array[Dictionary]:
	return _states.duplicate(true)

func _draw() -> void:
	for state in _states:
		var visibility := float(state["visibility"])
		if visibility <= 0.0:
			continue
		var spawn_position := Vector2(state["position"])
		var intensity := float(state["intensity"])
		var severity := int(state["severity"])
		var inward := (BattlefieldSpec.CENTER - spawn_position).normalized()
		var tangent := Vector2(-inward.y, inward.x)
		var pulse := 0.5 + 0.5 * sin(_time * (4.0 if severity == 2 else 2.4))
		var color := Color("d68b55") if severity == 1 else Color("b94d5c")
		var center := BattlefieldSpec.CENTER - inward * DISPLAY_RADIUS
		var radius := 28.0 + intensity * 16.0 + pulse * 4.0
		draw_arc(center, radius, 0.0, TAU, 32, Color(color, 0.32 * visibility), 5.0)
		draw_line(center - tangent * 14.0, center + inward * (26.0 + intensity * 18.0), Color(color, 0.58 * visibility), 5.0)
		var tip := center + inward * (34.0 + intensity * 18.0)
		draw_colored_polygon(PackedVector2Array([tip, tip - inward * 13.0 + tangent * 8.0, tip - inward * 13.0 - tangent * 8.0]), Color(color, 0.78 * visibility))
		if bool(state["boss"]):
			draw_arc(center, radius + 12.0 + pulse * 4.0, 0.0, TAU, 40, Color("e7c060", 0.85 * visibility), 3.0)
