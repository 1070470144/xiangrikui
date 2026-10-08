extends Node2D

const BattlefieldSpec = preload("res://scripts/battlefield_spec.gd")

const VIEW_SIZE := BattlefieldSpec.WORLD_RECT.size
const LIGHT_CENTER := BattlefieldSpec.CENTER
const REVEAL_RADIUS := 90.0
const EDGE_OPACITY := 0.985
const FOG_BRIGHTNESS := 0.28
const FADE_SPEED := 0.85
const REVEAL_TEXTURE_SIZE := 288
const REVEAL_UPDATE_SECONDS := 0.05
const REVEAL_FADE_SECONDS := 0.5
const REVEAL_EDGE := 60.0
const INNER_RING := 2.0
const OUTER_RING := 7.0
const RING_DISTANCE := 200.0
const SPREAD_SECONDS := 45.0

const FOG_SHADER := """
shader_type canvas_item;
render_mode unshaded;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D reveal_texture : filter_linear, repeat_disable;
uniform vec2 world_origin = vec2(0.0);
uniform vec2 world_size = vec2(2880.0);
varying vec2 world_position;
uniform float edge_opacity = 0.985;
uniform float spread_radius = 1400.0;
uniform vec3 fog_shadow = vec3(0.12, 0.15, 0.23);
uniform vec3 fog_highlight = vec3(0.34, 0.38, 0.46);

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.52;
	for (int i = 0; i < 4; i++) {
		value += noise(p) * amplitude;
		p = p * 2.03 + vec2(17.1, 9.2);
		amplitude *= 0.5;
	}
	return value;
}

void fragment() {
	vec2 world_uv = (world_position - world_origin) / world_size;

	vec2 drift = vec2(TIME * 0.025, TIME * -0.012);
	float broad_cloud = fbm(UV * vec2(3.2, 5.8) + drift);
	float long_wisps = fbm(UV * vec2(8.5, 2.4) - drift * 1.45);
	float fine_mist = fbm(UV * vec2(15.0, 9.0) + drift * 0.7);
	float cloud = broad_cloud * 0.48 + long_wisps * 0.34 + fine_mist * 0.18;
	float wisp = smoothstep(0.34, 0.76, cloud);

	float fog_mask = 1.0 - texture(reveal_texture, world_uv).r;
	float moving_density = mix(0.89, 1.0, wisp);
	float front = smoothstep(spread_radius - 80.0, spread_radius + 80.0,
		length(world_position - world_origin - world_size * 0.5));
	float alpha = mix(0.015, edge_opacity * moving_density, fog_mask) * intensity * front;

	vec3 color = mix(fog_shadow, fog_highlight, wisp * 0.82);
	color += vec3(0.025, 0.030, 0.040) * fine_mist;
	COLOR = vec4(color, alpha);
}
"""

var _active := false
var _intensity := 0.0
var _overlay: ColorRect
var _material: ShaderMaterial
var _lighting_driven := false
var _night_amount := 0.0
var _weather_weight := 0.0
var _reveal_sources: Dictionary = {}
var _reveal_elapsed := 0.0
var _reveal_dirty := true
var _reveal_image: Image
var _reveal_texture: ImageTexture
var _spread_elapsed := 0.0

func reset_spread() -> void:
	_spread_elapsed = 0.0
	if _material != null: _material.set_shader_parameter("spread_radius", get_spread_radius())

func get_spread_radius() -> float:
	return lerpf(OUTER_RING, INNER_RING, clampf(_spread_elapsed / SPREAD_SECONDS, 0.0, 1.0)) * RING_DISTANCE

func set_reveal_sources(sources: Array[Dictionary]) -> void:
	var present: Dictionary = {}
	for source in sources:
		var id: int = source.id
		present[id] = true
		if not _reveal_sources.has(id):
			_reveal_sources[id] = {"position":source.position, "radius":source.radius, "strength":0.0, "target":1.0}
			_reveal_dirty = true
		var entry: Dictionary = _reveal_sources[id]
		if entry.position != source.position or entry.radius != source.radius or entry.target != 1.0:
			_reveal_dirty = true
		entry.position = source.position
		entry.radius = source.radius
		entry.target = 1.0
	for id in _reveal_sources:
		if not present.has(id): _reveal_sources[id].target = 0.0

func clear_reveal_sources() -> void:
	reset_spread()
	_reveal_sources.clear()
	_reveal_elapsed = 0.0
	_reveal_dirty = true
	_rebuild_reveal_texture()

