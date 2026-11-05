class_name ForestNPC
extends CharacterBody2D

# Two alternating contacts make one full cycle. The supplied walking poses
# span about 20 screen pixels between feet; running poses have a longer stride.
const WALK_CYCLE_DISTANCE := 40.0
const RUN_CYCLE_DISTANCE := 54.0

var definition: Dictionary
var current_schedule: Dictionary = {}
var navigator: AStarGrid2D
var sprite: AnimatedSprite2D
var name_label: Label
var interaction_area: Area2D
var route := PackedVector2Array()
var path_index: int = 0
var stop_index: int = 0
var active: bool = false
var sleeping: bool = false
var wants_rest: bool = false
var facing: String = "down"
var waiting: float = 0.0
var stalled: float = 0.0
var custom_sprite: bool = false
var gait_phase: float = 0.75

func setup(profile: Dictionary, fallback: SpriteFrames, grid: AStarGrid2D, minute: float) -> void:
	definition = profile
	name = "NPC_" + profile.id
	navigator = grid
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 4
	collision_mask = 1
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 9.0
	collision.shape = circle
	add_child(collision)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = fallback
	sprite.position = Vector2(0, -26)
	sprite.scale = Vector2.ONE * 1.15
	sprite.modulate = profile.color
	sprite.play("idle_down")
	add_child(sprite)
	name_label = Label.new()
	name_label.position = Vector2(-115, -98)
	name_label.size = Vector2(230, 35)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 9)
	name_label.add_theme_color_override("font_color", Color("eee5c5"))
	name_label.add_theme_color_override("font_outline_color", Color("263a2b"))
	name_label.add_theme_constant_override("outline_size", 4)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(name_label)
	interaction_area = Area2D.new()
	interaction_area.name = "ConversationArea"
	interaction_area.collision_layer = 2
	interaction_area.collision_mask = 0
	interaction_area.monitoring = false
	interaction_area.set_meta("interaction", profile.merged({"kind": "npc"}))
	var area_shape := CollisionShape2D.new()
	var area_circle := CircleShape2D.new()
	area_circle.radius = 65.0
	area_shape.shape = area_circle
	interaction_area.add_child(area_shape)
	add_child(interaction_area)
	apply_schedule(minute, true)
	var bundled := "res://assets/npcs/" + String(profile.id) + ".png"
	if ResourceLoader.exists(bundled):
		load_original_sprite(bundled)

func apply_schedule(minute: float, snap: bool = false) -> void:
	var entry := KingdomData.schedule(definition, minute)
	if entry == current_schedule and not snap:
		return
	current_schedule = entry
	wants_rest = entry.get("rest", false)
	stop_index = 0
	waiting = 0.0
	stalled = 0.0
	if snap:
		position = nearest_walkable(KingdomData.point(entry.points[0]))
	refresh_presence()
	plan_route()
	queue_redraw()

func activity() -> String:
	return "Voltando para descansar" if wants_rest and not sleeping else String(current_schedule.activity)

func refresh_presence() -> void:
	sleeping = wants_rest and position.distance_to(nearest_walkable(KingdomData.point(current_schedule.points[0]))) < 10.0
	visible = not sleeping
	interaction_area.set_deferred("monitorable", not sleeping)
	name_label.text = "%s · %s\n%s" % [definition.name, definition.role, activity()]

func nearest_walkable(point: Vector2) -> Vector2:
	return Vector2(_nearest_cell(point)) * navigator.cell_size

func _nearest_cell(point: Vector2) -> Vector2i:
	var cell := Vector2i(roundi(point.x / navigator.cell_size.x), roundi(point.y / navigator.cell_size.y))
	if navigator.is_in_boundsv(cell) and not navigator.is_point_solid(cell):
		return cell
	for radius in range(1, 9):
		var nearest := Vector2i(-1, -1)
		var nearest_distance := INF
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				var candidate := cell + Vector2i(x, y)
				if navigator.is_in_boundsv(candidate) and not navigator.is_point_solid(candidate):
					var distance := (Vector2(candidate) * navigator.cell_size).distance_to(point)
					if distance < nearest_distance:
						nearest = candidate
						nearest_distance = distance
		if nearest != Vector2i(-1, -1):
			return nearest
	return Vector2i(48, 54)

func plan_route() -> void:
	var target := KingdomData.point(current_schedule.points[stop_index])
	route = navigator.get_point_path(_nearest_cell(position), _nearest_cell(target))
	path_index = 0
	while path_index < route.size() and position.distance_to(route[path_index]) < 7:
		path_index += 1

