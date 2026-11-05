extends SceneTree

# Graphical regressions: a stable trunk, a moving crown, continuous movement,
# and safe sampling at the edge of an atlas cell. Requires a display.
var failures := 0

func _initialize() -> void:
	var watchdog := Timer.new()
	watchdog.wait_time = 45.0
	watchdog.one_shot = true
	watchdog.autostart = true
	root.add_child(watchdog)
	watchdog.timeout.connect(func(): quit(1))
	call_deferred("_run")

func verify(condition: bool, label: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + label)
	if not condition:
		failures += 1

func _image(view: SubViewport) -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return view.get_texture().get_image()

func _centroid(image: Image, area: Rect2i) -> float:
	var mass := 0.0
	var moment := 0.0
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var alpha := image.get_pixel(x, y).a
			mass += alpha
			moment += x * alpha
	return moment / maxf(mass, 1.0)

func _opaque_point(image: Image, area: Rect2i) -> Vector2i:
	var result := Vector2i(-1, -1)
	var distance := INF
	var center := Vector2(area.get_center())
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var pixel := image.get_pixel(x, y)
			if pixel.a > 0.95 and minf(pixel.r, minf(pixel.g, pixel.b)) > 0.04:
				var candidate := Vector2i(x, y)
				var candidate_distance := Vector2(candidate).distance_squared_to(center)
				if candidate_distance < distance:
					distance = candidate_distance
					result = candidate
	return result

func _run() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(256, 256)
	view.disable_3d = true
	view.transparent_bg = true
	view.world_2d = World2D.new()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = TreeAtlas.read()[TreeAtlas.CALM_ROW]
	sprite.centered = false
	sprite.offset = -TreeAtlas.ANCHOR
	sprite.position = Vector2(128, 220)
	sprite.scale = Vector2.ONE * 160.0 / TreeAtlas.REFERENCE_SIZE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var material := TreeAtlas.make_wind_material(TreeAtlas.CALM_ROW)
	sprite.material = material
	view.add_child(sprite)
	material.set_shader_parameter("wind_time", 0.0)
	var first := await _image(view)
	first.save_png("/tmp/entre-folhas-tree-wind-start.png")
	var root_area := Rect2i(70, 197, 120, 25)
	var crown_area := Rect2i(20, 65, 220, 100)
	var clean_key := true
	var opaque_pixels := 0
	for y in first.get_height():
		for x in first.get_width():
			var pixel := first.get_pixel(x, y)
			if pixel.a > 0.1:
				opaque_pixels += 1
				if minf(pixel.r, pixel.b) - pixel.g > 0.15:
					clean_key = false
	verify(clean_key and opaque_pixels > 4000 and first.get_pixel(10, 10).a == 0.0,
		"fundo magenta e sombra roxa do PNG RGB ficam transparentes sem apagar a árvore")
	var root_pixels := first.get_region(root_area).get_data()
	var root_fixed := true
	var continuous := true
	var previous := _centroid(first, crown_area)
	var previous_pixels := first.get_region(crown_area).get_data()
	var changed_frames := 0
	for step in range(1, 49):
		material.set_shader_parameter("wind_time", step / 60.0)
		var current := await _image(view)
		root_fixed = root_fixed and current.get_region(root_area).get_data() == root_pixels
		var center := _centroid(current, crown_area)
		continuous = continuous and absf(center - previous) < 0.12
		var pixels := current.get_region(crown_area).get_data()
		if pixels != previous_pixels:
			changed_frames += 1
		previous_pixels = pixels
		previous = center
	var last := await _image(view)
	last.save_png("/tmp/entre-folhas-tree-wind-end.png")
	verify(root_fixed, "vento não move nenhum pixel do tronco inferior ou das raízes")
	verify(changed_frames >= 44 and continuous,
		"copa se move continuamente sem trocar a silhueta da árvore")
	var light := CanvasModulate.new()
	light.color = Color(0.4, 0.5, 0.7)
	view.add_child(light)
	var night := await _image(view)
	var point := _opaque_point(last, root_area)
	verify(point.x >= 0, "tronco fornecido mantém pixels opacos após a remoção do fundo")
	if point.x < 0:
		quit(1)
		return
	var day_pixel := last.get_pixelv(point)
	var night_pixel := night.get_pixelv(point)
	verify(day_pixel.a > 0.8 and night_pixel.r < day_pixel.r * 0.8 and night_pixel.b / maxf(day_pixel.b, 0.01) > night_pixel.r / maxf(day_pixel.r, 0.01),
		"vento preserva a iluminação noturna do cenário")
	sprite.modulate.a = 0.38
	var faded := await _image(view)
	verify(absf(faded.get_pixelv(point).a / maxf(night_pixel.a, 0.01) - 0.38) < 0.02,
		"árvore continua transparente quando o jogador passa por trás")
	view.queue_free()
	await process_frame
	await _test_atlas_edge()
	quit(1 if failures else 0)

func _test_atlas_edge() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(64, 64)
	view.disable_3d = true
	view.transparent_bg = true
	view.world_2d = World2D.new()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var image := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	# Blue is deliberately not a chroma-key color: a bad crop cannot hide a
	# neighboring cell leak by making that cell transparent.
	image.fill(Color.BLUE)
	image.fill_rect(Rect2i(0, 0, 32, 32), Color.GREEN)
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 0, 32, 32)
	sprite.centered = false
	sprite.position = Vector2(16, 16)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var material := TreeAtlas.make_wind_material(0)
	material.set_shader_parameter("frame_uv", Vector4(0.0, 0.0, 0.5, 1.0))
	material.set_shader_parameter("wind_time", 8.0)
	sprite.material = material
	view.add_child(sprite)
	var rendered := await _image(view)
	var clean := true
	for y in 64:
		for x in 64:
			var pixel := rendered.get_pixel(x, y)
			if pixel.a > 0.1 and pixel.r < 0.2 and pixel.b > 0.5 and pixel.g < 0.2:
				clean = false
	verify(clean, "deformação da copa nunca amostra o desenho vizinho do atlas")
	view.queue_free()
	await process_frame
