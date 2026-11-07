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
var appearance_data:AppearanceData
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
var home_override:=Vector2(INF,INF)
var work_override:=Vector2(INF,INF)
var economic_target := Vector2(INF,INF)
var economic_activity := ""
var enforcement_target:=Vector2(INF,INF)
var companion_mode:=false
var follow_target:=Vector2(INF,INF)
var task_target:=Vector2(INF,INF)
var state:="travel"
var hunger:=0.15
var fatigue:=0.1
var work_cycles:=0
var choice_serial:=0
var retry_delay:=0.0
var route_failures:=0
var neighbors:Array=[]
var threat_until:=0.0
var personality_seed:=0
var action_phase:=0.0

func setup(profile: Dictionary, fallback: SpriteFrames, grid: AStarGrid2D, minute: float) -> void:
	definition = profile
	personality_seed=posmod(String(profile.id).hash(),100000)
	hunger=0.1+(personality_seed%20)/100.0
	name = "NPC_" + profile.id
	navigator = grid
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	wall_min_slide_angle = 0.0
	collision_layer = 4
	collision_mask = WorldData.SOLID_LAYER | WorldData.WATER_LAYER | WorldData.BRIDGE_RAIL_LAYER
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
	sprite.animation_changed.connect(_sync_character_geometry)
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
	load_default_sprite()

func apply_schedule(minute: float, snap: bool = false) -> void:
	var entry := KingdomData.schedule(definition, minute)
	if entry == current_schedule and not snap:
		return
	current_schedule = entry
	wants_rest = entry.get("rest", false) and not companion_mode
	stop_index = 0
	waiting = 0.0
	stalled = 0.0
	task_target=Vector2(INF,INF)
	state="returning_home" if wants_rest else "travel"
	retry_delay=0
	if snap and not companion_mode:
		position = nearest_walkable(_scheduled_point())
	refresh_presence()
	plan_route()
	queue_redraw()

func activity() -> String:
	if enforcement_target.is_finite():return "Perseguindo invasor procurado"
	if state=="flee":return "Procurando abrigo"
	if companion_mode:return "Viajando em sua companhia"
	if economic_target.is_finite() and not sleeping and not wants_rest:return economic_activity
	if state=="blocked":return "Esperando o caminho liberar"
	if state=="social" and not neighbors.is_empty():return "Conversando com os vizinhos"
	return "Voltando para descansar" if wants_rest and not sleeping else String(current_schedule.activity)

func refresh_presence() -> void:
	sleeping = not enforcement_target.is_finite() and not companion_mode and wants_rest and position.distance_to(nearest_walkable(_scheduled_point())) < 10.0
	visible = not sleeping
	interaction_area.set_deferred("monitorable", not sleeping)
	name_label.text = "%s · %s\n%s" % [definition.name, definition.role, activity()]

func nearest_walkable(point: Vector2) -> Vector2:
	var cell:=_nearest_cell(point)
	return Vector2(cell)*navigator.cell_size if cell.x>=0 else position

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
	return Vector2i(-1,-1)

func plan_route() -> void:
	var target:=_target()
	var start:=_nearest_cell(position)
	var end:=_nearest_cell(target)
	route=PackedVector2Array();path_index=0
	if start.x<0 or end.x<0:
		state="blocked";retry_delay=5;return
	route=navigator.get_point_path(start,end)
	if route.is_empty():
		state="blocked";route_failures+=1;retry_delay=minf(10,2+route_failures);return
	if state=="blocked":state="returning_home" if wants_rest else "travel"
	route_failures=0
	while path_index<route.size() and position.distance_to(route[path_index])<7:path_index+=1

func _target()->Vector2:
	if enforcement_target.is_finite():return enforcement_target
	if wants_rest:return _scheduled_point()
	if state in ["flee","detour"] and task_target.is_finite():return task_target
	if companion_mode and follow_target.is_finite():return follow_target
	if economic_target.is_finite():return economic_target
	return task_target if task_target.is_finite() else _scheduled_point(stop_index)

