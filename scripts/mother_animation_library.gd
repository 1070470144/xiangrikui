extends RefCounted

const ROOT := "res://assets/core/generated/mother_motion_v2/"
static var _cache: Dictionary = {}

static func load_frames(form: String = "base") -> SpriteFrames:
	if form.is_empty(): form = "base"
	if not form in ["base", "sun_arrow", "root_heart", "dawn_pulse"]: return null
	if _cache.has(form): return _cache[form]
	var frames := load_manifest(ROOT + form + "/manifest.json")
	if form == "sun_arrow" and frames != null:
		var attack = preload("res://scripts/sun_arrow_visual.gd").frames("attack")
		if attack != null:
			frames.add_animation("attack")
			frames.set_animation_loop("attack", false)
			frames.set_animation_speed("attack", attack.get_animation_speed("attack"))
			for i in attack.get_frame_count("attack"):
				frames.add_frame("attack", attack.get_frame_texture("attack", i))
	_cache[form] = frames
	return frames

static func load_manifest(path: String) -> SpriteFrames:
	if not FileAccess.file_exists(path): return null
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("status", "") != "passed": return null
	var paths = data.get("frame_paths", [])
	var fps := float(data.get("fps", 0.0))
	if not paths is Array or paths.size() < 2 or fps <= 0.0: return null
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("idle")
	frames.set_animation_speed("idle", fps)
	frames.set_animation_loop("idle", bool(data.get("loop", true)))
	for frame_path in paths:
		if not frame_path is String or not frame_path.begins_with(ROOT): return null
		var texture = load(frame_path) if ResourceLoader.exists(frame_path) else null
		if not texture is Texture2D: return null
		frames.add_frame("idle", texture)
	return frames
