class_name WorldData
extends RefCounted

const TILE: float = 64.0
const COLS: int = 50
const ROWS: int = 40
const SIZE := Vector2(3200, 2560)
const SPAWN := Vector2(1536, 1740.8)
const MOTHER := Vector2(1536, 1497.6)
const CAMP := Vector2(1376, 1817.6)
const SIGN := Vector2(1593.6, 1644.8)
const SOLID_LAYER := 1
const WATER_LAYER := 16 # NPCs stay on land; the player can swim.
const BRIDGE_RAIL_LAYER := 32
const RIVER_HALF_WIDTH := 80.0
const BRIDGE_HEIGHT := 52.0
const BRIDGE_RAMP := 64.0
# Center the deck on river_x(20*TILE), leaving a ramp on each dry bank.
const BRIDGE_RECT := Rect2(2235.3182264, 1248.0, 288.0, 64.0)
const SEEDS: Array[Dictionary] = [
	{"id": "flores", "name": "Semente da alegria", "place": "Clareira das flores", "position": Vector2(1152, 1664)},
	{"id": "outono", "name": "Semente da memória", "place": "Bosque dourado", "position": Vector2(800, 960)},
	{"id": "pedras", "name": "Semente do tempo", "place": "Pedras antigas", "position": Vector2(1664, 608)},
	{"id": "rio", "name": "Semente da calma", "place": "Margem do riacho", "position": Vector2(2688, 1152)},
	{"id": "jardim", "name": "Semente da esperança", "place": "Jardim esquecido", "position": Vector2(2016, 2048)},
]
const LANDMARKS: Array[Dictionary] = [
	{"id": "mother", "name": "Árvore-mãe", "position": MOTHER, "range": 100.0, "text": "Por muitas primaveras, esta árvore protegeu o bosque. Agora seus galhos descansam. Cinco pequenas sementes podem trazer suas folhas de volta."},
	{"id": "camp", "name": "Um lugar para descansar", "position": CAMP, "range": 85.0, "text": "Alguém deixou um caderno junto à barraca:\n\n“Não é preciso ter pressa. A floresta guarda suas sementes nas flores, no outono, nas pedras antigas, depois do riacho e no jardim ao sul.”"},
	{"id": "sign", "name": "Os caminhos do bosque", "position": SIGN, "range": 65.0, "text": "OESTE · Clareira das flores e Bosque dourado\nNORTE · Árvore-mãe e Pedras antigas\nLESTE · Riacho, depois da ponte\nSUDESTE · Jardim esquecido\n\nAbra o mapa com M para encontrar os brilhos dourados."},
]

static func paths() -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for points in [
		[Vector2(23, 38), Vector2(23, 32), Vector2(24, 28), Vector2(24, 25), Vector2(24, 20), Vector2(26, 15), Vector2(26, 9.5), Vector2(25, 4)],
		[Vector2(24, 24), Vector2(21, 24), Vector2(18, 26), Vector2(14, 25), Vector2(12.5, 21), Vector2(12.5, 15), Vector2(9, 11)],
		[Vector2(24, 20), Vector2(29, 19), Vector2(33, 21), Vector2(36, 20), Vector2(41, 20), Vector2(42, 18), Vector2(45, 15)],
		[Vector2(24, 28), Vector2(28, 29), Vector2(31.5, 32), Vector2(34, 35)],
	]:
		var path := PackedVector2Array()
		for point in points:
			path.append(point * TILE)
		result.append(path)
	result.append_array(KingdomData.paths())
	return result

static func path_distance(point: Vector2) -> float:
	var nearest := INF
	for path in paths():
		for i in range(1, path.size()):
			nearest = minf(nearest, point.distance_to(Geometry2D.get_closest_point_to_segment(point, path[i - 1], path[i])))
	return nearest

static func river_x(y: float) -> float:
	return (38.5 + sin(y / TILE / 4.0) * 1.2 + sin(y / TILE / 1.7) * 0.24) * TILE

static func is_water(point: Vector2) -> bool:
	return in_river(point) and not BRIDGE_RECT.has_point(point)

static func in_river(point: Vector2) -> bool:
	return absf(point.x - river_x(point.y)) < RIVER_HALF_WIDTH

static func bridge_rails() -> Array[Rect2]:
	return [Rect2(BRIDGE_RECT.position + Vector2(0, -6.4), Vector2(BRIDGE_RECT.size.x, 6.4)),
		Rect2(Vector2(BRIDGE_RECT.position.x, BRIDGE_RECT.end.y), Vector2(BRIDGE_RECT.size.x, 6.4))]

static func bridge_height(point: Vector2) -> float:
	if not BRIDGE_RECT.has_point(point):
		return 0.0
	return BRIDGE_HEIGHT * clampf(minf(point.x - BRIDGE_RECT.position.x, BRIDGE_RECT.end.x - point.x) / BRIDGE_RAMP, 0.0, 1.0)

static func circle_hits_rect(point: Vector2, radius: float, rect: Rect2) -> bool:
	# Match a round character against the actual wall, including the corners.
	var closest := point.clamp(rect.position, rect.end)
	return point.distance_squared_to(closest) < radius * radius

