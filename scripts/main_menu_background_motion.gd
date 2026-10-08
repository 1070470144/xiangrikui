extends Control

## Opaque video frames packed into three atlases, drawn behind all menu controls.
const MANIFEST_PATH := "res://assets/backgrounds/menu_motion/animation.json"
var pages: Array[Texture2D] = []
var frames: Array = []
var fps := 12.0
var elapsed := 0.0
var motion_enabled := true
var available := false
var last_frame := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	if not FileAccess.file_exists(MANIFEST_PATH):
		visible = false
		return
	var metadata = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not metadata is Dictionary:
		visible = false
		return
	fps = maxf(1.0, float(metadata.get("fps", 12.0)))
	frames = metadata.get("frames", [])
	for path in metadata.get("pages", []):
		var texture := load(str(path)) as Texture2D
		if texture == null:
			pages.clear()
			visible = false
			return
		pages.append(texture)
	available = not pages.is_empty() and not frames.is_empty()
	set_motion_enabled(motion_enabled)

func set_motion_enabled(enabled: bool) -> void:
	motion_enabled = enabled
	visible = available and enabled
	set_process(available and enabled)
	if not enabled:
		elapsed = 0.0
		last_frame = -1
	queue_redraw()

func current_frame() -> int:
	return posmod(floori(elapsed * fps), frames.size()) if not frames.is_empty() else 0

func _process(delta: float) -> void:
	if not available or not motion_enabled: return
	elapsed = fmod(elapsed + delta, float(frames.size()) / fps)
	var index := current_frame()
	if index != last_frame:
		last_frame = index
		queue_redraw()

func _draw() -> void:
	if not available or not motion_enabled: return
	var frame: Dictionary = frames[current_frame()]
	var source := Rect2(float(frame.x), float(frame.y), float(frame.w), float(frame.h))
	var factor := maxf(size.x / source.size.x, size.y / source.size.y)
	var target_size := source.size * factor
	var target := Rect2((size - target_size) * 0.5, target_size)
	draw_texture_rect_region(pages[int(frame.page)], target, source)
