extends Node2D

## Fourth-night weather layer. Clouds are deliberately procedural so a missing
## video asset can never leave a black fullscreen quad in the battlefield.
const MANIFEST_PATH := "res://assets/effects/weather/thunderstorm_realism_v1/lightning.json"
const CLOUD_COLOR := Color(0.035, 0.055, 0.085, 0.34)
const CLOUD_HIGHLIGHT := Color(0.13, 0.16, 0.2, 0.11)
const LIGHTNING_COLOR := Color(0.82, 0.9, 1.0, 1.0)
const CLOUD_SHADER := """
shader_type canvas_item;
render_mode unshaded;
uniform float drift = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	for (int i = 0; i < 5; i++) { v += noise(p) * a; p = p * 2.03 + vec2(17.1, 9.2); a *= 0.5; }
	return v;
}
void fragment() {
	vec2 flow = vec2(drift * 0.003, -drift * 0.001);
	float cloud = fbm(UV * vec2(4.0, 5.0) + flow) * 0.65 + fbm(UV * vec2(10.0, 4.0) - flow * 0.6) * 0.35;
	COLOR = vec4(mix(vec3(0.025, 0.04, 0.065), vec3(0.13, 0.15, 0.18), cloud), smoothstep(0.25, 0.8, cloud) * 0.24);
}
"""

var active := false
var cloud_offset := 0.0
var lightning_elapsed := 0.0
var lightning_wait := 8.0
var lightning_phase := 0.0
var lightning_frame := 0
var lightning_playing := false
var trigger_count := 0
var frame_fps := 12.0
var frame_duration := 0.35
var frame_textures: Array[Texture2D] = []
var frame_size := Vector2.ZERO
var qa_passed := false
var _rng := RandomNumberGenerator.new()
var _cloud_layer: ColorRect

func _ready() -> void:
	_rng.seed = 4172026
	_load_manifest()
	_cloud_layer = ColorRect.new()
	_cloud_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cloud_layer.z_index = -1
	var shader := Shader.new()
	shader.code = CLOUD_SHADER
	var cloud_material := ShaderMaterial.new()
	cloud_material.shader = shader
	_cloud_layer.material = cloud_material
	add_child(_cloud_layer)
	visible = false

func _load_manifest(path: String = MANIFEST_PATH) -> void:
	frame_textures.clear()
	qa_passed = false
	frame_size = Vector2.ZERO
	if not FileAccess.file_exists(path): return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary: return
	_apply_manifest(parsed)

func _apply_manifest(parsed: Dictionary) -> void:
	frame_textures.clear()
	qa_passed = bool(parsed.get("qa_passed", false))
	frame_fps = maxf(1.0, float(parsed.get("delivery_fps", 12.0)))
	frame_duration = maxf(0.08, float(parsed.get("trigger_seconds", 0.35)))
	frame_size = Vector2(float(parsed.get("w", 0)), float(parsed.get("h", 0)))
	if not qa_passed or frame_size.x <= 0.0 or frame_size.y <= 0.0:
		qa_passed = false
		return
	var paths: Array = parsed.get("frame_paths", [])
	for frame_path in paths:
		var resource_path := String(frame_path)
		if ResourceLoader.exists(resource_path):
			var texture = load(resource_path)
			if texture is Texture2D and texture.get_size() == frame_size: frame_textures.append(texture)
	if frame_textures.is_empty() or frame_textures.size() != paths.size() or frame_textures.size() != int(parsed.get("frames", paths.size())):
		qa_passed = false
		frame_textures.clear()

func set_active(value: bool) -> void:
	if active == value: return
	active = value
	visible = value
	if not value: reset()
	else:
		lightning_wait = _rng.randf_range(6.0, 12.0)
		queue_redraw()

func reset() -> void:
	active = false
	visible = false
	cloud_offset = 0.0
	lightning_elapsed = 0.0
	lightning_phase = 0.0
	lightning_frame = 0
	lightning_playing = false
	queue_redraw()

func is_active() -> bool: return active

func _process(delta: float) -> void:
	if not active: return
	cloud_offset = fmod(cloud_offset + delta * 9.0, 2400.0)
	if _cloud_layer != null:
		var inverse := get_canvas_transform().affine_inverse()
		_cloud_layer.position = inverse * Vector2.ZERO
		_cloud_layer.size = inverse * get_viewport_rect().size - _cloud_layer.position
		_cloud_layer.material.set_shader_parameter("drift", cloud_offset)
	lightning_elapsed += delta
	if lightning_playing:
		lightning_phase += delta
		lightning_frame = mini(frame_textures.size() - 1, floori(lightning_phase * frame_fps)) if not frame_textures.is_empty() else 0
		if lightning_phase >= frame_duration:
			lightning_playing = false
			lightning_phase = 0.0
			lightning_frame = 0
			lightning_wait = _rng.randf_range(6.0, 12.0)
	elif lightning_elapsed >= lightning_wait:
		lightning_elapsed = 0.0
		lightning_playing = true
		lightning_phase = 0.0
		trigger_count += 1
	queue_redraw()

func _draw() -> void:
	if not active: return
	var inverse := get_canvas_transform().affine_inverse()
	var origin := inverse * Vector2.ZERO
	var view := Rect2(origin, inverse * get_viewport_rect().size - origin)
	var width := maxf(1.0, view.size.x)
	var height := maxf(1.0, view.size.y)
	if lightning_playing:
		var strength := _lightning_strength()
		# A restrained environment lift keeps actors readable during the flash.
		draw_rect(view, Color(0.52, 0.64, 0.8, 0.045 * strength), true)
		if not frame_textures.is_empty() and lightning_frame < frame_textures.size():
			# The accepted clip contains its own preflash and decay timing.
			var size := Vector2.ONE * maxf(width, height)
			var target := Rect2(view.get_center() - size * 0.5, size)
			draw_texture_rect(frame_textures[lightning_frame], target, false, Color(1, 1, 1, 0.28))
		else:
			_draw_fallback_lightning(view.get_center(), strength)

func _lightning_strength() -> float:
	var t := clampf(lightning_phase / frame_duration, 0.0, 1.0)
	if t < 0.18: return t / 0.18 * 0.25
	if t < 0.42: return 1.0
	return (1.0 - t) / 0.58

func _draw_fallback_lightning(origin: Vector2, strength: float) -> void:
	var bolt := PackedVector2Array([origin + Vector2(-34, -250), origin + Vector2(-6, -150), origin + Vector2(-28, -72), origin + Vector2(8, 0)])
	var branch := PackedVector2Array([origin + Vector2(-8, -151), origin + Vector2(68, -106), origin + Vector2(42, -42)])
	draw_polyline(bolt, Color(LIGHTNING_COLOR, 0.75 * strength), 4.0, true)
	draw_polyline(branch, Color(LIGHTNING_COLOR, 0.5 * strength), 2.0, true)
