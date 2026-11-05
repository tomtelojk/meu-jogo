extends RefCounted

static func run(runner, game: ForestGame) -> void:
	_test_alignment(runner, game.world)
	await _test_motion(runner, game)

static func _head_center(atlas: AtlasTexture) -> float:
	# Independently measure the head's alpha-weighted centroid in the displayed
	# frame, rather than comparing against the importer's alignment calculation.
	var image := atlas.get_image()
	var weight := 0.0
	var weighted_x := 0.0
	for y in mini(60, image.get_height()):
		for x in image.get_width():
			var alpha := image.get_pixel(x, y).a
			if alpha >= 0.75:
				weight += alpha
				weighted_x += (x + atlas.margin.position.x) * alpha
	return weighted_x / maxf(weight, 1.0)

static func _sole(atlas: AtlasTexture) -> int:
	var image := atlas.get_image()
	for y in range(image.get_height() - 1, -1, -1):
		for x in image.get_width():
			if image.get_pixel(x, y).a >= 0.75:
				return y + roundi(atlas.margin.position.y)
	return -1

static func _test_alignment(runner, world: ForestWorld) -> void:
	for profile in KingdomData.PEOPLE:
		var library: SpriteFrames = world.npcs[profile.id].sprite.sprite_frames
		var stable := true
		for direction in CharacterSheet.DIRECTIONS:
			for mode in ["walk", "run"]:
				var centers: Array[float] = []
				var soles: Array[int] = []
				for frame in 4:
					var atlas := library.get_frame_texture(mode + "_" + direction, frame) as AtlasTexture
					centers.append(_head_center(atlas))
					soles.append(_sole(atlas))
				stable = stable and centers.max() - centers.min() <= 4.0 and soles.max() - soles.min() <= 1
		runner.verify(stable, "cabeça e pés mantêm a âncora ao caminhar e correr: " + profile.name)
	var original: SpriteFrames = CharacterSheet.read("res://assets/npcs/caio.png").frames
	var fixed: SpriteFrames = world.npcs.caio.sprite.sprite_frames
	var old_centers: Array[float] = []
	var new_centers: Array[float] = []
	for frame in 4:
		old_centers.append(_head_center(original.get_frame_texture("walk_down", frame)))
		new_centers.append(_head_center(fixed.get_frame_texture("walk_down", frame)))
	runner.verify(old_centers.max() - old_centers.min() > 30.0 and new_centers.max() - new_centers.min() <= 2.0,
		"regressão reproduz e elimina o salto lateral de Caio nos PNGs reais")
	var path := "/tmp/entre-folhas-npc-original-override.png"
	var copied := DirAccess.copy_absolute(ProjectSettings.globalize_path("res://assets/npcs/caio.png"), path) == OK
	var override := CharacterSheet.read(path, true) if copied else {}
	var same_layout := not override.is_empty()
	if same_layout:
		for frame in 4:
			var bundled := fixed.get_frame_texture("walk_down", frame) as AtlasTexture
			var imported := override.frames.get_frame_texture("walk_down", frame) as AtlasTexture
			same_layout = same_layout and bundled.region == imported.region and bundled.margin == imported.margin
	runner.verify(same_layout, "PNG original importado do disco recebe a mesma correção do NPC incluído")
	DirAccess.remove_absolute(path)

static func _test_motion(runner, game: ForestGame) -> void:
	var npc := ForestNPC.new()
	game.world.entities.add_child(npc)
	npc.setup(KingdomData.person("bento"), game.player.default_frames, game.world.navigator, 600)
	npc.set_physics_process(false)
	npc.sprite.play("walk_down")
	npc.sprite.set_frame_and_progress(2, 0.7)
	npc._animate_movement(Vector2.RIGHT * 60.0, false)
	runner.verify(npc.sprite.animation == "walk_right" and npc.sprite.frame == 2 and is_equal_approx(npc.sprite.frame_progress, 0.7),
		"virar durante a caminhada preserva o quadro e o progresso do passo")
	npc._animate_movement(Vector2.LEFT * 60.0, true)
	runner.verify(npc.sprite.animation == "run_left" and npc.sprite.frame == 2 and is_equal_approx(npc.sprite.frame_progress, 0.7),
		"trocar entre caminhada e corrida preserva a fase das pernas")
	npc.facing = "down"
	var stable_facing := true
	for tick in 20:
		npc._animate_movement(Vector2(40.01 if tick % 2 == 0 else 40.0, 40.0 if tick % 2 == 0 else 40.01), false)
		stable_facing = stable_facing and npc.facing == "down"
	runner.verify(stable_facing, "pequenas correções perto da diagonal não alternam a direção do sprite")
	var origin := Vector2(-10000, -10000)
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, 16, 16)
	grid.cell_size = Vector2(32, 32)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ALWAYS
	grid.update()
	npc.route = grid.get_point_path(Vector2i(1, 1), Vector2i(8, 8))
	for index in npc.route.size():
		npc.route[index] += origin
	npc.position = npc.route[0]
	npc.path_index = 1
	npc.collision_mask = 0
	npc.active = true
	npc.sleeping = false
	npc.wants_rest = false
	npc.waiting = 0.0
	npc.current_schedule = {"points": ["forge"], "activity": "Teste", "loop": false}
	npc.set_physics_process(true)
	var start := npc.position
	var frames_seen: Dictionary = {}
	var facing_stayed := true
	for tick in 90:
		await runner.frames(1)
		frames_seen[npc.sprite.frame] = true
		facing_stayed = facing_stayed and npc.facing == "down"
	runner.verify(npc.position.distance_to(start) > 60 and facing_stayed and frames_seen.size() == 4,
		"rota diagonal real do AStar avança sem oscilação e completa os quatro quadros")
	npc.position = origin
	npc.route = PackedVector2Array([origin + Vector2(200, 0)])
	npc.path_index = 0
	npc.collision_mask = 1
	var wall := StaticBody2D.new()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(30, 100)
	collider.shape = shape
	wall.position = origin + Vector2(35, 0)
	wall.add_child(collider)
	game.world.add_child(wall)
	await runner.frames(40)
	runner.verify(npc.get_real_velocity().length_squared() <= 1.0 and String(npc.sprite.animation).begins_with("idle_"),
		"colisão real interrompe os passos quando o NPC fica bloqueado")
	npc.queue_free()
	wall.queue_free()
	await runner.frames(1)
