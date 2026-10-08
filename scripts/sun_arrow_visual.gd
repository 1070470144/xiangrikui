extends RefCounted

const ROOT := "res://assets/effects/sun_arrow/"
static var cache: Dictionary = {}

static func frames(kind: String) -> SpriteFrames:
	if cache.has(kind): return cache[kind]
	var path := ROOT + kind + "/manifest.json"
	if not FileAccess.file_exists(path): return null
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("status") != "passed": return null
	var result := SpriteFrames.new()
	result.remove_animation("default")
	result.add_animation(kind)
	result.set_animation_loop(kind, kind == "flight")
	result.set_animation_speed(kind, float(data["fps"]))
	for texture_path in data["frame_paths"]:
		if not ResourceLoader.exists(texture_path): return null
		var texture = load(texture_path)
		if not texture is Texture2D: return null
		result.add_frame(kind, texture)
	cache[kind] = result
	return result

static func impact(parent: Node, point: Vector2) -> void:
	var resource := frames("impact")
	if resource == null: return
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = resource
	parent.add_child(sprite)
	sprite.global_position = point
	sprite.scale = Vector2.ONE * 0.35
	sprite.add_to_group("mother_attack_effects")
	sprite.animation_finished.connect(sprite.queue_free)
	sprite.play("impact")
