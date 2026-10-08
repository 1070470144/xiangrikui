shader_type canvas_item;
render_mode unshaded;
uniform vec4 light_tint : source_color = vec4(1.0);
uniform float daylight_amount = 1.0;
uniform vec2 sun_direction = vec2(0.65, 0.76);
varying vec4 body_tint;
void vertex() { body_tint = COLOR; }
void fragment() {
	vec4 body = texture(TEXTURE, UV) * body_tint;
	float facing = clamp(dot(vec2(0.5) - UV, sun_direction), -0.5, 0.5);
	body.rgb *= light_tint.rgb * (1.0 + facing * 0.18 * daylight_amount);
	COLOR = body;
}
