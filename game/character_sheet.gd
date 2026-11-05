class_name CharacterSheet
extends RefCounted

const DIRECTIONS := ["down", "up", "right", "left"]

static func read(path: String) -> Dictionary:
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
	var cell := Vector2(image.get_width() / 5.0, image.get_height() / 8.0)
	for row in 4:
		for mode in ["idle", "walk", "run"]:
			var animation: String = mode + "_" + DIRECTIONS[row]
			frames.add_animation(animation)
			frames.set_animation_speed(animation, 12.0 if mode == "run" else 8.0)
			var source_row := row + (4 if mode == "run" else 0)
			for col in ([0] if mode == "idle" else [1, 2, 3, 4]):
				var atlas := AtlasTexture.new()
				atlas.atlas = texture
				atlas.region = Rect2(Vector2(col, source_row) * cell, cell)
				frames.add_frame(animation, atlas)
	return {"frames": frames, "cell": cell}
