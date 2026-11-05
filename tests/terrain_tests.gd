class_name TerrainTests
extends RefCounted

static func run(runner, world: ForestWorld) -> void:
	_test_atlas(runner)
	var terrain: ForestTerrain = world.get_node("ForestPaths")
	var samples: Array[Vector2] = []
	for path in WorldData.paths():
		for index in path.size() - 1:
			var steps := maxi(1, ceili(path[index].distance_to(path[index + 1]) / 24.0))
			for step in steps + 1:
				samples.append(path[index].lerp(path[index + 1], float(step) / steps))
	var covered := true
	var anchored := true
	for point in samples:
		var patches := _at(terrain, point)
		covered = covered and not patches.is_empty()
		for patch in patches:
			anchored = anchored and _texture_point(patch, point).distance_to(point * GroundAtlas.UV_SCALE) < 0.02
	runner.verify(covered, "ruas cobrem todos os percursos, curvas, cruzamentos e pontas")
	runner.verify(anchored, "textura de terra mantém escala e posição nos cruzamentos e curvas")
	# The southern end is isolated from all other roads and clearings.
	var end := Vector2(23, 38) * WorldData.TILE
	runner.verify(not _at(terrain, end + Vector2(43, -60)).is_empty() and _at(terrain, end + Vector2(45, -60)).is_empty(), "largura original de 88 pixels preservada")
	runner.verify(not _at(terrain, end + Vector2(0, 43)).is_empty() and _at(terrain, end + Vector2(0, 45)).is_empty(), "ponta arredondada preserva raio de 44 pixels")
	var spots: Array[Vector2] = [WorldData.MOTHER, WorldData.CAMP]
	for seed_data in WorldData.SEEDS:
		spots.append(seed_data.position)
	var clearings_covered := true
	for point in spots:
		clearings_covered = clearings_covered and not _at(terrain, point).is_empty()
	runner.verify(clearings_covered, "clareiras da árvore-mãe, acampamento e sementes preservadas")
	_test_river(runner, world)

static func _test_atlas(runner) -> void:
	var source := GroundAtlas.source_image(GroundAtlas.TERRAIN_PATH)
	var original_pixels := true
	var no_borders := true
	for row in 5:
		for column in 8:
			var image := GroundAtlas.tile(row, column).get_image()
			var region := GroundAtlas.region(row, column)
			original_pixels = original_pixels and image.get_size() == Vector2i(176, 176)
			for point in [Vector2i.ZERO, Vector2i(87, 87), Vector2i(175, 175)]:
				original_pixels = original_pixels and image.get_pixelv(point).is_equal_approx(source.get_pixelv(region.position + point))
			no_borders = no_borders and not _contains_sheet_border(image)
	runner.verify(original_pixels, "quarenta tiles de tomate.zip mantêm os pixels e recortes inteiros originais")
	runner.verify(no_borders, "recortes de terreno excluem o fundo magenta e a grade preta da prancha")
	var tiles := GroundAtlas.create_grass_tiles()
	var variants: Dictionary = {}
	for y in WorldData.ROWS:
		for x in WorldData.COLS:
			variants[GroundAtlas.grass_variant(x, y)] = true
	runner.verify(tiles.get_source_count() == 8 and variants.size() == 8, "o chão usa as oito variações de grama com flores e pedras do pacote")
	runner.verify(not _contains_sheet_border(GroundAtlas.transition_strip().get_image()), "franjas dos caminhos usam a transição grama e terra sem a grade da folha")

static func _contains_sheet_border(image: Image) -> bool:
	var dark_rows := 0
	for y in image.get_height():
		var dark := 0
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.r > 0.65 and color.b > 0.65 and color.g < 0.25:
				return true
			if maxf(color.r, maxf(color.g, color.b)) < 0.13:
				dark += 1
		if dark > image.get_width() * 0.85:
			dark_rows += 1
	return dark_rows > 0

static func _test_river(runner, world: ForestWorld) -> void:
	var river: ForestRiver = world.get_node("RiverBridgeAndCamp/TomateRiver")
	var frames := GroundAtlas.water_frames()
	var valid := river.get_child_count() == 3 and frames.size() == 4
	for phase in 4:
		valid = valid and river.water_material.get_shader_parameter("frame" + str(phase)) == frames[phase]
		valid = valid and not _contains_sheet_border(frames[phase].get_image())
	runner.verify(valid, "rio usa as quatro fases de água do pacote e duas margens sem magenta ou grade")
	var body: Polygon2D = river.get_child(0)
	var covered := true
	for y in range(0, int(WorldData.SIZE.y), 64):
		covered = covered and Geometry2D.is_point_in_polygon(Vector2(WorldData.river_x(y), y + 0.1), body.polygon)
	runner.verify(covered, "rio texturizado acompanha a geometria original até a ponte e as duas extremidades")

static func _at(terrain: ForestTerrain, point: Vector2) -> Array[Polygon2D]:
	var result: Array[Polygon2D] = []
	for patch: Polygon2D in terrain.get_node("Dirt").get_children():
		if Geometry2D.is_point_in_polygon(point, patch.polygon):
			result.append(patch)
	return result

static func _texture_point(patch: Polygon2D, point: Vector2) -> Vector2:
	var triangles := Geometry2D.triangulate_polygon(patch.polygon)
	for index in range(0, triangles.size(), 3):
		var a := triangles[index]
		var b := triangles[index + 1]
		var c := triangles[index + 2]
		var start := patch.polygon[a]
		var horizontal := patch.polygon[b] - start
		var vertical := patch.polygon[c] - start
		var local := point - start
		var denominator := horizontal.cross(vertical)
		if is_zero_approx(denominator):
			continue
		var u := local.cross(vertical) / denominator
		var v := horizontal.cross(local) / denominator
		if u >= -0.0001 and v >= -0.0001 and u + v <= 1.0001:
			return patch.uv[a] * (1.0 - u - v) + patch.uv[b] * u + patch.uv[c] * v
	return Vector2.INF
