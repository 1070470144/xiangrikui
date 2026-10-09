extends Node2D

var frames: Array[AtlasTexture] = []
var sprite := Sprite2D.new()
var elapsed := 0.0
var duration := 1.0
var attached: Node2D
var offset := Vector2.ZERO
var effect_owner := 0

func configure(kind: String, point: Vector2, radius: float, lifetime: float, owner_id: int, follow: Node2D = null) -> bool:
	var path := "res://assets/effects/root_boss/atlas_manifest.json"
	if not FileAccess.file_exists(path): return false
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not manifest is Dictionary or not manifest.get("states", {}).has(kind): return false
	var spec: Dictionary = manifest.states[kind]
	var pages: Dictionary = {}
	for record in spec.regions:
		var page := str(record.page)
		if not pages.has(page): pages[page] = load("res://assets/effects/root_boss/" + page) as Texture2D
		var texture: Texture2D = pages[page]
		if texture == null: return false
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		var rect: Array = record.region
		atlas.region = Rect2(rect[0], rect[1], rect[2], rect[3])
		atlas.filter_clip = true
		frames.append(atlas)
	if frames.is_empty(): return false
	duration = maxf(lifetime, 0.01)
	effect_owner = owner_id
	attached = follow
	global_position = point
	if attached != null: offset = point - attached.global_position
	add_child(sprite)
	sprite.texture = frames[0]
	sprite.scale = Vector2.ONE * (radius * 2.0 / float(spec.width))
	return true

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration or (attached != null and (not is_instance_valid(attached) or attached.health <= 0.0)):
		queue_free()
		return
	if is_instance_valid(attached): global_position = attached.global_position + offset
	sprite.texture = frames[mini(frames.size() - 1, int(elapsed / duration * frames.size()))]
