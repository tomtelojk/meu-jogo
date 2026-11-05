extends SceneTree

var failures := 0

func _initialize() -> void:
	var watchdog := Timer.new()
	watchdog.wait_time = 30.0
	watchdog.one_shot = true
	watchdog.autostart = true
	root.add_child(watchdog)
	watchdog.timeout.connect(func(): quit(1))
	call_deferred("_run")

func verify(condition: bool, message: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + message)
	if not condition:
		failures += 1

func _run() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(512, 180)
	view.world_2d = World2D.new()
	view.disable_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var background := ColorRect.new()
	background.size = Vector2(view.size)
	background.color = Color("203b29")
	view.add_child(background)
	var frames: SpriteFrames = TomateCharacterSheet.read().frames
	var sprites: Array[AnimatedSprite2D] = []
	for index in 4:
		var actor := Node2D.new()
		actor.position = Vector2(64 + index * 128, 130)
		view.add_child(actor)
		var sprite := AnimatedSprite2D.new()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.sprite_frames = frames
		sprite.animation = "walk_" + CharacterSheet.DIRECTIONS[index]
		sprite.frame = 1
		sprite.material = TomateCharacterSheet.make_material()
		TomateCharacterSheet.apply_geometry(sprite)
		actor.add_child(sprite)
		sprites.append(sprite)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var normal := view.get_texture().get_image()
	normal.save_png("/tmp/entre-folhas-tomate-characters.png")
	var magenta := 0
	var visible := 0
	for y in normal.get_height():
		for x in normal.get_width():
			var color := normal.get_pixel(x, y)
			if color.r > 0.7 and color.b > 0.7 and color.g < 0.25:
				magenta += 1
			if _difference(color, background.color) > 0.12:
				visible += 1
	verify(magenta == 0, "fundo magenta desaparece nas quatro direções renderizadas")
	verify(visible > 2500, "personagens continuam visíveis após remover o fundo")
	for sprite in sprites:
		sprite.material = TomateCharacterSheet.make_material(Color(0.45, 0.8, 0.65))
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var tinted := view.get_texture().get_image()
	var head_unchanged := true
	var shirt_changed := 0
	for index in 4:
		var center := 64 + index * 128
		for y in range(65, 91):
			for x in range(center - 30, center + 31):
				head_unchanged = head_unchanged and _difference(normal.get_pixel(x, y), tinted.get_pixel(x, y)) < 0.005
		for y in range(97, 116):
			for x in range(center - 24, center + 25):
				if _difference(normal.get_pixel(x, y), tinted.get_pixel(x, y)) > 0.015:
					shirt_changed += 1
	verify(head_unchanged, "variação de roupa preserva chapéu e cabeça")
	verify(shirt_changed > 50, "roupa diferencia os moradores sem alterar os PNGs")
	view.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func _difference(a: Color, b: Color) -> float:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))
