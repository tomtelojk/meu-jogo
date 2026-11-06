class_name ForestTerrain
extends Node2D

const ROAD_HALF_WIDTH := 44.0
const BORDER_WIDTH := 7.5
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

func build() -> void:
	var dirt := GroundAtlas.tile(1, 0)
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
		for outline in Geometry2D.offset_polyline(path, ROAD_HALF_WIDTH, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND):
			_add_edge(borders, outline)
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
		_add_edge(borders, clearing)
		var texture := dirt
		if point == WorldData.SEEDS[2].position:
			texture = GroundAtlas.tile(4, 0)
		elif point == WorldData.SEEDS[3].position:
			texture = GroundAtlas.tile(2, 3)
		_add_polygon(surface, clearing, texture)
	# The stone and moss rows form small plazas at the two capitals.
	for id in ["aurelia", "valverde"]:
		var plaza := PackedVector2Array()
		var center: Vector2 = KingdomData.REALMS[id].capital
		for i in 36:
			var angle := i / 36.0 * TAU
			plaza.append(center + Vector2(cos(angle) * 105.0, sin(angle) * 67.0))
		_add_edge(borders, plaza)
		_add_polygon(surface, plaza, GroundAtlas.tile(3 if id == "aurelia" else 4, 2))

func _add_edge(layer: Node2D, outline: PackedVector2Array) -> void:
	# This layer is behind every road fill, so junctions never acquire a green
	# stripe from the outline of a crossing road. Only the outer fringe remains.
	var points := outline.duplicate()
	var signed_area := 0.0
	for index in points.size():
		signed_area += points[index].cross(points[(index + 1) % points.size()])
	if signed_area < 0:
		points.reverse()
	points.append(points[0])
	var edge := Line2D.new()
	edge.points = points
	edge.width = BORDER_WIDTH * 2.0
	edge.joint_mode = Line2D.LINE_JOINT_ROUND
	edge.texture = GroundAtlas.transition_strip()
	edge.texture_mode = Line2D.LINE_TEXTURE_TILE
	edge.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	edge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.add_child(edge)

func _add_polygon(layer: Node2D, outline: PackedVector2Array, dirt: Texture2D = null) -> void:
	var patch := Polygon2D.new()
	patch.polygon = outline
	if dirt:
		# UVs use world pixels instead of distance along a line. Curves, caps,
		# intersections and clearings therefore sample precisely the same texels.
		var uv := PackedVector2Array()
		for point in outline:
			uv.append(point * GroundAtlas.UV_SCALE)
		patch.uv = uv
		patch.texture = dirt
		patch.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		patch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		patch.use_parent_material = true
	layer.add_child(patch)

func build_region(region:Rect2)->void:
	# Draw complete world-coordinate outlines and let the viewport clip them.
	# Cutting the outlines would introduce false borders between chunks.
	var borders:=Node2D.new()
	add_child(borders)
	var surface:=Node2D.new()
	add_child(surface)
	var material:=ShaderMaterial.new()
	var shader:=Shader.new()
	shader.code=DIRT_SHADER
	material.shader=shader
	surface.material=material
	var dirt:=GroundAtlas.tile(1,0)
	for path in WorldData.paths():
		var bounds:=Rect2(path[0],Vector2.ZERO)
		for point in path:bounds=bounds.expand(point)
		if not bounds.grow(ROAD_HALF_WIDTH+BORDER_WIDTH).intersects(region):continue
		for outline in Geometry2D.offset_polyline(path,ROAD_HALF_WIDTH,Geometry2D.JOIN_ROUND,Geometry2D.END_ROUND):
			_add_edge(borders,outline)
			_add_polygon(surface,outline,dirt)
	for town in KingdomData.SETTLEMENTS:
		var center:Vector2=town.position
		if region.grow(140).has_point(center):
			var points:=PackedVector2Array()
			for i in 32:
				points.append(center+Vector2(cos(i*TAU/32),sin(i*TAU/32))*Vector2(140,100))
			_add_polygon(surface,points,GroundAtlas.tile(3 if town.realm=="aurelia" else 4,2))
		var farm:=Rect2(center+Vector2(1472,640),Vector2(384,384))
		if region.intersects(farm):
			var points:=PackedVector2Array([farm.position,Vector2(farm.end.x,farm.position.y),farm.end,Vector2(farm.position.x,farm.end.y)])
			_add_polygon(surface,points,GroundAtlas.tile(1,3))
			for i in 12:
				var line:=Line2D.new()
				line.points=PackedVector2Array([farm.position+Vector2(16+i*30,16),Vector2(farm.position.x+16+i*30,farm.end.y-16)])
				line.width=7
				line.default_color=Color("a1ae50") if i%2==0 else Color("7d9c44")
				surface.add_child(line)
