class_name ForestWorld
extends Node2D

var data: Dictionary
var entities: Node2D
var mother_sprite: AnimatedSprite2D
var mother_label: Label
var mother_material: ShaderMaterial
var tree_materials: Array[ShaderMaterial] = []
var trees: Array[Dictionary] = []
var seeds: Dictionary = {}
var libraries: Dictionary = {}
var player: CharacterBody2D
var fade_timer: float = 0.0
var clock: WorldClock
var navigator: AStarGrid2D
var npcs: Dictionary = {}
var daylight: CanvasModulate
var hybrid_rendering := false

func _ready() -> void:
	data = WorldData.generate()
	entities = $Entities
	player = $Entities/Player
	var tree_frames := TreeAtlas.read()
	for row in TreeAtlas.ROWS:
		libraries["tree" + str(row)] = tree_frames[row]
		tree_materials.append(TreeAtlas.make_wind_material(row))
	_build_ground()
	var art := Node2D.new()
	art.name = "RiverBridgeAndCamp"
	art.set_script(load("res://game/world_art.gd"))
	add_child(art)
	move_child(art, get_child_count() - 2)
	for tree in data.trees:
		_add_tree(tree)
	_add_tree({"position": WorldData.MOTHER, "size": 255.0, "radius": 26.0, "kind": "bare", "phase": 0}, true)
	for seed_data in WorldData.SEEDS:
		var seed_node := ForestSeed.new()
		seed_node.setup(seed_data)
		entities.add_child(seed_node)
		seeds[seed_data.id] = seed_node
	for landmark in WorldData.LANDMARKS:
		var area := _interaction_area(landmark.position, landmark.range)
		area.set_meta("interaction", landmark.merged({"kind": "landmark"}))
		area.name = "Interaction_" + landmark.id
		add_child(area)
	_build_water_collisions()
	_build_bridge_collisions()
	_build_boundaries()
	_build_settlements()
	_build_population()

func _build_settlements() -> void:
	var art := Node2D.new()
	art.name = "TwoKingdoms"
	art.set_script(load("res://game/settlements.gd"))
	add_child(art)
	move_child(art, 3)
	var buildings := StaticBody2D.new()
	buildings.name = "BuildingCollisions"
	buildings.collision_layer = WorldData.SOLID_LAYER
	buildings.collision_mask = 0
	for index in data.solid_rects.size():
		var rect:Rect2 = data.solid_rects[index]
		var shape := CollisionShape2D.new()
		shape.name = "Footprint_" + str(index)
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		shape.position = rect.get_center()
		buildings.add_child(shape)
	add_child(buildings)
	daylight = CanvasModulate.new()
	daylight.name = "DayNightLight"
	add_child(daylight)

func _build_population() -> void:
	navigator = AStarGrid2D.new()
	navigator.region = Rect2i(0, 0, 100, 80)
	navigator.cell_size = Vector2(32, 32)
	navigator.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigator.update()
	for y in 80:
		for x in 100:
			navigator.set_point_solid(Vector2i(x, y), not WorldData.can_stand(Vector2(x, y) * 32, data, 11.0))
	clock = WorldClock.new()
	clock.name = "Clock"
	add_child(clock)
	for profile in KingdomData.PEOPLE:
		var npc := ForestNPC.new()
		npc.setup(profile, player.default_frames, navigator, clock.minute)
		entities.add_child(npc)
		npcs[profile.id] = npc
	clock.minute_changed.connect(_update_population)
	_update_population()

func _update_population() -> void:
	for npc in npcs.values():
		npc.apply_schedule(clock.minute)
	var hour := clock.minute / 60.0
	var color := Color(0.98, 0.98, 0.94)
	if hour < 5 or hour >= 21:
		color = Color(0.39, 0.49, 0.67)
	elif hour < 7:
		color = Color(0.56, 0.58, 0.64).lerp(Color(0.98, 0.98, 0.94), (hour - 5) / 2)
	elif hour >= 17:
		color = Color(0.98, 0.92, 0.81).lerp(Color(0.39, 0.49, 0.67), (hour - 17) / 4)
	daylight.color = color

