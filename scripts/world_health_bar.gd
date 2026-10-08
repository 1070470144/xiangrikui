extends Node2D

var target: Node
var bar_size := Vector2(54, 6)
var offset := Vector2(-27, -58)
var tint := Color("d95d68")
var _refresh_clock := 0.0

func setup(owner: Node, color: Color = Color("d95d68")) -> void:
	target = owner
	tint = color
	queue_redraw()

func _process(delta: float) -> void:
	if not is_instance_valid(target): queue_free(); return
	_refresh_clock -= delta
	if target.has_method("get_rank"):
		var rank_name := str(target.get_rank())
		visible = rank_name in ["elite", "boss"] or float(target.health) < float(target.max_health)
	else:
		visible = true
	if visible and _refresh_clock <= 0.0:
		_refresh_clock = 0.12
		queue_redraw()

func _draw() -> void:
	if not is_instance_valid(target) or not ("health" in target) or not ("max_health" in target): return
	var ratio := clampf(float(target.health) / maxf(1.0, float(target.max_health)), 0.0, 1.0)
	draw_rect(Rect2(offset, bar_size), Color(0.03, 0.04, 0.05, 0.85), true)
	draw_rect(Rect2(offset + Vector2(1, 1), Vector2((bar_size.x - 2.0) * ratio, bar_size.y - 2.0)), tint, true)
