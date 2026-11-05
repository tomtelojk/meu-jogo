extends SceneTree

# Run on a real or virtual display, like tests/capture.gd. A deliberately
# non-seamless gradient makes any regression at repeat boundaries measurable.
var failures := 0

func _initialize() -> void:
	var watchdog := Timer.new()
	watchdog.wait_time = 20.0
	watchdog.one_shot = true
	watchdog.autostart = true
	root.add_child(watchdog)
	watchdog.timeout.connect(func(): quit(1))
	call_deferred("_run")

func verify(condition: bool, label: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + label)
	if not condition:
		failures += 1

func _run() -> void:
	var image := Image.create(100, 100, false, Image.FORMAT_RGBA8)
	for y in 100:
		for x in 100:
			image.set_pixel(x, y, Color(float(x) / 99.0, float(y) / 99.0, 0.5))
	var view := SubViewport.new()
	view.size = Vector2i(302, 302)
	view.disable_3d = true
	view.world_2d = World2D.new()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var patch := Polygon2D.new()
	patch.polygon = PackedVector2Array([Vector2.ZERO, Vector2(340, 0), Vector2(340, 340), Vector2(0, 340)])
	patch.uv = patch.polygon
	patch.texture = ImageTexture.create_from_image(image)
	patch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	patch.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = ForestTerrain.DIRT_SHADER
	material.shader = shader
	patch.material = material
	view.add_child(patch)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var before := view.get_texture().get_image()
	var horizontal := true
	var vertical := true
	for seam in [50, 100, 150, 200, 250]:
		for offset in [17, 49, 50, 99, 100, 149, 199]:
			horizontal = horizontal and absf(before.get_pixel(seam - 1, offset).r - before.get_pixel(seam, offset).r) < 0.04
			vertical = vertical and absf(before.get_pixel(offset, seam - 1).g - before.get_pixel(offset, seam).g) < 0.04
	verify(horizontal and vertical, "shader elimina emendas horizontais, verticais e nos cantos")
	view.canvas_transform = Transform2D(0.0, Vector2(-17, -13))
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var after := view.get_texture().get_image()
	var anchored := true
	for point in [Vector2i(73, 82), Vector2i(100, 100), Vector2i(150, 200), Vector2i(210, 170)]:
		var a := before.get_pixelv(point)
		var b := after.get_pixelv(point - Vector2i(17, 13))
		anchored = anchored and absf(a.r - b.r) < 0.02 and absf(a.g - b.g) < 0.02
	verify(anchored, "textura permanece presa ao terreno quando a câmera se move")
	patch.queue_free()
	await process_frame
	view.canvas_transform = Transform2D.IDENTITY
	view.transparent_bg = true
	await _test_water(view)
	view.queue_free()
	await process_frame
	quit(1 if failures else 0)

func _test_water(view: SubViewport) -> void:
	var factory := ForestRiver.new()
	var frames := GroundAtlas.water_frames()
	var material := factory._material(frames, false)
	factory.free()
	var patch := Polygon2D.new()
	patch.polygon = PackedVector2Array([Vector2.ZERO, Vector2(302, 0), Vector2(302, 302), Vector2(0, 302)])
	var uv := PackedVector2Array()
	for point in patch.polygon:
		uv.append(point * GroundAtlas.UV_SCALE)
	patch.uv = uv
	patch.texture = frames[0]
	patch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	patch.material = material
	view.add_child(patch)
	material.set_shader_parameter("water_time", 0.0)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var first := view.get_texture().get_image()
	material.set_shader_parameter("water_time", 1.25)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var next := view.get_texture().get_image()
	var clean := true
	var changed := 0
	for y in range(2, 299, 8):
		for x in range(2, 299, 8):
			var a := first.get_pixel(x, y)
			var b := next.get_pixel(x, y)
			clean = clean and a.b > a.r * 1.3 and b.b > b.r * 1.3 and a.a > 0.99 and b.a > 0.99
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.02:
				changed += 1
	verify(clean and changed > 10, "água renderiza as fases novas sem fundo magenta, grade ou regiões vazias")
	patch.modulate = Color(0.5, 0.6, 0.7, 0.6)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var shaded := view.get_texture().get_image()
	var tint_preserved := true
	for point in [Vector2i(35, 43), Vector2i(100, 124), Vector2i(230, 210)]:
		var a := next.get_pixelv(point)
		var b := shaded.get_pixelv(point)
		tint_preserved = tint_preserved and absf(b.a - 0.6) < 0.02 and b.b < a.b * 0.8
	verify(tint_preserved, "shader da água preserva transparência e iluminação do CanvasItem")
	patch.queue_free()
	await process_frame
