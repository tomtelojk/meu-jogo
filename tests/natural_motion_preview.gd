extends SceneTree

# Deterministic temporal preview of the actual gait controller and tree shader.
# Physics/pathfinding behavior is covered separately by the native test suite.
# DISPLAY=:99 ./scripts/godot.sh --audio-driver Dummy --script res://tests/natural_motion_preview.gd -- --test
const OUTPUT := "/tmp/entre-folhas-tomate-motion-preview30"
const FRAME_COUNT := 240
const FRAME_STEP := 1.0 / 30.0
var actors: Array[Dictionary] = []
var wind_materials: Array[ShaderMaterial] = []

func _initialize() -> void:
	root.size = Vector2i(1280, 800)
	Engine.max_fps = 60
	var watchdog := Timer.new()
	watchdog.wait_time = 120.0
	watchdog.one_shot = true
	watchdog.autostart = true
	root.add_child(watchdog)
	watchdog.timeout.connect(func(): quit(1))
	call_deferred("_record")

func _record() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var navigator := AStarGrid2D.new()
	navigator.region = Rect2i(0, 0, 100, 80)
	navigator.cell_size = Vector2(32, 32)
	navigator.update()
	var fallback: SpriteFrames = TomateCharacterSheet.read().frames
	root.canvas_transform = Transform2D.IDENTITY
	var stage := Node2D.new()
	stage.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(stage)
	_panel(stage, Rect2(0, 0, 1280, 800), Color("17291f"))
	_label(stage, "Entre Folhas · sprites de tomate.zip", Vector2(24, 10), 25)
	_label(stage, "Passos acompanham o deslocamento · copas com vento contínuo", Vector2(24, 44), 15)
	for index in KingdomData.PEOPLE.size():
		var profile: Dictionary = KingdomData.PEOPLE[index]
		var left := 24.0 + (index % 2) * 640.0
		var baseline := 157.0 + floori(index / 2.0) * 103.0
		_panel(stage, Rect2(left, baseline - 80, 590, 92), Color("20392a") if index % 4 < 2 else Color("1c3326"))
		_line(stage, Vector2(left + 8, baseline + 3), Vector2(left + 582, baseline + 3), Color("4b6849"))
		var npc := ForestNPC.new()
		npc.setup(profile, fallback, navigator, 600.0)
		stage.add_child(npc)
		npc.set_physics_process(false)
		npc.name_label.visible = false
		npc.collision_mask = 0
		npc.active = true
		npc.sleeping = false
		npc.visible = true
		npc.wants_rest = false
		npc.waiting = 0.0
		var sign_x := 1.0 if index % 2 == 0 else -1.0
		var start := left + (36.0 if sign_x > 0 else 554.0)
		npc.position = Vector2(start, baseline)
		npc.current_schedule = {"points": ["forge"], "activity": "Caminhando", "loop": profile.id == "tomas"}
		npc.route = PackedVector2Array([Vector2(sign_x * 100000.0, baseline)])
		npc.path_index = 0
		var running: bool = profile.id == "tomas"
		var speed: float = profile.speed * (1.2 if running else 1.0)
		actors.append({"npc": npc, "left": left + 28.0, "right": left + 562.0, "sign": sign_x, "speed": speed, "running": running})
		_label(stage, String(profile.name) + (" · corrida" if profile.id == "tomas" else " · caminhada"), Vector2(left + 10, baseline - 80), 13)
	_label(stage, "Vento suave · troncos firmes", Vector2(24, 522), 20)
	_line(stage, Vector2(20, 766), Vector2(1260, 766), Color("4b6849"))
	var frames := TreeAtlas.read()
	for row in TreeAtlas.ROWS:
		var tree := AnimatedSprite2D.new()
		tree.sprite_frames = frames[row]
		tree.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		tree.centered = false
		tree.offset = -TreeAtlas.ANCHOR
		tree.position = Vector2(160 + row * 320, 766)
		tree.scale = Vector2.ONE * 160.0 / TreeAtlas.REFERENCE_SIZE
		var material := TreeAtlas.make_wind_material(row)
		tree.material = material
		wind_materials.append(material)
		stage.add_child(tree)
	for frame in 5:
		await process_frame
	# Animation time is explicit: encoding/render speed cannot alter cadence.
	for frame in FRAME_COUNT:
		for actor in actors:
			var npc: ForestNPC = actor.npc
			var direction: float = actor.sign
			var previous_x := npc.position.x
			var distance: float = actor.speed * FRAME_STEP if frame > 0 else 0.0
			npc.position.x = clampf(previous_x + direction * distance, actor.left, actor.right)
			if npc.position.x == actor.right:
				actor.sign = -1.0
			elif npc.position.x == actor.left:
				actor.sign = 1.0
			npc._animate_movement(Vector2(direction * actor.speed, 0), actor.running, absf(npc.position.x - previous_x))
		for material in wind_materials:
			material.set_shader_parameter("wind_time", frame * FRAME_STEP)
		await process_frame
		await RenderingServer.frame_post_draw
		if root.get_texture().get_image().save_jpg(OUTPUT + "/frame-%04d.jpg" % frame, 0.99) != OK:
			push_error("Falha ao salvar quadro da prévia temporal.")
			quit(1)
			return
	print("MOTION: %d quadros · %.1f segundos simulados · %s" % [FRAME_COUNT, FRAME_COUNT * FRAME_STEP, OUTPUT])
	quit()

func _panel(stage: Node2D, bounds: Rect2, color: Color) -> void:
	var panel := ColorRect.new()
	panel.position = bounds.position
	panel.size = bounds.size
	panel.color = color
	stage.add_child(panel)

func _label(stage: Node2D, value: String, at: Vector2, size: int) -> void:
	var label := Label.new()
	label.text = value
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("e6ebd0"))
	stage.add_child(label)

func _line(stage: Node2D, start: Vector2, end: Vector2, color: Color) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([start, end])
	line.width = 1.0
	line.default_color = color
	stage.add_child(line)
