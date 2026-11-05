class_name ForestRiver
extends Node2D

const WATER_SHADER := """
shader_type canvas_item;
uniform sampler2D frame0 : filter_nearest, repeat_enable;
uniform sampler2D frame1 : filter_nearest, repeat_enable;
uniform sampler2D frame2 : filter_nearest, repeat_enable;
uniform sampler2D frame3 : filter_nearest, repeat_enable;
uniform bool bank_mode = false;
uniform float water_time = -1.0;
varying vec4 tint;
void vertex() { tint = COLOR; }
vec4 sample_tile(sampler2D source, vec2 p) {
	vec2 tile = fract(p);
	vec2 shifted = fract(tile + vec2(0.5));
	vec2 blend = smoothstep(vec2(0.2), vec2(0.5), abs(tile - vec2(0.5)));
	if (bank_mode) {
		float x = clamp(p.x, 0.001, 0.999);
		return mix(texture(source, vec2(x, tile.y)), texture(source, vec2(x, shifted.y)), blend.y);
	}
	vec4 a = mix(texture(source, tile), texture(source, vec2(shifted.x, tile.y)), blend.x);
	vec4 b = mix(texture(source, vec2(tile.x, shifted.y)), texture(source, shifted), blend.x);
	return mix(a, b, blend.y);
}
void fragment() {
	float t = water_time >= 0.0 ? water_time : TIME;
	float phase = mod(t * 0.8, 4.0);
	vec2 p = UV;
	if (!bank_mode) { p.y += t * 0.018; }
	vec4 a;
	vec4 b;
	if (phase < 1.0) { a = sample_tile(frame0, p); b = sample_tile(frame1, p); }
	else if (phase < 2.0) { a = sample_tile(frame1, p); b = sample_tile(frame2, p); }
	else if (phase < 3.0) { a = sample_tile(frame2, p); b = sample_tile(frame3, p); }
	else { a = sample_tile(frame3, p); b = sample_tile(frame0, p); }
	COLOR = mix(a, b, smoothstep(0.0, 1.0, fract(phase))) * tint;
}
"""

var water_material: ShaderMaterial
var bank_materials: Array[ShaderMaterial] = []

func build() -> void:
	name = "TomateRiver"
	show_behind_parent = true
	var frames := GroundAtlas.water_frames()
	water_material = _material(frames, false)
	_strip(-80.0, 80.0, frames[0], water_material, false)
	for left in [true, false]:
		var bank := GroundAtlas.bank_texture(left)
		var bank_frames: Array[Texture2D] = [bank, bank, bank, bank]
		var material := _material(bank_frames, true)
		bank_materials.append(material)
		_strip(-88.0 if left else 72.0, -72.0 if left else 93.1, bank, material, true)

func _material(frames: Array[Texture2D], banks: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = WATER_SHADER
	material.shader = shader
	for index in 4:
		material.set_shader_parameter("frame" + str(index), frames[index])
	material.set_shader_parameter("bank_mode", banks)
	return material

func _strip(left: float, right: float, texture: Texture2D, material: ShaderMaterial, banks: bool) -> void:
	var polygon := Polygon2D.new()
	var points := PackedVector2Array()
	var uv := PackedVector2Array()
	for i in 83:
		var y := i / 82.0 * WorldData.SIZE.y
		var p := Vector2(WorldData.river_x(y) + left, y)
		points.append(p)
		uv.append(Vector2(0, y * GroundAtlas.UV_SCALE) if banks else p * GroundAtlas.UV_SCALE)
	for i in range(82, -1, -1):
		var y := i / 82.0 * WorldData.SIZE.y
		var p := Vector2(WorldData.river_x(y) + right, y)
		points.append(p)
		uv.append(Vector2(texture.get_width(), y * GroundAtlas.UV_SCALE) if banks else p * GroundAtlas.UV_SCALE)
	polygon.polygon = points
	polygon.uv = uv
	polygon.texture = texture
	polygon.material = material
	polygon.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	polygon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(polygon)
