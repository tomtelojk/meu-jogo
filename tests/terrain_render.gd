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
	view.queue_free()
	await process_frame
	quit(1 if failures else 0)
