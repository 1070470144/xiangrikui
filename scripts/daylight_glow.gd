extends Node2D

const BattlefieldSpec = preload("res://scripts/battlefield_spec.gd")
const VIEW_SIZE := BattlefieldSpec.WORLD_RECT.size
const LIGHT_CENTER := BattlefieldSpec.CENTER
const MAX_OPACITY := 0.18
const FADE_SPEED := 0.65

const LIGHT_SHADER := """
shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec2 light_center = vec2(0.5, 0.5216);
uniform float max_opacity = 0.18;
uniform vec2 sun_direction = vec2(0.65, 0.76);
uniform vec4 sun_color : source_color = vec4(1.0, 0.94, 0.81, 1.0);

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
		p = p * 2.01 + vec2(13.7, 8.3);
		amplitude *= 0.5;
	}
	return value;
}

float soft_beam(vec2 uv, float top_x, float target_x, float width) {
	float center_x = top_x + uv.y * sun_direction.x / max(0.1, sun_direction.y);
	float distance_to_axis = abs(uv.x - center_x);
	return 1.0 - smoothstep(width * 0.28, width, distance_to_axis);
}

void fragment() {
	vec2 delta = UV - light_center;
	float distance_from_light = length(delta);
	float center_glow = 1.0 - smoothstep(0.025, 0.29, distance_from_light);

	float sway = sin(TIME * 0.12) * 0.012;
	float beam_left = soft_beam(UV, 0.25 + sway, light_center.x - 0.055, 0.17);
	float beam_center = soft_beam(UV, 0.49 - sway * 0.4, light_center.x, 0.135);
	float beam_right = soft_beam(UV, 0.74 + sway * 0.7, light_center.x + 0.06, 0.16);
	float beams = max(beam_center, max(beam_left * 0.72, beam_right * 0.66));

	float vertical_fade = smoothstep(0.01, 0.14, UV.y) * (1.0 - smoothstep(0.76, 1.0, UV.y));
	float air = fbm(UV * vec2(4.2, 7.5) + vec2(TIME * 0.018, TIME * -0.025));
	float broken_light = smoothstep(0.24, 0.82, air);
	beams *= mix(0.46, 1.0, broken_light) * vertical_fade;

	vec2 dust_uv = UV * vec2(42.0, 25.0) + vec2(TIME * -0.11, TIME * 0.17);
	float dust = smoothstep(0.91, 0.985, noise(dust_uv)) * beams;
	float pulse = 0.97 + sin(TIME * 0.31) * 0.03;
	float alpha = (beams * 0.68 + center_glow * 0.36 + dust * 0.58) * max_opacity * pulse * intensity;
	vec3 sunlight = sun_color.rgb;
	COLOR = vec4(sunlight, alpha);
}
"""

var _active := true
var _intensity := 0.0
var _material: ShaderMaterial
var _lighting_driven := false

func set_lighting_state(state: Dictionary) -> void:
	_lighting_driven = true
	_intensity = state.daylight_amount
	visible = _intensity > 0.0
	if _material != null:
		_material.set_shader_parameter("intensity", _intensity)
		_material.set_shader_parameter("sun_direction", state.sun_direction)
		_material.set_shader_parameter("sun_color", state.sun_color)

func _ready() -> void:
	z_index = 11
	var overlay := ColorRect.new()
	overlay.name = "SunlightOverlay"
	overlay.position = Vector2.ZERO
	overlay.size = VIEW_SIZE
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = LIGHT_SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter("light_center", LIGHT_CENTER / VIEW_SIZE)
	_material.set_shader_parameter("max_opacity", MAX_OPACITY)
	overlay.material = _material
	add_child(overlay)
	set_process(true)

func set_active(value: bool) -> void:
	_active = value
	if value:
		visible = true

func is_active() -> bool:
	return _active

func get_max_opacity() -> float:
	return MAX_OPACITY

func uses_directional_shafts() -> bool:
	return true

func _process(delta: float) -> void:
	if _lighting_driven: return
	var target := 1.0 if _active else 0.0
	_intensity = move_toward(_intensity, target, delta * FADE_SPEED)
	if _material != null:
		_material.set_shader_parameter("intensity", _intensity)
	if not _active and is_zero_approx(_intensity):
		visible = false
