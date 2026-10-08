extends Node2D

var elapsed := 0.0
var duration := 0.42
var seed_value := 0.0
var sprite: AnimatedSprite2D
var frame_ground_offsets: Array[float] = []

func _ready() -> void:
	var folder := "res://assets/core/generated/monster_smoke_animation"
	var absolute := ProjectSettings.globalize_path(folder)
	if not DirAccess.dir_exists_absolute(absolute):
		return
	var names: Array[String] = []
	for candidate in DirAccess.get_files_at(absolute):
		if candidate.begins_with("puff-") and candidate.ends_with(".png"):
			names.append(candidate)
	names.sort()
	if names.is_empty():
		return
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("puff")
	frames.set_animation_speed("puff", 24.0)
	frames.set_animation_loop("puff", false)
	for name in names:
		var image := Image.load_from_file(absolute + "/" + name)
		if image != null:
			frames.add_frame("puff", ImageTexture.create_from_image(image))
			var used := image.get_used_rect()
			var bottom_from_center := float(used.position.y + used.size.y) - image.get_height() * 0.5
			frame_ground_offsets.append(bottom_from_center)
	sprite = AnimatedSprite2D.new()
	sprite.name = "FootfallSmokeSprite"
	sprite.sprite_frames = frames
	sprite.animation = "puff"
	sprite.autoplay = "puff"
	add_child(sprite)
	_update_sprite_grounding()

func configure(at: Vector2, scale_factor := 1.0) -> void:
	# The caller resolves the monster's rendered ground line before spawning.
	global_position = at
	seed_value = float(get_instance_id() % 17)
	scale = Vector2.ONE * scale_factor
	z_index = 2
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	_update_sprite_grounding()
	queue_redraw()
	if elapsed >= duration: queue_free()

func _update_sprite_grounding() -> void:
	if sprite == null or frame_ground_offsets.is_empty():
		return
	var frame := clampi(sprite.frame, 0, frame_ground_offsets.size() - 1)
	sprite.position.y = -frame_ground_offsets[frame]

func _draw() -> void:
	if sprite != null:
		return
	var progress := clampf(elapsed / duration, 0.0, 1.0)
	var fade := 1.0 - progress
	for i in range(4):
		var angle := seed_value * 0.37 + float(i) * 1.57
		var offset := Vector2.from_angle(angle) * (4.0 + progress * (8.0 + i * 3.0))
		var size := 4.0 + i * 1.5 + progress * 5.0
		draw_circle(offset + Vector2(0, -progress * 8.0), size, Color(0.38, 0.40, 0.34, fade * (0.34 - i * 0.045)))
