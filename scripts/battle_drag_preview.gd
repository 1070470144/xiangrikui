extends Node2D

# Existing in-game plant art at its actual world size; never a gameplay actor.
var ghost: Sprite2D
var label: Label
var effect_radius := 0.0
var inner_radius := 0.0
var valid := false
var has_parent := false
var parent_point := Vector2.ZERO
var global_target := false

func _ready() -> void:
	z_index = 25
	ghost = Sprite2D.new()
	add_child(ghost)
	label = Label.new()
	label.position = Vector2(-90, 35)
	label.size = Vector2(180, 30)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_shadow_color", Color(0,0,0,0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(label)
	visible = false

func show_target(point: Vector2, allowed: bool, radius: float, caption: String, texture: Texture2D = null, sprite_scale := 0.58, sprite_offset := -18.0, parent: Node = null, global_effect := false, trigger_radius := 0.0) -> void:
	global_position = point
	valid = allowed
	effect_radius = radius
	inner_radius = trigger_radius
	global_target = global_effect
	has_parent = is_instance_valid(parent)
	if has_parent: parent_point = parent.global_position
	var tint := Color("96c3ae") if allowed else Color("de777b")
	ghost.texture = texture
	ghost.visible = texture != null
	ghost.position = Vector2(0, sprite_offset)
	ghost.scale = Vector2.ONE * sprite_scale
	ghost.modulate = Color(tint, 0.62)
	label.text = caption + (" · 松开使用" if allowed else " · 无效目标")
	label.modulate = tint
	# Target feedback stays readable without growing with the world camera zoom.
	var canvas := get_viewport().get_canvas_transform()
	var zoom_value := maxf(canvas.x.length(), 0.01)
	label.scale = Vector2.ONE / zoom_value
	label.size = Vector2(250,30)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var screen_point := canvas * point
	label.position = Vector2(28, 6) / zoom_value
	if screen_point.x + 278 > get_viewport_rect().size.x:
		label.position.x = -278 / zoom_value
	visible = true
	queue_redraw()

func clear() -> void:
	visible = false
	ghost.texture = null
	effect_radius = 0.0
	inner_radius = 0.0
	has_parent = false

func _draw() -> void:
	var color := Color("96c3ae") if valid else Color("de777b")
	if has_parent:
		draw_line(to_local(parent_point), Vector2.ZERO, Color(color,0.55), 2.0)
	if effect_radius > 0:
		draw_circle(Vector2.ZERO, effect_radius, Color(color,0.09))
		draw_arc(Vector2.ZERO, effect_radius, 0, TAU, 96, Color(color,0.85), 2.0)
	if inner_radius > 0:
		draw_arc(Vector2.ZERO, inner_radius, 0, TAU, 64, Color(color,0.45), 1.0)
	# A small target marker is not presented as an effect radius.
	for index in range(4):
		var direction := Vector2.RIGHT.rotated(PI * 0.5 * index)
		draw_line(direction * 12, direction * 21, color, 2.0)
	if global_target:
		draw_arc(Vector2.ZERO, 25, 0, TAU, 32, Color(color,0.7), 1.5)
