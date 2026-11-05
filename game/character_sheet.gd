class_name CharacterSheet
extends RefCounted

const DIRECTIONS := ["down", "up", "right", "left"]

static func read(path: String, stabilize_frames: bool = false) -> Dictionary:
	var image: Image
	if path.begins_with("res://"):
		if not ResourceLoader.exists(path):
			return {}
		var bundled_texture := load(path) as Texture2D
		if bundled_texture == null:
			return {}
		image = bundled_texture.get_image()
	else:
		if not FileAccess.file_exists(path):
			return {}
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null or file.get_length() > 12 * 1024 * 1024:
			return {}
		file.close()
		image = Image.load_from_file(path)
	if image == null or image.is_empty() or image.get_width() < 250 or image.get_height() < 400:
		return {}
	var ratio := float(image.get_width()) / image.get_height()
	if ratio < 0.45 or ratio > 1.1:
		return {}
	var texture := ImageTexture.create_from_image(image)
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	# Generated sheets can have uneven outer padding and spacing. Integer source
	# rectangles prevent subpixel sampling; NPCs additionally align the artwork
	# inside a fixed canvas without resampling or changing the original pixels.
	var cell := Vector2(ceilf(image.get_width() / 5.0), ceilf(image.get_height() / 8.0))
	var mask: BitMap
	if stabilize_frames and image.detect_alpha() != Image.ALPHA_NONE:
		mask = BitMap.new()
		mask.create_from_image_alpha(image, 0.5)
	for row in 4:
		for mode in ["idle", "walk", "run"]:
			var animation: String = mode + "_" + DIRECTIONS[row]
			frames.add_animation(animation)
			frames.set_animation_speed(animation, 12.0 if mode == "run" else 8.0)
			var source_row := row + (4 if mode == "run" else 0)
			for col in ([0] if mode == "idle" else [1, 2, 3, 4]):
				var atlas := AtlasTexture.new()
				atlas.atlas = texture
				var left := roundi(col * image.get_width() / 5.0)
				var top := roundi(source_row * image.get_height() / 8.0)
				var right := roundi((col + 1) * image.get_width() / 5.0)
				var bottom := roundi((source_row + 1) * image.get_height() / 8.0)
				var source := Rect2i(left, top, right - left, bottom - top)
				atlas.region = Rect2(source)
				if mask != null:
					_align_frame(atlas, mask, source, Vector2i(cell))
				frames.add_frame(animation, atlas)
	return {"frames": frames, "cell": cell}

static func _content_bounds(mask: BitMap, area: Rect2i) -> Rect2i:
	# Contour extraction runs in native code. Ignore tiny detached alpha specks
	# instead of treating almost transparent backdrop noise as character pixels.
	var largest := Rect2()
	for polygon in mask.opaque_to_polygons(area, 1.0):
		if polygon.is_empty():
			continue
		var bounds := Rect2(polygon[0], Vector2.ZERO)
		for point in polygon:
			bounds = bounds.expand(point)
		if bounds.get_area() > largest.get_area():
			largest = bounds
	return Rect2i(largest)

static func _head_center_x(mask: BitMap, area: Rect2i) -> float:
	var largest_area := 0.0
	var center_x := area.size.x / 2.0
	for polygon in mask.opaque_to_polygons(area, 1.0):
		var signed_area := 0.0
		var moment_x := 0.0
		for index in polygon.size():
			var a: Vector2 = polygon[index]
			var b: Vector2 = polygon[(index + 1) % polygon.size()]
			var cross := a.cross(b)
			signed_area += cross
			moment_x += (a.x + b.x) * cross
		if absf(signed_area) > largest_area:
			largest_area = absf(signed_area)
			center_x = moment_x / (3.0 * signed_area)
	return area.position.x + center_x

static func _align_frame(atlas: AtlasTexture, mask: BitMap, source: Rect2i, canvas: Vector2i) -> void:
	var body := _content_bounds(mask, source)
	if body.size == Vector2i.ZERO:
		return
	# The top third follows the head rather than a swinging arm, cape or boot.
	# All frames share this horizontal pivot and the same sole height.
	var head_area := Rect2i(source.position + body.position, Vector2i(body.size.x, maxi(1, roundi(body.size.y * 0.35))))
	var anchor_x := _head_center_x(mask, head_area)
	var sole_y := source.position.y + body.end.y - 1
	var region := Rect2i(source.position + body.position, body.size).grow(2).intersection(source)
	var padding := Vector2i(roundi(canvas.x / 2.0 - (anchor_x - region.position.x)), roundi(canvas.y * 0.95) - 1 - (sole_y - region.position.y))
	if padding.x < 0 or padding.y < 0 or padding.x + region.size.x > canvas.x or padding.y + region.size.y > canvas.y:
		return
	atlas.region = Rect2(region)
	atlas.margin = Rect2(Vector2(padding), Vector2(canvas - region.size))