func set_population_active(value: bool) -> void:
	clock.active = value
	for npc in npcs.values():
		npc.active = value

func reset_population() -> void:
	clock.set_time(8.5, 1)
	for npc in npcs.values():
		npc.apply_schedule(clock.minute, true)

func restore_population(saved: Dictionary) -> void:
	for id in npcs:
		var npc: ForestNPC = npcs[id]
		var value = saved.get(id, {})
		if value is Dictionary and (value.get("x") is float or value.get("x") is int) and (value.get("y") is float or value.get("y") is int):
			var point := Vector2(value.x, value.y)
			if is_finite(point.x) and is_finite(point.y) and WorldData.can_stand(point, data):
				npc.position = point
				npc.refresh_presence()
				npc.plan_route()

func population_data() -> Dictionary:
	var result := {}
	for id in npcs:
		result[id] = {"x": npcs[id].position.x, "y": npcs[id].position.y}
	return result

func _build_ground() -> void:
	var ground := TileMapLayer.new()
	ground.name = "GrassTiles"
	ground.tile_set = GroundAtlas.create_grass_tiles()
	ground.scale = Vector2.ONE * (float(WorldData.TILE) / GroundAtlas.TILE_PIXELS)
	for y in WorldData.ROWS:
		for x in WorldData.COLS:
			ground.set_cell(Vector2i(x, y), GroundAtlas.grass_variant(x, y), Vector2i.ZERO)
	add_child(ground)
	move_child(ground, 0)
	var paths_node := ForestTerrain.new()
	paths_node.name = "ForestPaths"
	paths_node.build()
	add_child(paths_node)
	move_child(paths_node, 1)

func _add_tree(tree: Dictionary, mother: bool = false) -> void:
	var body := StaticBody2D.new()
	body.position = tree.position
	body.name = "MotherTree" if mother else "Tree"
	var shadow := Polygon2D.new()
	var shadow_points := PackedVector2Array()
	for i in 20:
		var angle := i / 20.0 * TAU
		shadow_points.append(Vector2(9 + cos(angle) * tree.size * 0.33, 5 + sin(angle) * tree.size * 0.115))
	shadow.polygon = shadow_points
	shadow.color = Color(0.1, 0.17, 0.14, 0.26)
	body.add_child(shadow)
	var sprite := AnimatedSprite2D.new()
	var row := TreeAtlas.variant(tree.position)
	if mother or tree.get("kind", "green") == "bare":
		row = TreeAtlas.DRY_ROW
	elif row == TreeAtlas.DRY_ROW:
		row = TreeAtlas.CALM_ROW
	sprite.sprite_frames = libraries["tree" + str(row)]
	sprite.set_meta("atlas_row", row)
	sprite.centered = false
	sprite.offset = -TreeAtlas.ANCHOR
	sprite.position.y = 3.0
	sprite.scale = Vector2.ONE * tree.size / TreeAtlas.REFERENCE_SIZE
	# Foliage moves by fractions of a texel. Local linear sampling avoids the
	# entire crown snapping one pixel when a nearest-neighbor sample changes.
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.material = tree_materials[row]
	sprite.stop()
	body.add_child(sprite)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = tree.radius
	shape.shape = circle
	body.add_child(shape)
	entities.add_child(body)
	trees.append({"body": body, "sprite": sprite, "size": tree.size})
	if mother:
		mother_sprite = sprite
		mother_material = TreeAtlas.make_wind_material(row, 0.15)
		mother_sprite.material = mother_material
		mother_label = Label.new()
		mother_label.text = "Á R V O R E - M Ã E"
		mother_label.position = Vector2(-100, 24)
		mother_label.size = Vector2(200, 28)
		mother_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mother_label.add_theme_font_size_override("font_size", 10)
		mother_label.add_theme_color_override("font_color", Color("efe6c1"))
		mother_label.add_theme_color_override("font_shadow_color", Color("253727"))
		mother_label.add_theme_constant_override("shadow_offset_y", 2)
		body.add_child(mother_label)

func _interaction_area(point: Vector2, radius: float) -> Area2D:
	var area := Area2D.new()
	area.position = point
	area.collision_layer = 2
	area.collision_mask = 0
	area.monitoring = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	area.add_child(shape)
	return area