func _advance_reveal(delta: float) -> void:
	_reveal_elapsed += maxf(0.0, delta)
	var steps := floori((_reveal_elapsed + 0.000001) / REVEAL_UPDATE_SECONDS)
	if steps == 0: return
	var elapsed := steps * REVEAL_UPDATE_SECONDS
	_reveal_elapsed = maxf(0.0, _reveal_elapsed - elapsed)
	for id in _reveal_sources.keys():
		var source: Dictionary = _reveal_sources[id]
		var strength := move_toward(float(source.strength), float(source.target), elapsed / REVEAL_FADE_SECONDS)
		if strength != source.strength: _reveal_dirty = true
		source.strength = strength
		if strength == 0.0 and source.target == 0.0: _reveal_sources.erase(id)
	if _reveal_dirty: _rebuild_reveal_texture()

func _rebuild_reveal_texture() -> void:
	var pixels := PackedByteArray()
	pixels.resize(REVEAL_TEXTURE_SIZE * REVEAL_TEXTURE_SIZE)
	var texel_size := VIEW_SIZE / float(REVEAL_TEXTURE_SIZE)
	for source in _reveal_sources.values():
		if source.strength <= 0.0: continue
		var point: Vector2 = to_local(source.position) if is_inside_tree() else source.position
		var radius: float = source.radius
		var extent := Vector2.ONE * (radius + REVEAL_EDGE)
		var lower := Vector2i(((point - extent) / texel_size).floor()).clamp(Vector2i.ZERO, Vector2i.ONE * REVEAL_TEXTURE_SIZE)
		var upper := Vector2i(((point + extent) / texel_size).ceil()).clamp(Vector2i.ZERO, Vector2i.ONE * REVEAL_TEXTURE_SIZE)
		for y in range(lower.y, upper.y):
			for x in range(lower.x, upper.x):
				var distance := ((Vector2(x, y) + Vector2.ONE * 0.5) * texel_size).distance_to(point)
				var amount := (1.0 - smoothstep(radius, radius + REVEAL_EDGE, distance)) * float(source.strength)
				var index := y * REVEAL_TEXTURE_SIZE + x
				pixels[index] = maxi(pixels[index], roundi(amount * 255.0))
	_reveal_image = Image.create_from_data(REVEAL_TEXTURE_SIZE, REVEAL_TEXTURE_SIZE, false, Image.FORMAT_R8, pixels)
	if _reveal_texture == null: _reveal_texture = ImageTexture.create_from_image(_reveal_image)
	else: _reveal_texture.update(_reveal_image)
	_reveal_dirty = false

func set_lighting_state(state: Dictionary) -> void:
	_lighting_driven = true
	_night_amount = 1.0 - float(state.daylight_amount)
	_intensity = _night_amount * _weather_weight
	visible = _intensity > 0.0
	if _material != null: _material.set_shader_parameter("intensity", _intensity)

func _ready() -> void:
	z_index = 12
	visible = false
	_overlay = ColorRect.new()
	_overlay.name = "FogMask"
	_overlay.position = Vector2.ZERO
	_overlay.size = VIEW_SIZE
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = FOG_SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	_rebuild_reveal_texture()
	_material.set_shader_parameter("reveal_texture", _reveal_texture)
	_material.set_shader_parameter("world_origin", global_position)
	_material.set_shader_parameter("world_size", VIEW_SIZE)
	_material.set_shader_parameter("edge_opacity", EDGE_OPACITY)
	_overlay.material = _material
	add_child(_overlay)
	set_process(true)

func set_active(value: bool) -> void:
	if _active == value: return
	_active = value
	if value:
		visible = true
	else:
		_weather_weight = 0.0
		_intensity = 0.0
		visible = false
		if _material != null: _material.set_shader_parameter("intensity", 0.0)

func is_active() -> bool:
	return _active

func get_reveal_radius() -> float:
	return REVEAL_RADIUS

func get_world_size() -> Vector2:
	return VIEW_SIZE

func get_light_center() -> Vector2:
	return LIGHT_CENTER

func get_edge_opacity() -> float:
	return EDGE_OPACITY

func get_fog_brightness() -> float:
	return FOG_BRIGHTNESS

func _process(delta: float) -> void:
	if _active:
		_spread_elapsed = minf(SPREAD_SECONDS, _spread_elapsed + maxf(0.0, delta))
		if _material != null: _material.set_shader_parameter("spread_radius", get_spread_radius())
	_advance_reveal(delta)
	if _lighting_driven:
		_weather_weight = move_toward(_weather_weight, 1.0 if _active else 0.0, delta * FADE_SPEED)
		return
	var target := 1.0 if _active else 0.0
	_intensity = move_toward(_intensity, target, delta * FADE_SPEED)
	if _material != null:
		_material.set_shader_parameter("intensity", _intensity)
	if not _active and is_zero_approx(_intensity):
		visible = false