func _physics_process(delta: float) -> void:
	if not active or sleeping:
		velocity = Vector2.ZERO
		sprite.play("idle_" + facing)
		gait_phase = 0.75
		return
	if waiting > 0:
		waiting -= delta
		if waiting <= 0 and current_schedule.get("loop", false):
			stop_index = (stop_index + 1) % current_schedule.points.size()
			plan_route()
		_idle()
		return
	while path_index < route.size() and position.distance_to(route[path_index]) < 5:
		path_index += 1
	if path_index >= route.size():
		if wants_rest:
			refresh_presence()
		if current_schedule.get("loop", false):
			waiting = 2.0
		_idle()
		return
	var direction := position.direction_to(route[path_index])
	var speed: float = definition.speed
	var running: bool = definition.id == "tomas" and current_schedule.get("loop", false)
	velocity = direction * (speed * 1.2 if running else speed)
	var previous := position
	move_and_slide()
	_animate_movement(get_real_velocity(), running, position.distance_to(previous))
	stalled = stalled + delta if position.distance_to(previous) < 0.15 else 0.0
	if stalled > 1.0:
		stalled = 0.0
		plan_route()

func _idle() -> void:
	velocity = Vector2.ZERO
	sprite.play("idle_" + facing)
	gait_phase = 0.75

func _animate_movement(motion: Vector2, running: bool, distance: float = 0.0) -> void:
	if motion.length_squared() <= 1.0:
		sprite.play("idle_" + facing)
		gait_phase = 0.75
		return
	var horizontal := absf(motion.x)
	var vertical := absf(motion.y)
	# Keep the current axis near a diagonal so tiny path/collision corrections
	# cannot flip the character between two directions every physics frame.
	var use_horizontal := horizontal > vertical
	if facing in ["left", "right"] and horizontal >= vertical * 0.8:
		use_horizontal = true
	elif facing in ["up", "down"] and vertical >= horizontal * 0.8:
		use_horizontal = false
	facing = ("right" if motion.x > 0 else "left") if use_horizontal else ("down" if motion.y > 0 else "up")
	var animation := ("run_" if running else "walk_") + facing
	var previous_animation := String(sprite.animation)
	var keep_phase := previous_animation.begins_with("walk_") or previous_animation.begins_with("run_")
	if keep_phase:
		gait_phase = (sprite.frame + sprite.frame_progress) / sprite.sprite_frames.get_frame_count(previous_animation)
	# Animation never runs ahead while a villager slows down or slides along a
	# wall. Preserving phase also keeps left/right contacts intact through turns.
	var stride := RUN_CYCLE_DISTANCE if running else WALK_CYCLE_DISTANCE
	gait_phase = fposmod(gait_phase + maxf(0.0, distance) / stride, 1.0)
	var frame_position := gait_phase * sprite.sprite_frames.get_frame_count(animation)
	sprite.animation = animation
	sprite.set_frame_and_progress(floori(frame_position), fmod(frame_position, 1.0))
	sprite.pause()

func face(point: Vector2) -> void:
	var direction := point - position
	if absf(direction.x) > absf(direction.y):
		facing = "right" if direction.x > 0 else "left"
	else:
		facing = "down" if direction.y > 0 else "up"
	sprite.play("idle_" + facing)
	gait_phase = 0.75

func load_original_sprite(path: String) -> bool:
	var sheet := CharacterSheet.read(path, true)
	if sheet.is_empty():
		return false
	sprite.sprite_frames = sheet.frames
	sprite.scale = Vector2.ONE * 72.0 / sheet.cell.y
	sprite.position = Vector2(0, -31)
	sprite.modulate = Color.WHITE
	custom_sprite = true
	sprite.play("idle_" + facing)
	queue_redraw()
	return true

func _draw() -> void:
	draw_set_transform(Vector2(0, 2), 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 12, Color(0.1, 0.17, 0.13, 0.4))
	draw_set_transform(Vector2.ZERO)
	if not custom_sprite and not definition.is_empty():
		var realm_color: Color = KingdomData.REALMS[definition.realm].color
		draw_circle(Vector2(16, -46), 6, realm_color)
		if definition.id in ["aurel", "caio"]:
			draw_rect(Rect2(-10, -59, 20, 7), Color("d4b764"))
			for x in [-10, -2, 6]:
				draw_rect(Rect2(x, -63, 4, 6), Color("e7d18d"))