func _build_water_collisions() -> void:
	var water := StaticBody2D.new()
	water.name = "StreamCollision"
	water.collision_layer = WorldData.WATER_LAYER
	water.collision_mask = 0
	var cuts: Array[float] = []
	for y in range(0, int(WorldData.SIZE.y) + 1, 32):
		cuts.append(float(y))
	cuts.append(WorldData.BRIDGE_RECT.position.y)
	cuts.append(WorldData.BRIDGE_RECT.end.y)
	cuts.sort()
	for i in range(1, cuts.size()):
		var a := cuts[i - 1]
		var b := cuts[i]
		if b <= a or (a >= WorldData.BRIDGE_RECT.position.y and b <= WorldData.BRIDGE_RECT.end.y):
			continue
		var polygon := CollisionPolygon2D.new()
		polygon.polygon = PackedVector2Array([Vector2(WorldData.river_x(a) - 80, a), Vector2(WorldData.river_x(a) + 80, a), Vector2(WorldData.river_x(b) + 80, b), Vector2(WorldData.river_x(b) - 80, b)])
		water.add_child(polygon)
	add_child(water)

func _build_bridge_collisions() -> void:
	var rails := StaticBody2D.new()
	rails.name = "BridgeRails"
	rails.collision_layer = WorldData.BRIDGE_RAIL_LAYER
	rails.collision_mask = 0
	for rect in WorldData.bridge_rails():
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		shape.position = rect.get_center()
		rails.add_child(shape)
	add_child(rails)

func _build_boundaries() -> void:
	var boundary := StaticBody2D.new()
	boundary.name = "WorldBoundary"
	for rect in [Rect2(-100, -100, 3300, 128.4), Rect2(-100, 2531.6, 3400, 128.4), Rect2(-100, 0, 128.4, 2560), Rect2(3171.6, 0, 128.4, 2560)]:
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		shape.position = rect.get_center()
		boundary.add_child(shape)
	add_child(boundary)

func apply_progress(collected: Dictionary, complete: bool) -> void:
	for id in seeds:
		if collected.has(id):
			seeds[id].gather()
		else:
			seeds[id].gathered = false
			seeds[id].show()
			seeds[id].set_deferred("monitorable", true)
	var row := TreeAtlas.CALM_ROW if complete else TreeAtlas.DRY_ROW
	mother_sprite.sprite_frames = libraries["tree" + str(row)]
	mother_sprite.set_meta("atlas_row", row)
	mother_material = TreeAtlas.make_wind_material(row, 1.0 if complete else 0.15)
	mother_sprite.material = mother_material
	mother_label.text = "O BOSQUE RENASCE" if complete else "Á R V O R E - M Ã E"

func burst(point: Vector2, amount: int = 30) -> void:
	var particles := CPUParticles2D.new()
	particles.position = point
	particles.one_shot = true
	particles.amount = amount
	particles.lifetime = 1.3
	particles.explosiveness = 1.0
	particles.direction = Vector2.UP
	particles.spread = 180
	particles.gravity = Vector2(0, 15)
	particles.initial_velocity_min = 15
	particles.initial_velocity_max = 75
	particles.scale_amount_min = 2
	particles.scale_amount_max = 3
	particles.color = Color("f2dfa1")
	particles.finished.connect(particles.queue_free)
	entities.add_child(particles)
	particles.emitting = true

func _process(delta: float) -> void:
	fade_timer += delta
	if fade_timer < 0.1:
		return
	fade_timer = 0.0
	if not hybrid_rendering:
		for tree in trees:
			var point: Vector2 = tree.body.position
			var behind: bool = player.position.y < point.y - 8 and player.position.y > point.y - tree.size and absf(player.position.x - point.x) < tree.size * 0.42
			tree.sprite.modulate.a = 0.38 if behind else 1.0
	var markers: Array[Dictionary] = []
	for npc in npcs.values():
		if not npc.sleeping:
			markers.append({"position": npc.position, "realm": npc.definition.realm})
	data["npc_markers"] = markers
