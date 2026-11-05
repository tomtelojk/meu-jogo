class_name ForestTerrain
extends Node2D

const ROAD_HALF_WIDTH := 44.0
const BORDER_WIDTH := 7.5
# Opaque edging keeps overlapping paths from darkening their intersections.
const BORDER_COLOR := Color("414c2d")
const DIRT_REGION := Rect2i(14, 270, 100, 100)
const DIRT_SHADER := """
shader_type canvas_item;
varying vec4 tint;
void vertex() {
	tint = COLOR;
}
void fragment() {
	vec2 tile = fract(UV);
	vec2 shifted = fract(tile + vec2(0.5));
	// Crossfade only near a repeat edge. The shifted sample's own edge is
	// hidden at the tile center, keeping the source's pixel density intact.
	vec2 blend = smoothstep(vec2(0.2), vec2(0.5), abs(tile - vec2(0.5)));
	vec4 top = mix(texture(TEXTURE, tile), texture(TEXTURE, vec2(shifted.x, tile.y)), blend.x);
	vec4 bottom = mix(texture(TEXTURE, vec2(tile.x, shifted.y)), texture(TEXTURE, shifted), blend.x);
	COLOR = tint * mix(top, bottom, blend.y);
}
"""

func build(ground_image: Image) -> void:
	var dirt := ImageTexture.create_from_image(ground_image.get_region(DIRT_REGION))
	var borders := Node2D.new()
	borders.name = "Borders"
	add_child(borders)
	var surface := Node2D.new()
	surface.name = "Dirt"
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = DIRT_SHADER
	material.shader = shader
	surface.material = material
	add_child(surface)
	for path in WorldData.paths():
		for outline in Geometry2D.offset_polyline(path, ROAD_HALF_WIDTH + BORDER_WIDTH, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND):
			_add_polygon(borders, outline)
		for outline in Geometry2D.offset_polyline(path, ROAD_HALF_WIDTH, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND):
			_add_polygon(surface, outline, dirt)
	var spots: Array[Vector2] = [WorldData.MOTHER, WorldData.CAMP]
	for seed_data in WorldData.SEEDS:
		spots.append(seed_data.position)
	for point in spots:
		var clearing := PackedVector2Array()
		var radius := Vector2(110, 70) if point == WorldData.MOTHER else Vector2(81, 52)
		for i in 36:
			var angle := i / 36.0 * TAU
			clearing.append(point + Vector2(cos(angle), sin(angle)) * radius)
		for outline in Geometry2D.offset_polygon(clearing, BORDER_WIDTH, Geometry2D.JOIN_ROUND):
			_add_polygon(borders, outline)
		_add_polygon(surface, clearing, dirt)

func _add_polygon(layer: Node2D, outline: PackedVector2Array, dirt: Texture2D = null) -> void:
	var patch := Polygon2D.new()
	patch.polygon = outline
	if dirt:
		# UVs use world pixels instead of distance along a line. Curves, caps,
		# intersections and clearings therefore sample precisely the same texels.
		patch.uv = outline
		patch.texture = dirt
		patch.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		patch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		patch.use_parent_material = true
	else:
		patch.color = BORDER_COLOR
	layer.add_child(patch)