func update_brain(delta:float,nearby:Array,hostiles:Array)->void:
	neighbors=nearby
	if not active:return
	action_phase+=delta
	hunger=clampf(hunger+delta/480.0,0,1)
	fatigue=clampf(fatigue+(-delta/50.0 if sleeping else delta/1800.0),0,1)
	if sleeping:return
	if enforcement_target.is_finite():return
	retry_delay=maxf(0,retry_delay-delta)
	threat_until=maxf(0,threat_until-delta)
	if state=="blocked" and retry_delay<=0:task_target=Vector2(INF,INF);plan_route()
	if threat_until<=0 and state=="flee":state="travel";task_target=Vector2(INF,INF);plan_route()
	if not wants_rest and threat_until<=0 and definition.id!="tomas":
		for hostile in hostiles:
			if not is_instance_valid(hostile) or not hostile.alive:continue
			if position.distance_squared_to(hostile.position)<180*180:
				var away:Vector2=hostile.position.direction_to(position)
				if away==Vector2.ZERO:away=Vector2.RIGHT
				task_target=nearest_walkable(position+away*320)
				state="flee";threat_until=5;waiting=0;plan_route();break
	if state=="social" and waiting>0:
		for other in neighbors:
			if is_instance_valid(other) and other!=self and not other.sleeping and position.distance_to(other.position)<100:
				face(other.position);break

func _physics_process(delta:float)->void:
	if not active or sleeping:_idle();return
	if state=="blocked":_idle();return
	if waiting>0:
		waiting=maxf(0,waiting-delta)
		if waiting<=0:_next_task()
		_idle();return
	while path_index<route.size() and position.distance_to(route[path_index])<6:path_index+=1
	if path_index>=route.size():_arrive();_idle();return
	var direction:=position.direction_to(route[path_index])
	var speed:float=definition.speed*(1.35 if state=="flee" else 1.0)
	if enforcement_target.is_finite():speed=maxf(speed,165.0)
	if companion_mode and state!="flee":speed=maxf(speed,230.0 if position.distance_to(_target())>300 else (180.0 if position.distance_to(_target())>150 else 110.0))
	var separation:=Vector2.ZERO
	for other in neighbors:
		if not is_instance_valid(other) or other==self or other.sleeping:continue
		var offset:Vector2=position-other.position
		if offset.length_squared()<=0.01:separation+=Vector2.RIGHT if String(definition.id)>String(other.definition.id) else Vector2.LEFT
		if offset.length_squared()<28*28 and offset.length_squared()>0.01:separation+=offset.normalized()*(1-offset.length()/28)
	direction=(direction+separation*0.65).normalized()
	# A local sweep finds a safe side around a trunk or a building corner.
	if test_move(global_transform,direction*speed*minf(delta,0.15)):
		for angle in [0.65,-0.65,1.2,-1.2]:
			var alternative:=direction.rotated(angle)
			if not test_move(global_transform,alternative*speed*minf(delta,0.15)):
				direction=alternative;break
	velocity=direction*speed
	var previous:=position
	move_and_slide()
	var distance:=position.distance_to(previous)
	_animate_movement(get_real_velocity(),enforcement_target.is_finite() or state=="flee" or companion_mode and speed>140,distance)
	stalled=stalled+delta if distance<0.15 else 0.0
	if stalled>1.2:
		stalled=0;retry_delay=0.5;task_target=nearest_walkable(position+Vector2(96 if personality_seed%2 else -96,64));state="detour";plan_route()

func _arrive()->void:
	if enforcement_target.is_finite():waiting=0.2;return
	if state=="detour":task_target=Vector2(INF,INF);state="travel";plan_route();return
	if companion_mode and state!="flee":state="following";waiting=0.5;refresh_presence();return
	if wants_rest:
		refresh_presence()
		if not sleeping:waiting=3
		return
	if state=="flee":waiting=0.5;return
	state="work" if current_schedule.get("work",false) else ("social" if current_schedule.get("social",false) else "idle")
	if state=="work":work_cycles+=1
	waiting=2.5+((personality_seed+choice_serial*17)%35)/10.0
	refresh_presence()

