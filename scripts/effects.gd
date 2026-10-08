extends Node2D

const ArtLibrary = preload("res://scripts/art_library.gd")

var radius := 0.0
var max_radius := 150.0
var duration := 0.42
var elapsed := 0.0
var art_sprite: Sprite2D

func _ready() -> void:
	var resources := get_node_or_null("/root/PlantResources")
	var texture: Texture2D = resources.get_texture(ArtLibrary.SUNBURST) if resources != null else ArtLibrary.get_cached_texture(ArtLibrary.SUNBURST)
	if texture != null:
		art_sprite = Sprite2D.new()
		art_sprite.name = "ArtSprite"
		art_sprite.texture = texture
		art_sprite.scale = Vector2.ZERO
		add_child(art_sprite)

func configure(world_position: Vector2, effect_radius: float) -> void:
	global_position = world_position
	max_radius = effect_radius

func _process(delta: float) -> void:
	elapsed += delta
	radius = ease(clampf(elapsed / duration, 0.0, 1.0), -1.8) * max_radius
	if art_sprite != null:
		var scale_value := radius * 2.0 / 512.0
		art_sprite.scale = Vector2.ONE * scale_value
		art_sprite.rotation += delta * 0.35
		art_sprite.modulate.a = 1.0 - clampf(elapsed / duration, 0.0, 1.0)
	queue_redraw()
	if elapsed >= duration:
		queue_free()

func _draw() -> void:
	var alpha := 1.0 - clampf(elapsed / duration, 0.0, 1.0)
	if art_sprite == null:
		draw_circle(Vector2.ZERO, radius, Color(1.0, 0.72, 0.22, alpha * 0.14))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 72, Color(1.0, 0.91, 0.55, alpha), 8.0)
