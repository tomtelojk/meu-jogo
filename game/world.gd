class_name ForestWorld
extends Node2D

const DECOR_FRAMES := [Vector2(0, 78), Vector2(78, 68), Vector2(146, 87), Vector2(233, 87), Vector2(320, 101), Vector2(421, 97), Vector2(518, 73), Vector2(591, 79), Vector2(670, 92)]
const BUSH_SWAY_FPS: float = 1.6

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

func _ready() -> void:
	data = WorldData.generate()
	entities = $Entities
	player = $Entities/Player
	var tree_frames := TreeAtlas.read()
	for row in TreeAtlas.ROWS:
		libraries["tree" + str(row)] = tree_frames[row]
		tree_materials.append(TreeAtlas.make_wind_material(row))
	var bush_texture: Texture2D = load("res://assets/environment/arbustos_vento.png")
	for variant in 3:
		libraries["bush" + str(variant)] = _frames(bush_texture, 4, 1024.0 / 12.0, 102.0, BUSH_SWAY_FPS, variant * 4)
	_build_ground()
	var art := Node2D.new()
	art.name = "RiverBridgeAndCamp"
	art.set_script(load("res://game/world_art.gd"))
	add_child(art)
	move_child(art, get_child_count() - 2)
	for tree in data.trees:
		_add_tree(tree)
	_add_tree({"position": WorldData.MOTHER, "size": 255.0, "radius": 26.0, "kind": "bare", "phase": 0}, true)
	for item in data.decor:
		_add_decor(item)
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
	for rect in data.solid_rects:
		var shape := CollisionShape2D.new()
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

func _frames(texture: Texture2D, count: int, width: float, height: float, fps: float, offset: int = 0) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", fps)
	# Return through the original frames so the crown never snaps from one
	# extreme to the other. Hold the ends briefly for a softer breeze.
	var sequence: Array[int] = []
	for i in count:
		sequence.append(i)
	for i in range(count - 2, 0, -1):
		sequence.append(i)
	for i in sequence:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2((i + offset) * width, 0, width, height)
		frames.add_frame("default", atlas, 1.4 if i == 0 or i == count - 1 else 1.0)
	return frames

func _build_ground() -> void:
	var ground_texture: Texture2D = load("res://assets/environment/chao_tiles_7x6_128px.png")
	var image := ground_texture.get_image()
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(104, 104)
	for variant in 3:
		var source := TileSetAtlasSource.new()
		source.texture = ImageTexture.create_from_image(image.get_region(Rect2i([0, 2, 3][variant] * 128 + 12, 12, 104, 104)))
		source.texture_region_size = Vector2i(104, 104)
		source.create_tile(Vector2i.ZERO)
		tiles.add_source(source, variant)
	var ground := TileMapLayer.new()
	ground.name = "GrassTiles"
	ground.tile_set = tiles
	ground.scale = Vector2.ONE * (64.0 / 104.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 442
	for y in WorldData.ROWS:
		for x in WorldData.COLS:
			var variant := 1 if rng.randf() < 0.13 else (0 if rng.randf() < 0.6 else 2)
			ground.set_cell(Vector2i(x, y), variant, Vector2i.ZERO)
	add_child(ground)
	move_child(ground, 0)
	var paths_node := ForestTerrain.new()
	paths_node.name = "ForestPaths"
	paths_node.build(image)
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
	var row := TreeAtlas.CALM_ROW if mother else TreeAtlas.variant(tree.position)
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

func _add_decor(item: Dictionary) -> void:
	var root: Node2D = StaticBody2D.new() if item.kind == "decor" and item.variant >= 6 else Node2D.new()
	root.position = item.position
	if root is StaticBody2D:
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = item.size * 0.24
		shape.shape = circle
		root.add_child(shape)
	if item.kind == "bush":
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = libraries["bush" + str(item.variant)]
		sprite.scale = Vector2.ONE * item.size / (1024.0 / 12.0)
		sprite.position.y = -item.size * 0.35
		sprite.play()
		sprite.set_frame_and_progress(int(item.phase), fposmod(item.position.x * 0.017 + item.position.y * 0.011, 1.0))
		sprite.speed_scale = 0.9 + fposmod(item.position.x * 0.009 + item.position.y * 0.013, 0.14)
		root.add_child(sprite)
	else:
		var sprite := Sprite2D.new()
		sprite.texture = load("res://assets/environment/decoracao_chao.png")
		var region: Vector2 = DECOR_FRAMES[item.variant]
		sprite.region_enabled = true
		sprite.region_rect = Rect2(region.x, 0, region.y, 82)
		sprite.scale = Vector2.ONE * item.size / region.y
		sprite.position.y = -item.size * 82.0 / region.y / 2.0 + 5
		root.add_child(sprite)
	entities.add_child(root)

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
	var cuts: Array[float] = []
	for y in range(0, int(WorldData.SIZE.y) + 1, 32):
		cuts.append(float(y))
	cuts.append(19.45 * WorldData.TILE)
	cuts.append(20.55 * WorldData.TILE)
	cuts.sort()
	for i in range(1, cuts.size()):
		var a := cuts[i - 1]
		var b := cuts[i]
		if b <= a or (a >= 19.45 * WorldData.TILE and b <= 20.55 * WorldData.TILE):
			continue
		var polygon := CollisionPolygon2D.new()
		polygon.polygon = PackedVector2Array([Vector2(WorldData.river_x(a) - 80, a), Vector2(WorldData.river_x(a) + 80, a), Vector2(WorldData.river_x(b) + 80, b), Vector2(WorldData.river_x(b) - 80, b)])
		water.add_child(polygon)
	add_child(water)

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
	mother_material.set_shader_parameter("vitality", 1.0 if complete else 0.15)
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
	for tree in trees:
		var point: Vector2 = tree.body.position
		var behind: bool = player.position.y < point.y - 8 and player.position.y > point.y - tree.size and absf(player.position.x - point.x) < tree.size * 0.42
		tree.sprite.modulate.a = 0.38 if behind else 1.0
	var markers: Array[Dictionary] = []
	for npc in npcs.values():
		if not npc.sleeping:
			markers.append({"position": npc.position, "realm": npc.definition.realm})
	data["npc_markers"] = markers