static func generate() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 271828
	var trees: Array[Dictionary] = []
	var decor: Array[Dictionary] = []
	var colliders: Array[Dictionary] = [{"position": MOTHER, "radius": 26.0}]
	var reserved: Array[Vector2] = [SPAWN, MOTHER, CAMP, SIGN]
	reserved.append_array(KingdomData.reserved_points())
	for seed_data in SEEDS:
		reserved.append(seed_data.position)
	for row in range(1, ROWS - 1):
		for col in range(1, COLS - 1):
			var point := Vector2(col + 0.15 + rng.randf() * 0.7, row + 0.15 + rng.randf() * 0.7) * TILE
			var distance_to_path := path_distance(point)
			var near_water := absf(point.x - river_x(point.y)) < TILE * 1.9
			var near_feature := false
			for spot in reserved:
				if point.distance_to(spot) < (155.0 if spot == MOTHER else 115.0):
					near_feature = true
					break
			var border := col < 3 or row < 3 or col > COLS - 4 or row > ROWS - 4
			if not near_water and not near_feature and distance_to_path > 75.0 and rng.randf() < (0.95 if border else 0.48):
				var kind := "green"
				if point.x < 18.0 * TILE and point.y < 22.0 * TILE:
					kind = "autumn" if rng.randf() < 0.9 else "green"
				elif rng.randf() < 0.07:
					kind = "bare"
				var size := 135.0 + rng.randf() * 48.0
				var tree := {"position": point, "size": size, "radius": size * 0.085, "kind": kind, "phase": rng.randi_range(0, 4)}
				trees.append(tree)
				colliders.append(tree)
			elif not near_water and not near_feature and distance_to_path > 48.0 and rng.randf() < 0.43:
				var bush := rng.randf() < 0.34
				var item := {"position": point, "kind": "bush" if bush else "decor", "variant": rng.randi_range(0, 2 if bush else 8), "size": 27.0 + rng.randf() * 28.0, "phase": rng.randi_range(0, 3)}
				decor.append(item)
	for index in SEEDS.size():
		for i in 9:
			var angle := i / 9.0 * TAU
			var radius := 62.0 + rng.randf() * 21.0
			decor.append({"position": SEEDS[index].position + Vector2(cos(angle) * radius, sin(angle) * radius * 0.64), "kind": "decor" if index == 2 else "bush", "variant": 6 + i % 3 if index == 2 else (1 if index == 1 else 2), "size": 38.0 + rng.randf() * 15.0, "phase": rng.randi_range(0, 3)})
	# Flowers, stones and low plants now belong to the supplied ground tiles.
	# Keep the RNG sequence above so saved tree positions remain deterministic,
	# but do not leave invisible colliders for the retired decorative sprites.
	decor.clear()
	var grid: Dictionary = {}
	for obstacle in colliders:
		var cell := Vector2i(floori(obstacle.position.x / TILE), floori(obstacle.position.y / TILE))
		if not grid.has(cell):
			grid[cell] = []
		grid[cell].append(obstacle)
	var solid_rects: Array[Rect2] = []
	for building in KingdomData.BUILDINGS:
		solid_rects.append(KingdomData.building_rect(building))
	return {"trees": trees, "decor": decor, "colliders": colliders, "collision_grid": grid, "solid_rects": solid_rects}

static func can_stand(point: Vector2, data: Dictionary, radius: float = 10.0, allow_swimming: bool = false) -> bool:
	if point.x < 38.4 or point.y < 38.4 or point.x > SIZE.x - 38.4 or point.y > SIZE.y - 38.4:
		return false
	for rect in data.get("solid_rects", []):
		if circle_hits_rect(point, radius, rect):
			return false
	if not allow_swimming:
		for rect in bridge_rails():
			if circle_hits_rect(point, radius, rect):
				return false
		for offset in [Vector2.ZERO, Vector2(radius, 0), Vector2(-radius, 0), Vector2(0, radius), Vector2(0, -radius)]:
			if is_water(point + offset):
				return false
	var candidates: Array = data.colliders
	if data.has("collision_grid"):
		candidates = []
		var cell := Vector2i(floori(point.x / TILE), floori(point.y / TILE))
		for y in range(-1, 2):
			for x in range(-1, 2):
				candidates.append_array(data.collision_grid.get(cell + Vector2i(x, y), []))
	for obstacle in candidates:
		if point.distance_to(obstacle.position) < radius + obstacle.radius:
			return false
	return true

static func location_name(point: Vector2) -> String:
	for seed_data in SEEDS:
		if point.distance_to(seed_data.position) < 270.0:
			return seed_data.place
	if point.distance_to(MOTHER) < 220.0:
		return "Clareira da árvore-mãe"
	if point.distance_to(CAMP) < 260.0:
		return "Acampamento do viajante"
	if absf(point.x - river_x(point.y)) < 270.0:
		return "Caminho do riacho"
	return "Bosque do vento"
