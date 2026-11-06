class_name ForestPlayer
extends CharacterBody2D

signal interact_requested

const WALK_SPEED: float = 135.0
const RUN_SPEED: float = 225.0
const SWIM_SPEED := 86.0
const FAST_SWIM_SPEED := 120.0
const SWIM_ACCELERATION := 260.0
const RIVER_CURRENT := Vector2(0, 5)
const DIRECTIONS := ["down", "up", "right", "left"]

var active: bool = false
var stamina: float = 1.0
var touch_vector := Vector2.ZERO
var facing: String = "down"
var running: bool = false
var sprite: AnimatedSprite2D
var sensor: Area2D
var default_frames: SpriteFrames
var swimming := false
var on_bridge := false
var swim_phase := 0.0

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	wall_min_slide_angle = 0.0
	max_slides = 6
	collision_layer = 8
	collision_mask = WorldData.SOLID_LAYER | WorldData.BRIDGE_RAIL_LAYER
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10.0
	collision.shape = circle
	add_child(collision)
	sensor = Area2D.new()
	sensor.name = "InteractionSensor"
	sensor.collision_layer = 0
	sensor.collision_mask = 2
	var sensor_shape := CollisionShape2D.new()
	var sensor_circle := CircleShape2D.new()
	sensor_circle.radius = 1.0
	sensor_shape.shape = sensor_circle
	sensor.add_child(sensor_shape)
	add_child(sensor)
	sprite = AnimatedSprite2D.new()
	sprite.name = "CharacterAnimation"
	sprite.position = Vector2(0, -26)
	sprite.scale = Vector2.ONE * 1.15
	default_frames = _default_animations()
	var provided := TomateCharacterSheet.read()
	if not provided.is_empty():
		default_frames = provided.frames
	sprite.sprite_frames = default_frames
	sprite.play("idle_down")
	add_child(sprite)
	sprite.animation_changed.connect(_sync_character_geometry)
	use_default_character()

func _physics_process(delta: float) -> void:
	update_surface()
	if not active:
		velocity = Vector2.ZERO
		running = false
		sprite.play("idle_" + facing)
		return
	var direction := (Input.get_vector("move_left", "move_right", "move_up", "move_down") + touch_vector).limit_length(1.0)
	running = direction.length_squared() > 0.01 and Input.is_action_pressed("run") and stamina > 0.02
	if direction.length_squared() > 0.01:
		if absf(direction.x) > absf(direction.y):
			facing = "right" if direction.x > 0 else "left"
		else:
			facing = "down" if direction.y > 0 else "up"
	if swimming:
		var target := direction * (FAST_SWIM_SPEED if running else SWIM_SPEED) + RIVER_CURRENT
		velocity = velocity.move_toward(target, SWIM_ACCELERATION * delta)
	else:
		velocity = direction * (RUN_SPEED if running else WALK_SPEED)
	move_and_slide()
	update_surface()
	var moving := get_real_velocity().length_squared() > 1.0
	stamina = clampf(stamina + delta * (-0.08 if swimming and running else (-0.14 if running and moving else 0.25)), 0.0, 1.0)
	swim_phase += delta * (3.2 if moving else 1.6) if swimming else 0.0
	sprite.speed_scale = 0.45 if swimming else 1.0
	sprite.play(("run_" if running and not swimming else "walk_") + facing if moving and direction.length_squared() > 0.01 else "idle_" + facing)

func update_surface() -> void:
	# A swimmer stays below the bridge. Only entry from dry land boards its
	# ramps; deck rails block walkers, while swimmers can pass underneath.
	if on_bridge and WorldData.bridge_at(position).size==Vector2.ZERO:
		on_bridge = false
	if not on_bridge:
		if swimming:
			swimming = WorldData.in_river(position)
		if not swimming:
			on_bridge = WorldData.bridge_at(position).size!=Vector2.ZERO
			swimming = WorldData.in_river(position) and not on_bridge
	collision_mask = WorldData.SOLID_LAYER | (0 if swimming else WorldData.BRIDGE_RAIL_LAYER)

func restore_surface(under_bridge: bool = false) -> void:
	on_bridge = false
	swimming = under_bridge and WorldData.in_river(position)
	velocity = Vector2.ZERO
	update_surface()

func surface_height() -> float:
	return WorldData.bridge_height(position) if on_bridge else 0.0

func _unhandled_input(event: InputEvent) -> void:
	if active and event.is_action_pressed("interact") and not event.is_echo():
		interact_requested.emit()
		get_viewport().set_input_as_handled()

