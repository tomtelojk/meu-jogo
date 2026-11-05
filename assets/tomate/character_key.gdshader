shader_type canvas_item;

uniform vec4 clothing_tint : source_color = vec4(1.0);
varying vec4 character_tint;

void vertex() {
	character_tint = COLOR;
}

void fragment() {
	vec4 albedo = texture(TEXTURE, UV);
	// The provided RGB sheets use magenta as their transparency key. Keep the
	// files unchanged and remove the key only while rendering the character.
	float key = min(albedo.r, albedo.b) - albedo.g;
	albedo.a *= 1.0 - smoothstep(0.25, 0.5, key);
	// A restrained tint differentiates villagers without recoloring skin, hat,
	// boots or the source files. The bright hands are excluded from this band.
	float cloth = step(0.44, UV.y) * step(UV.y, 0.68);
	cloth *= step(0.08, albedo.r) * step(albedo.r, 0.68);
	cloth *= smoothstep(0.06, 0.18, albedo.r - albedo.g);
	albedo.rgb = mix(albedo.rgb, albedo.rgb * clothing_tint.rgb, cloth * 0.55);
	COLOR = albedo * character_tint;
}