func _next_task()->void:
	if enforcement_target.is_finite():plan_route();return
	choice_serial+=1
	if companion_mode and state=="flee":waiting=0.5;return
	if companion_mode:task_target=Vector2(INF,INF);plan_route();return
	if wants_rest:plan_route();return
	if economic_target.is_finite():plan_route();return
	if current_schedule.get("loop",false):
		stop_index=(stop_index+1)%current_schedule.points.size()
		task_target=Vector2(INF,INF)
	elif current_schedule.get("work",false) or current_schedule.get("social",false):
		var origin:=_scheduled_point()
		var angle:=fposmod(personality_seed*0.01+choice_serial*2.399,TAU)
		task_target=nearest_walkable(origin+Vector2.from_angle(angle)*(64+((choice_serial+personality_seed)%3)*32))
	else:task_target=Vector2(INF,INF)
	state="travel";plan_route()

func set_economic_goal(point:Vector2,label:String)->void:
	economic_activity=label
	if economic_target.is_equal_approx(point):return
	economic_target=point;task_target=Vector2(INF,INF);waiting=0
	plan_route()

func clear_economic_goal()->void:
	economic_target=Vector2(INF,INF);task_target=Vector2(INF,INF);plan_route()

func advance_offscreen(delta:float)->void:
	if not active or sleeping or state=="blocked":return
	if waiting>0:
		waiting=maxf(0,waiting-delta)
		if waiting<=0:_next_task()
		return
	var remaining:float=definition.speed*delta
	if companion_mode:remaining=maxf(float(definition.speed),180.0)*delta
	while path_index<route.size() and remaining>0:
		var distance:=position.distance_to(route[path_index])
		if distance<=remaining:position=route[path_index];remaining-=distance;path_index+=1
		else:position=position.move_toward(route[path_index],remaining);remaining=0
	if path_index>=route.size():_arrive()

func mind_data()->Dictionary:
	return {"hunger":hunger,"fatigue":fatigue,"cycles":work_cycles,"serial":choice_serial}

func restore_mind(data:Dictionary)->void:
	for field in ["hunger","fatigue"]:
		var value:Variant=data.get(field,0.1)
		if (value is int or value is float) and is_finite(float(value)):set(field,clampf(value,0,1))
	work_cycles=clampi(int(data.get("cycles",0)),0,1000000)
	choice_serial=clampi(int(data.get("serial",0)),0,1000000)

func emote()->String:
	if enforcement_target.is_finite() or state=="flee":return "!"
	if state=="work":return {"Lenhador":"/","Mineiro":"*","Ferreiro":"*","Agricultora":"+","Agricultor":"+","Herbalista":"+"}.get(definition.role,"...")
	if state=="social":return "..."
	return ""

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
	sprite.material = null
	appearance_data=AppearanceGenerator.for_profile(definition)
	if sprite.has_meta("appearance_data"):sprite.remove_meta("appearance_data")
	sprite.scale = Vector2.ONE * 72.0 / sheet.cell.y
	sprite.position = Vector2(0, -31)
	sprite.modulate = Color.WHITE
	custom_sprite = true
	sprite.play("idle_" + facing)
	queue_redraw()
	return true

func load_default_sprite() -> bool:
	if not NPCAppearance.apply(sprite,definition):
		return false
	appearance_data=sprite.get_meta("appearance_data")
	custom_sprite = true
	sprite.play("idle_" + facing)
	_sync_character_geometry()
	queue_redraw()
	return true

func _sync_character_geometry() -> void:
	NPCAppearance.geometry(sprite)

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

func _scheduled_point(index:int=0)->Vector2:
	if wants_rest and home_override.is_finite():return home_override
	if current_schedule.get("work",false) and work_override.is_finite():return work_override
	return KingdomData.point(current_schedule.points[index])
