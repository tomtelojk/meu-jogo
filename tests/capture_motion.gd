extends SceneTree

# Graphical inspection of the actual NPC walking frames. Run after imports:
# DISPLAY=:99 ./scripts/godot.sh --audio-driver Dummy --script res://tests/capture_motion.gd
# The source PNGs remain untouched; CharacterSheet supplies the runtime atlases.
const OUTPUT := "/tmp/entre-folhas-npc-motion.png"
const ROW_TOP := 70.0
const ROW_HEIGHT := 88.0
const GROUP_LEFT := 170.0
const GROUP_WIDTH := 274.0
const FRAME_STEP := 64.0
const DIRECTION_LABELS := ["Frente", "Costas", "Direita", "Esquerda"]

func _initialize() -> void:
	root.size = Vector2i(1280, 800)
	var watchdog := Timer.new()
	watchdog.wait_time = 45.0
	watchdog.one_shot = true
	watchdog.autostart = true
	root.add_child(watchdog)
	watchdog.timeout.connect(func(): quit(1))
	call_deferred("_capture")

func _capture() -> void:
	var stage := Node2D.new()
	stage.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(stage)
	_panel(stage, Rect2(0, 0, 1280, 800), Color("14251f"))
	_label(stage, "NPCs · caminhada", Vector2(12, 8), Vector2(300, 25), 19)
	_label(stage, "8 NPCs · 128 poses", Vector2(12, 36), Vector2(152, 22), 12)
	for direction in 4:
		var left := GROUP_LEFT + direction * GROUP_WIDTH
		_label(stage, DIRECTION_LABELS[direction], Vector2(left, 9), Vector2(260, 24), 16, true)
		for frame in 4:
			_label(stage, str(frame + 1), Vector2(left + 4 + frame * FRAME_STEP, 41), Vector2(60, 20), 11, true)
	var count := 0
	for profile in KingdomData.PEOPLE:
		var path := "res://assets/npcs/" + String(profile.id) + ".png"
		var sheet: Dictionary = CharacterSheet.read(path, true)
		if sheet.is_empty():
			_fail("Prancha não carregada: " + path)
			return
		var frames: SpriteFrames = sheet.frames
		var cell: Vector2 = sheet.cell
		var top := ROW_TOP + count * ROW_HEIGHT
		var baseline := top + 76.0
		_panel(stage, Rect2(5, top, 1268, ROW_HEIGHT - 2), Color("1c3329") if count % 2 == 0 else Color("182d25"))
		_label(stage, String(profile.name), Vector2(12, top + 24), Vector2(152, 24), 15)
		_label(stage, "%s · %.0f × %.0f" % [profile.id, cell.x, cell.y], Vector2(12, top + 49), Vector2(152, 20), 10)
		for direction in 4:
			var animation: String = "walk_" + CharacterSheet.DIRECTIONS[direction]
			if not frames.has_animation(animation) or frames.get_frame_count(animation) != 4:
				_fail("Animação incompleta: %s / %s" % [profile.id, animation])
				return
			var left := GROUP_LEFT + direction * GROUP_WIDTH
			_line(stage, Vector2(left + 3, baseline), Vector2(left + 259, baseline), Color("628765"))
			for frame in 4:
				var x := left + 34 + frame * FRAME_STEP
				_line(stage, Vector2(x, top + 3), Vector2(x, baseline + 5), Color(0.6, 0.75, 0.6, 0.12))
				var texture := frames.get_frame_texture(animation, frame)
				if texture == null:
					_fail("Quadro vazio: %s / %s / %d" % [profile.id, animation, frame])
					return
				var sprite := Sprite2D.new()
				sprite.texture = texture
				# Keep this placement identical to ForestNPC.load_original_sprite.
				sprite.scale = Vector2.ONE * 72.0 / cell.y
				sprite.position = Vector2(x, baseline) + Vector2(0, -31)
				stage.add_child(sprite)
		count += 1
	if count != 8:
		_fail("Esperados oito NPCs; encontrados %d." % count)
		return
	_label(stage, "Guia horizontal = posição do NPC no chão · guias verticais = centro fixo de cada quadro · escala de jogo", Vector2(12, 780), Vector2(1240, 20), 11)
	for frame in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	var capture := root.get_texture().get_image()
	if capture == null or capture.is_empty() or capture.get_size() != Vector2i(1280, 800):
		_fail("Captura vazia ou com tamanho incorreto.")
		return
	if capture.save_png(OUTPUT) != OK:
		_fail("Falha ao salvar " + OUTPUT)
		return
	print("CAPTURE: " + OUTPUT + " · 8 NPCs × 4 direções × 4 quadros = 128 quadros")
	quit()

func _panel(stage: Node2D, bounds: Rect2, color: Color) -> void:
	var panel := ColorRect.new()
	panel.position = bounds.position
	panel.size = bounds.size
	panel.color = color
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(panel)

func _label(stage: Node2D, value: String, at: Vector2, bounds: Vector2, size: int, centered: bool = false) -> void:
	var label := Label.new()
	label.text = value
	label.position = at
	label.size = bounds
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("e4ecd5"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage.add_child(label)

func _line(stage: Node2D, start: Vector2, end: Vector2, color: Color) -> void:
	var guide := Line2D.new()
	guide.points = PackedVector2Array([start, end])
	guide.default_color = color
	guide.width = 1.0
	stage.add_child(guide)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
