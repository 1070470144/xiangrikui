extends Node2D


const ArtLibrary = preload("res://scripts/art_library.gd")

var target: Node2D
var damage := 20.0
var speed := 390.0
var lifetime := 3.0
var _resolved := false
var art_sprite: Sprite2D
var source_position := Vector2.ZERO
var hit_callback: Callable
var is_mother_arrow := false
var flash_time := 0.12

func _ready() -> void:
	if is_mother_arrow:
		z_index = 8
		add_to_group("mother_attack_effects")
		var frames = preload("res://scripts/sun_arrow_visual.gd").frames("flight")
		if frames != null:
			var animation := AnimatedSprite2D.new()
			animation.sprite_frames = frames
			animation.scale = Vector2.ONE * 0.35
			animation.z_index = 1
			add_child(animation)
			animation.play("flight")
			return
	var texture := ArtLibrary.load_texture(ArtLibrary.PROJECTILE)
	if texture != null:
		art_sprite = Sprite2D.new()
		art_sprite.name = "ArtSprite"
		art_sprite.texture = texture
		add_child(art_sprite)

func launch(new_target: Node2D, new_damage: float) -> void:
	target = new_target
	damage = new_damage
	source_position = global_position
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	if _resolved:
		return
	if is_mother_arrow and (not is_instance_valid(get_parent().mother_flower) or get_parent().mother_flower.health <= 0.0 or not get_parent().mother_flower.combat_night):
		queue_free()
		return
	lifetime -= delta
	flash_time = maxf(0.0, flash_time - delta)
	if lifetime <= 0.0 or not is_instance_valid(target) or target.is_queued_for_deletion() or (is_mother_arrow and target.health <= 0.0):
		queue_free()
		return
	queue_redraw()
	global_position = global_position.move_toward(target.global_position, speed * delta)
	rotation = global_position.angle_to_point(target.global_position)
	if global_position.distance_to(target.global_position) <= 13.0:
		_resolved = true
		if is_mother_arrow: preload("res://scripts/sun_arrow_visual.gd").impact(get_parent(), target.global_position)
		if hit_callback.is_valid(): hit_callback.call(target, source_position, damage)
		elif target.has_method("take_directional_damage"): target.take_directional_damage(damage, source_position)
		else: target.take_damage(damage)
		queue_free()

func _draw() -> void:
	if is_mother_arrow and get_child_count() > 0:
		if flash_time > 0.0:
			draw_circle(Vector2.ZERO, 18.0 * (flash_time / 0.12), Color(1.0, 0.82, 0.25, 0.22 * flash_time / 0.12))
		return
	if art_sprite != null:
		return
	draw_circle(Vector2.ZERO, 12.0, Color(1.0, 0.75, 0.24, 0.12))
	draw_circle(Vector2.ZERO, 6.0, Color("fff0b0"))
	draw_line(Vector2(-18, 0), Vector2(-4, 0), Color("e5b94b"), 4.0)