func _draw() -> void:
	draw_set_transform(Vector2(0, 1), 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 11, Color(0.1, 0.17, 0.13, 0.43))
	draw_set_transform(Vector2.ZERO)

func use_default_character() -> void:
	sprite.sprite_frames = default_frames
	sprite.scale = Vector2.ONE * 1.15
	sprite.position = Vector2(0, -26)
	sprite.material = TomateCharacterSheet.make_material() if TomateCharacterSheet.is_sheet(default_frames) else null
	sprite.play("idle_" + facing)
	_sync_character_geometry()

func load_character_file(path: String) -> bool:
	var sheet := CharacterSheet.read(path)
	if sheet.is_empty():
		return false
	sprite.sprite_frames = sheet.frames
	sprite.material = null
	sprite.scale = Vector2.ONE * 72.0 / sheet.cell.y
	sprite.position = Vector2(0, -31)
	sprite.play("idle_" + facing)
	return true

func _sync_character_geometry() -> void:
	TomateCharacterSheet.apply_geometry(sprite)

func _default_animations() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for direction in DIRECTIONS:
		for mode in ["idle", "walk", "run"]:
			var animation: String = mode + "_" + direction
			frames.add_animation(animation)
			frames.set_animation_speed(animation, 12.0 if mode == "run" else 8.0)
			for frame in (1 if mode == "idle" else 4):
				frames.add_frame(animation, _fallback_texture(direction, frame, mode != "idle"))
	return frames

func _fallback_texture(direction: String, frame: int, moving: bool) -> Texture2D:
	# A small placeholder, used only until the original character PNG is available.
	var image := Image.create(32, 52, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var step: int = [0, 1, 0, -1][frame] if moving else 0
	var back := direction == "up"
	_pixel(image, "343c2b", Rect2i(3, 18, 4, 5 + step))
	_pixel(image, "343c2b", Rect2i(8, 18, 3, 5 - step))
	_pixel(image, "65513b", Rect2i(2, 22 + step, 5, 2))
	_pixel(image, "65513b", Rect2i(8, 22 - step, 5, 2))
	_pixel(image, "3a5140", Rect2i(2, 12, 11, 8))
	_pixel(image, "899b64", Rect2i(3, 12, 9, 7))
	_pixel(image, "a8b47d", Rect2i(4, 12, 6, 2))
	_pixel(image, "d7af78", Rect2i(1, 14 + step, 2, 5))
	_pixel(image, "d7af78", Rect2i(12, 14 - step, 2, 5))
	_pixel(image, "aa6946", Rect2i(3, 11, 9, 2))
	if back:
		_pixel(image, "7d5635", Rect2i(3, 14, 8, 6))
		_pixel(image, "bc8551", Rect2i(4, 14, 6, 5))
		_pixel(image, "d2a065", Rect2i(4, 15, 6, 1))
		_pixel(image, "665035", Rect2i(6, 17, 2, 2))
	else:
		_pixel(image, "c68b55", Rect2i(3, 13, 2, 7))
		_pixel(image, "d6b478", Rect2i(3, 18, 7, 2))
	_pixel(image, "4f4130", Rect2i(3, 4, 9, 7))
	_pixel(image, "e1b881", Rect2i(4, 7, 7, 5))
	if back:
		_pixel(image, "6d5237", Rect2i(3, 7, 9, 4))
	else:
		_pixel(image, "343c2b", Rect2i(5, 8, 1, 2))
		_pixel(image, "343c2b", Rect2i(9, 8, 1, 2))
		_pixel(image, "bf875e", Rect2i(7, 11, 2, 1))
	_pixel(image, "3b4c36", Rect2i(2, 4, 11, 3))
	_pixel(image, "8b9a62", Rect2i(3, 2, 9, 4))
	_pixel(image, "abb77c", Rect2i(4, 2, 7, 1))
	_pixel(image, "b5b17b", Rect2i(1, 6, 13, 1))
	_pixel(image, "77895b", Rect2i(0, 7, 14, 1))
	_pixel(image, "e6d9a0", Rect2i(10, 0, 1, 4))
	_pixel(image, "bbc79b", Rect2i(11, 0, 1, 3))
	if direction == "left":
		image.flip_x()
	return ImageTexture.create_from_image(image)

func _pixel(image: Image, color: String, rect: Rect2i) -> void:
	image.fill_rect(Rect2i(rect.position * 2, rect.size * 2), Color(color))
