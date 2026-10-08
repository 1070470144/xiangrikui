extends Label

var lifetime := 0.75
static var active_count := 0
const MAX_ACTIVE := 40

static func can_spawn() -> bool:
	return active_count < MAX_ACTIVE

func _ready() -> void:
	active_count += 1

func _exit_tree() -> void:
	active_count = maxi(0, active_count - 1)

func setup(amount: float, healing: bool) -> void:
	text = ("+%d" if healing else "-%d") % maxi(1, int(round(amount)))
	position = Vector2(-24, -72)
	size = Vector2(48, 28)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", 19)
	add_theme_color_override("font_color", Color("75e39a") if healing else Color("ff7b72"))
	add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	add_theme_constant_override("shadow_offset_x", 1)
	add_theme_constant_override("shadow_offset_y", 2)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	lifetime -= delta
	position.y -= 34.0 * delta
	modulate.a = clampf(lifetime / 0.35, 0.0, 1.0)
	if lifetime <= 0.0: queue_free()
