shader_type canvas_item;
render_mode unshaded;

uniform sampler2D surface_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 world_size = vec2(2880.0);
uniform vec2 world_origin = vec2(0.0);
varying vec2 surface_position;
varying vec4 surface_tint;
uniform float daylight_amount = 1.0;
uniform vec2 sun_direction = vec2(0.65, 0.76);
uniform vec4 sun_color : source_color = vec4(1.0, 0.94, 0.81, 1.0);
uniform vec4 ambient_color : source_color = vec4(0.96, 0.95, 0.89, 1.0);
uniform float shadow_strength = 0.42;
uniform float bounce_strength = 0.08;
uniform vec4 local_lights[32];
uniform int light_count = 0;

float luminance(vec3 color) { return dot(color, vec3(0.2126, 0.7152, 0.0722)); }

void vertex() {
	// TileMap quadrants have separate transforms; MODEL_MATRIX joins them into
	// one world surface. Camera movement never changes the sampled position.
	surface_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy - world_origin;
	surface_tint = COLOR;
}

void fragment() {
	vec2 uv = surface_position / world_size;
	vec4 surface = texture(surface_texture, uv) * surface_tint;
	// A shallow relief estimate from the authored surface, anchored to world space.
	vec2 step_uv = sun_direction * 3.0 / world_size;
	float relief = luminance(texture(surface_texture, uv - step_uv).rgb)
		- luminance(texture(surface_texture, uv + step_uv).rgb);
	float sunlight = clamp(1.0 + relief * shadow_strength * 1.4, 0.87, 1.1);
	vec3 illumination = ambient_color.rgb * sunlight;
	illumination += sun_color.rgb * daylight_amount * bounce_strength;
	float local_glow = 0.0;
	for (int i = 0; i < 32; i++) {
		if (i >= light_count) { break; }
		float falloff = max(0.0, 1.0 - distance(surface_position + world_origin, local_lights[i].xy) / max(local_lights[i].z, 1.0));
		local_glow = max(local_glow, falloff * falloff * local_lights[i].w);
	}
	illumination = mix(illumination, vec3(1.0, 0.85, 0.58), local_glow * (1.0 - daylight_amount));
	COLOR = vec4(surface.rgb * illumination, surface.a);
}
