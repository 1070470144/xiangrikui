shader_type canvas_item;
render_mode unshaded;

varying vec4 draw_tint;
void vertex() {
	draw_tint = COLOR;
}
void fragment() {
	vec4 mask = texture(TEXTURE, UV);
	// Alpha encodes the composite at strength=1; reconstruct layer coverage.
	float layers = log(max(0.00001, 1.0 - mask.a)) / log(1.0 - 0.045);
	float alpha = 1.0 - pow(1.0 - 0.045 * draw_tint.a, layers);
	COLOR = vec4(draw_tint.rgb, alpha);
}
