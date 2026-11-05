shader_type canvas_item;

// The atlas contains different drawings, not an in-betweened animation.
// Keep one drawing intact and bend only the foliage in a continuous breeze.
uniform vec4 frame_uv;
uniform float vitality : hint_range(0.0, 1.0) = 1.0;
uniform float wind_time = -1.0;
uniform float wind_strength = 1.0;
varying vec2 breeze;
varying vec4 tree_tint;

void vertex() {
	float t = wind_time >= 0.0 ? wind_time : TIME;
	vec2 place = MODEL_MATRIX[3].xy;
	float phase = dot(place, vec2(0.0026, 0.0017)) + frame_uv.y * 0.85;
	float gust = 0.65 + 0.25 * sin(t * 0.19 + phase * 0.7);
	breeze = wind_strength * vec2(8.0 * gust * (sin(t * 0.68 + phase) + 0.22 * sin(t * 1.08 + phase * 1.37)), 0.5 * sin(t * 0.53 + phase));
	tree_tint = COLOR;
}

void fragment() {
	vec2 local = (UV - frame_uv.xy) / frame_uv.zw;
	// The lower trunk and its roots receive exactly zero displacement. Upper
	// branches progressively follow the crown instead of the whole tree sliding.
	float foliage = 1.0 - smoothstep(0.43, 0.77, local.y);
	vec2 sample_uv = UV - breeze * foliage * TEXTURE_PIXEL_SIZE;
	vec2 lower = frame_uv.xy + TEXTURE_PIXEL_SIZE * 0.5;
	vec2 upper = frame_uv.xy + frame_uv.zw - TEXTURE_PIXEL_SIZE * 0.5;
	vec2 inside = step(lower, sample_uv) * step(sample_uv, upper);
	vec4 albedo = texture(TEXTURE, clamp(sample_uv, lower, upper));
	albedo.a *= inside.x * inside.y;
	// RGB originals use a magenta key, including their purple baked shadow.
	float key = smoothstep(0.07, 0.14, min(albedo.r, albedo.b) - albedo.g);
	albedo.a *= 1.0 - key;
	float gray = dot(albedo.rgb, vec3(0.299, 0.587, 0.114));
	albedo.rgb = mix(vec3(gray) * vec3(0.86, 0.87, 0.81), albedo.rgb, vitality);
	COLOR = albedo * tree_tint;
}
