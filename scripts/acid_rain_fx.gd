extends Node2D

## Seedance clip -> sprite-gen keyed frames -> fixed-cycle strip.
## World-anchored cells keep impacts stationary while the camera pans.
const NEW_STRIP_PATH := "res://assets/effects/weather/acid_rain_realism_v2/acid_rain.strip.png"
const NEW_META_PATH := "res://assets/effects/weather/acid_rain_realism_v2/acid_rain.strip.json"
const STRIP_PATH := "res://assets/effects/weather/acid_rain.strip.png"
const META_PATH := "res://assets/effects/weather/acid_rain.strip.json"
const CELL_SPACING := Vector2(92, 94)
const EFFECT_HEIGHT := 64.0
const WORLD_SIZE := 2880.0

var cycle_texture: Texture2D
var frame_textures: Array[Texture2D] = []
var frame_count := 0
var frame_size := Vector2.ZERO
var cycle_seconds := 1.0
var elapsed := 0.0
var active := false

func _ready() -> void:
	var metadata = _load_metadata(NEW_META_PATH)
	if metadata.get("qa_passed", false):
		frame_size = Vector2(float(metadata.get("w", 0)), float(metadata.get("h", 0)))
		cycle_seconds = maxf(0.001, float(metadata.get("cycle_seconds", 1.0)))
		var frame_paths: Array = metadata.get("frame_paths", [])
		for frame_path in frame_paths:
			if ResourceLoader.exists(String(frame_path)):
				frame_textures.append(load(String(frame_path)))
		if frame_textures.size() > 0:
			frame_count = frame_textures.size()
	if frame_textures.is_empty() and cycle_texture == null:
		metadata = _load_metadata(META_PATH)
		cycle_texture = load(STRIP_PATH)
	if metadata is Dictionary:
		if frame_textures.is_empty():
			frame_count = int(metadata.get("frames", 0))
			frame_size = Vector2(float(metadata.get("w", 0)), float(metadata.get("h", 0)))
		cycle_seconds = maxf(0.001, float(metadata.get("cycle_seconds", 1.0)))
	visible = active

func _load_metadata(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

func set_active(value: bool) -> void:
	if active == value: return
	active = value
	visible = value
	if not value: elapsed = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	if not active: return
	elapsed = fmod(elapsed + delta, cycle_seconds)
	queue_redraw()

func _cell_random(x: int, y: int, salt: float) -> float:
	return fposmod(sin(float(x) * 127.1 + float(y) * 311.7 + salt) * 43758.5453, 1.0)

func _draw() -> void:
	if not active or (cycle_texture == null and frame_textures.is_empty()) or frame_count <= 0: return
	if frame_size.x <= 0.0 or frame_size.y <= 0.0: return
	var inverse := get_canvas_transform().affine_inverse()
	var effect_size := Vector2(EFFECT_HEIGHT * frame_size.x / frame_size.y, EFFECT_HEIGHT)
	var top_left := inverse * Vector2.ZERO
	var bottom_right := inverse * get_viewport_rect().size
	for y in range(maxi(0, floori(top_left.y / CELL_SPACING.y) - 1), mini(ceili(WORLD_SIZE / CELL_SPACING.y), ceili(bottom_right.y / CELL_SPACING.y) + 1)):
		for x in range(maxi(0, floori(top_left.x / CELL_SPACING.x) - 1), mini(ceili(WORLD_SIZE / CELL_SPACING.x), ceili(bottom_right.x / CELL_SPACING.x) + 1)):
			var offset := Vector2(_cell_random(x, y, 0.0), _cell_random(x, y, 25.0)) * CELL_SPACING * 0.8
			var position_on_ground := Vector2(x, y) * CELL_SPACING + offset
			var frame := mini(frame_count - 1, floori(fposmod(elapsed / cycle_seconds + _cell_random(x, y, 50.0), 1.0) * frame_count))
			var target := Rect2(position_on_ground - effect_size * Vector2(0.5, 0.75), effect_size)
			if not frame_textures.is_empty():
				draw_texture_rect(frame_textures[frame], target, false, Color(0.95, 1.0, 0.76, 0.68))
			else:
				var source := Rect2(Vector2(frame * frame_size.x, 0), frame_size)
				draw_texture_rect_region(cycle_texture, target, source, Color(0.95, 1.0, 0.76, 0.68))
