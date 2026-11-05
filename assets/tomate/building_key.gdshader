shader_type canvas_item;
uniform vec4 frame_uv;
varying vec4 house_tint;
void vertex() {
	house_tint = COLOR;
}
void fragment() {
	vec2 lower = frame_uv.xy + TEXTURE_PIXEL_SIZE * 0.5;
	vec2 upper = frame_uv.xy + frame_uv.zw - TEXTURE_PIXEL_SIZE * 0.5;
	vec4 albedo = texture(TEXTURE, clamp(UV, lower, upper));
	float key = smoothstep(0.07, 0.14, min(albedo.r, albedo.b) - albedo.g);
	albedo.a *= 1.0 - key;
	COLOR = albedo * house_tint;
}
