class_name TerrainTests
extends RefCounted

static func run(runner, world: ForestWorld) -> void:
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
			anchored = anchored and _texture_point(patch, point).distance_to(point) < 0.02
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
