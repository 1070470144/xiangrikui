extends Node2D


const ArtLibrary = preload("res://scripts/art_library.gd")

var target: Node2D
var damage := 20.0
var speed := 390.0
var lifetime := 3.0
var _resolved := false
var art_sprite: Sprite2D
var source_position := Vector2.ZERO

func _ready() -> void:
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
	lifetime -= delta
	if lifetime <= 0.0 or not is_instance_valid(target):
		queue_free()
		return
	global_position = global_position.move_toward(target.global_position, speed * delta)
	rotation = global_position.angle_to_point(target.global_position)
	if global_position.distance_to(target.global_position) <= 13.0:
		_resolved = true
		if target.has_method("take_directional_damage"): target.take_directional_damage(damage, source_position)
		else: target.take_damage(damage)
		queue_free()

func _draw() -> void:
	if art_sprite != null:
		return
	draw_circle(Vector2.ZERO, 12.0, Color(1.0, 0.75, 0.24, 0.12))
	draw_circle(Vector2.ZERO, 6.0, Color("fff0b0"))
	draw_line(Vector2(-18, 0), Vector2(-4, 0), Color("e5b94b"), 4.0)
