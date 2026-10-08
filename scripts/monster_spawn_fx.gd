extends Node2D

var elapsed := 0.0
var duration := 0.72
static var active_count := 0
const MAX_ACTIVE := 24

static func can_spawn() -> bool:
	return active_count < MAX_ACTIVE

func _ready() -> void:
	active_count += 1

func _exit_tree() -> void:
	active_count = maxi(0, active_count - 1)

func configure(at: Vector2) -> void:
	global_position = at
	z_index = 6
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
	if elapsed >= duration: queue_free()

func _draw() -> void:
	var progress := clampf(elapsed / duration, 0.0, 1.0)
	var fade := 1.0 - progress
	var ring := 12.0 + progress * 50.0
	draw_arc(Vector2(0, 8), ring, 0.0, TAU, 40, Color("c46b63", fade * 0.7), 3.0, true)
	draw_arc(Vector2.ZERO, ring * 0.58, -1.0, 1.8, 20, Color("e5b873", fade * 0.8), 2.0, true)
	for i in range(6):
		var angle := float(i) * TAU / 6.0 + progress * 0.9
		draw_circle(Vector2.from_angle(angle) * ring * 0.72, 2.5 + fade * 2.0, Color("c46b63", fade * 0.8))
