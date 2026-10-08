extends Camera2D

const BattlefieldSpec = preload("res://scripts/battlefield_spec.gd")

const WORLD_RECT := BattlefieldSpec.WORLD_RECT
const MIN_ZOOM := 0.8
const MAX_ZOOM := 3.375

var move_speed := 248.0
var edge_margin := 18.0
var dragging := false
var drag_started := false
var just_dragged := false

func _ready() -> void:
	position = WORLD_RECT.get_center()
	zoom = Vector2.ONE * 1.35
	position_smoothing_enabled = true
	position_smoothing_speed = 8.0

func clamp_zoom(value: float) -> float:
	return clampf(value, MIN_ZOOM, MAX_ZOOM)

func clamp_position(value: Vector2) -> Vector2:
	return Vector2(clampf(value.x, WORLD_RECT.position.x, WORLD_RECT.end.x), clampf(value.y, WORLD_RECT.position.y, WORLD_RECT.end.y))

func clamp_position_for_view(value: Vector2, viewport_size: Vector2, zoom_value: float) -> Vector2:
	var safe_zoom := maxf(0.01, zoom_value)
	var half_view := viewport_size * 0.5 / safe_zoom
	var minimum := WORLD_RECT.position + half_view
	var maximum := WORLD_RECT.end - half_view
	if minimum.x > maximum.x: minimum.x = WORLD_RECT.get_center().x; maximum.x = minimum.x
	if minimum.y > maximum.y: minimum.y = WORLD_RECT.get_center().y; maximum.y = minimum.y
	return Vector2(clampf(value.x, minimum.x, maximum.x), clampf(value.y, minimum.y, maximum.y))

func _clamp_current_position(value: Vector2) -> Vector2:
	return clamp_position_for_view(value, get_viewport_rect().size, zoom.x)

func focus_world(point: Vector2) -> void:
	position = _clamp_current_position(point)

func _process(delta: float) -> void:
	var motion := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	var mouse := get_viewport().get_mouse_position()
	var viewport_size := get_viewport_rect().size
	if mouse.x <= edge_margin: motion.x -= 1.0
	if mouse.x >= viewport_size.x - edge_margin: motion.x += 1.0
	if mouse.y <= edge_margin: motion.y -= 1.0
	if mouse.y >= viewport_size.y - edge_margin: motion.y += 1.0
	if motion.length_squared() > 0.0:
		position = _clamp_current_position(position + motion.normalized() * move_speed * delta / zoom.x)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			if event.pressed:
				drag_started = false
			else:
				just_dragged = drag_started
				drag_started = false
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			dragging = event.pressed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var factor := 1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.89
			var next := clamp_zoom(zoom.x * factor)
			zoom = Vector2.ONE * next
			position = _clamp_current_position(position)
	elif event is InputEventMouseMotion and dragging:
		position = _clamp_current_position(position - event.relative / zoom.x)
		if event.relative.length_squared() > 4.0: drag_started = true
	elif event.is_action_pressed("focus_mother"):
		focus_world(WORLD_RECT.get_center())

func consume_click_was_dragged() -> bool:
	var value := just_dragged
	just_dragged = false
	return value
