shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec2 p = UV - vec2(0.52, 0.48);
	float vignette = smoothstep(0.2, 0.78, length(p)) * 0.38;
	float top = (1.0 - smoothstep(0.0, 0.22, UV.y)) * 0.5;
	float bottom = smoothstep(0.8, 1.0, UV.y) * 0.28;
	COLOR = vec4(0.055, 0.13, 0.085, max(vignette, max(top, bottom)));
}
