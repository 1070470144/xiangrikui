extends Control

var angle := 0.0:
	set(value):
		angle = value
		_apply_angle()
var turning := false
var travel := 0.0
var animation: Tween

func _ready() -> void:
	pivot_offset = size * 0.5
	_apply_angle()

func flip() -> void:
	if animation != null: animation.kill()
	animation = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	animation.tween_property(self, "angle", snappedf(angle, 180.0) + 180.0, 0.42)
	animation.parallel().tween_property(self, "rotation", 0.0, 0.42)

func handle_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if animation != null: animation.kill()
			turning = true; travel = 0.0

func _input(event: InputEvent) -> void:
	if not turning: return
	if event is InputEventMouseMotion:
		travel += absf(event.relative.x) + absf(event.relative.y)
		angle += event.relative.x * 0.8
		rotation = clampf(rotation + event.relative.y * 0.002, -0.09, 0.09)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		turning = false
		if travel < 8.0: flip()
		else:
			animation = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			animation.tween_property(self, "angle", snappedf(angle, 180.0), 0.2)
			animation.parallel().tween_property(self, "rotation", 0.0, 0.2)

func _apply_angle() -> void:
	var perspective := cos(deg_to_rad(angle))
	scale.x = maxf(0.025, absf(perspective))
	modulate = Color.WHITE.darkened((1.0 - absf(perspective)) * 0.28)
	var front := get_node_or_null("Front") as Control
	var back := get_node_or_null("Back") as Control
	if front != null: front.visible = perspective >= 0.0
	if back != null: back.visible = perspective < 0.0
