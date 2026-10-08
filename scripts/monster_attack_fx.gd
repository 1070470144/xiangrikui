extends Node2D

## Lightweight, procedural hit feedback for enemy attacks.
## It is deliberately independent from combat so a missed visual never changes damage.
var fx_kind := "slash"
var direction := Vector2.RIGHT
var charged := false
var elapsed := 0.0
var duration := 0.34
var radius := 28.0
var tint := Color("b59cff")
static var active_count := 0
const MAX_ACTIVE := 32

static func can_spawn() -> bool:
	return active_count < MAX_ACTIVE

func _ready() -> void:
	active_count += 1

func _exit_tree() -> void:
	active_count = maxi(0, active_count - 1)

func configure(kind: String, origin: Vector2, target_position: Vector2, is_charged := false) -> void:
	fx_kind = kind
	global_position = target_position + Vector2(0, -12)
	z_index = 8
	direction = origin.direction_to(target_position)
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	charged = is_charged
	duration = 0.46 if charged else (0.38 if kind in ["corrosion", "impact"] else 0.30)
	radius = 42.0 if charged else 28.0
	tint = {
		"slash": Color("a98cff"),
		"claw": Color("d9a6ff"),
		"pincer": Color("ff9c63"),
		"impact": Color("d6ae69"),
		"corrosion": Color("c56ee8"),
		"armor": Color("895fc4")
	}.get(kind, Color("b59cff"))
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
	if elapsed >= duration:
		queue_free()

func _draw() -> void:
	var progress := clampf(elapsed / duration, 0.0, 1.0)
	var fade := 1.0 - progress
	var forward := direction.normalized()
	var side := Vector2(-forward.y, forward.x)
	var center := forward * (10.0 + progress * 5.0)
	var line_color := Color(tint, fade)
	match fx_kind:
		"slash", "claw", "pincer":
			var reach := radius * (0.72 + progress * 0.34)
			var arc_center := center + forward * 5.0
			var start := forward.angle() - 1.05
			var arc_width := 1.85 if fx_kind == "pincer" else 1.55
			draw_arc(arc_center, reach, start, start + arc_width, 18, line_color, 4.0 if fx_kind == "pincer" else 3.0, true)
			draw_line(arc_center + forward.rotated(-0.65) * reach * 0.65, arc_center + forward.rotated(-0.65) * reach, line_color, 2.0, true)
			draw_line(arc_center + forward.rotated(0.65) * reach * 0.65, arc_center + forward.rotated(0.65) * reach, line_color, 2.0, true)
		"impact", "armor":
			var ring := radius * (0.30 + progress * 0.78)
			draw_circle(center, ring, Color(tint, fade * 0.12))
			draw_arc(center, ring, 0.0, TAU, 28, line_color, 3.0 if not charged else 4.5, true)
			for i in range(5 if charged else 3):
				var angle := float(i) * TAU / float(5 if charged else 3) + progress * 0.8
				draw_line(center + Vector2.from_angle(angle) * ring * 0.8, center + Vector2.from_angle(angle) * ring * 1.32, Color(tint, fade * 0.7), 2.0, true)
		"corrosion":
			var pulse := radius * (0.25 + progress * 0.95)
			draw_circle(center, pulse, Color(tint, fade * 0.10))
			draw_arc(center, pulse, -0.4, 2.3, 20, line_color, 3.0, true)
			draw_arc(center, pulse * 0.68, 2.6, 5.6, 16, Color("f0b1ff", fade * 0.8), 2.0, true)
			for i in range(4):
				var angle := float(i) * TAU / 4.0 + progress * 2.0
				draw_circle(center + Vector2.from_angle(angle) * pulse * 0.72, 2.5 + fade * 2.0, Color(tint, fade * 0.85))
