class_name HouseInterior
extends Node2D

var system: HouseSystem
var data: Dictionary
var kit: HouseData
var dimensions: Vector2
var spawn_point: Vector2
var stage: Node3D
var camera: Camera3D
var environment: Environment
var actor: Sprite3D
var furniture: Array[Dictionary] = []
var interactions: Array[Dictionary] = []

func setup(source: HouseSystem, building: Dictionary) -> void:
	system=source;data=building;kit=HouseKit.definition(HouseKit.style_for(data));dimensions=Vector2(kit.interior_cells)*WorldGrid.CELL
	spawn_point=Vector2(dimensions.x/2,dimensions.y-70)
	stage=Node3D.new();add_child(stage)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=maxf(9,dimensions.x/64+2.5);stage.add_child(camera)
	environment=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color("171e27")
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color("dfbd86");environment.ambient_light_energy=0.8
	environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-60,-25,0);sun.light_color=Color("ffe3ac");sun.light_energy=0.85;stage.add_child(sun)
	var w:=dimensions.x/64;var d:=dimensions.y/64
	visual(Vector3(w/2,-0.08,d/2),Vector3(w,0.16,d),Color("75604b"))
	# Open front wall is a cutaway for the camera; the two sides remain solid.
	wall(Rect2(-16,-16,dimensions.x+32,32),Vector3(w/2,1.05,0),Vector3(w+0.3,2.1,0.20))
	wall(Rect2(-16,0,32,dimensions.y),Vector3(0,1.05,d/2),Vector3(0.20,2.1,d))
	wall(Rect2(dimensions.x-16,0,32,dimensions.y),Vector3(w,1.05,d/2),Vector3(0.20,2.1,d))
	collider(Rect2(0,dimensions.y-10,dimensions.x/2-40,32));collider(Rect2(dimensions.x/2+40,dimensions.y-10,dimensions.x/2-40,32))
	# The threshold blocks the outside void, with E providing the portal.
	collider(Rect2(dimensions.x/2-40,dimensions.y+10,80,24))
	visual(Vector3(w/2,0.01,d-0.45),Vector3(1.2,0.03,0.9),kit.accent_color)
	interactions.append({"kind":"house_exit","id":"exit","name":"Sair · "+data.name,"at":Vector2(dimensions.x/2,dimensions.y-28)})
	if kit.id in ["poor","common","rich"]:
		add_bed(Vector2(80,95))
		add_table(Vector2(dimensions.x-112,130))
		furnish(Rect2(dimensions.x-85,dimensions.y-175,55,75),0.9,Color("6d4d37"))
		if kit.id=="rich":
			visual(Vector3(w*0.60,0.012,d*0.62),Vector3(2.8,0.025,2.1),Color("8f4845"))
			furnish(Rect2(35,dimensions.y-170,105,50),0.65,Color("5c6b79"))
	elif kit.id=="tavern":
		for y in [175,310]:
			for x in [125,dimensions.x-130]:add_table(Vector2(x,y))
		add_bed(Vector2(dimensions.x-80,80))
		counter(Vector2(dimensions.x/2,75),"Conversar com o estalajadeiro")
	else:
		counter(Vector2(dimensions.x/2,110),"Negociar ferramentas e provisões")
		for x in [50,dimensions.x-85]:
			furnish(Rect2(x,185,35,110),1.1,Color("5b4533"))
			for index in 3:visual(WorldGrid.point3(Vector2(x+17,205+index*30))+Vector3(0,1.16,0),Vector3(0.3,0.25,0.22),[Color("99744e"),Color("80905e"),Color("9e5c46")][index])
	# Furniture is persistent kit data; only player position and shared RPG state
	# need saving. Loading the same seed recreates this exact room.
	var window:=visual(Vector3(w*0.65,1.25,0.13),Vector3(0.85,0.8,0.04),Color("eed7a5"));window.name="InteriorWindow"
	var light:=OmniLight3D.new();light.position=Vector3(w/2,2,d/2);light.omni_range=maxf(w,d);light.light_color=Color("ffcb83");light.light_energy=0.7;stage.add_child(light)
	queue_redraw()

func visual(at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size;node.mesh=mesh;node.position=at
	var material:=StandardMaterial3D.new();material.albedo_color=color;material.roughness=1;node.material_override=material;stage.add_child(node)
	return node

func collider(rect: Rect2) -> void:
	var body:=StaticBody2D.new();body.collision_layer=WorldData.SOLID_LAYER;body.collision_mask=0
	var shape:=CollisionShape2D.new();var box:=RectangleShape2D.new();box.size=rect.size;shape.shape=box;shape.position=rect.get_center();body.add_child(shape);add_child(body)

func wall(rect: Rect2, at: Vector3, size: Vector3) -> void:
	collider(rect);visual(at,size,kit.wall_color)

func furnish(rect: Rect2, height: float, color: Color) -> void:
	furniture.append({"rect":rect,"color":color});collider(rect)
	visual(WorldGrid.point3(rect.get_center())+Vector3(0,height/2,0),Vector3(rect.size.x/64,height,rect.size.y/64),color)

func add_bed(point: Vector2) -> void:
	furnish(Rect2(point-Vector2(32,50),Vector2(64,100)),0.35,Color("644b38"))
	visual(WorldGrid.point3(point)+Vector3(0,0.40,0),Vector3(0.9,0.18,1.45),kit.accent_color)
	visual(WorldGrid.point3(point-Vector2(0,30))+Vector3(0,0.54,0),Vector3(0.72,0.15,0.35),Color("ddd5b9"))
	interactions.append({"kind":"house_bed","id":"bed","name":"Descansar na cama","at":point+Vector2(30,75)})

func add_table(point: Vector2) -> void:
	furnish(Rect2(point-Vector2(40,25),Vector2(80,50)),0.72,Color("886a45"))
	for side in [-1,1]:furnish(Rect2(point+Vector2(side*58-12,-12),Vector2(24,24)),0.38,Color("6b5039"))
	visual(WorldGrid.point3(point)+Vector3(0,0.80,0),Vector3(0.18,0.18,0.18),Color("d9bd79"))

func counter(point: Vector2, text: String) -> void:
	furnish(Rect2(point-Vector2(90,22),Vector2(180,44)),0.85,Color("89603c"))
	interactions.append({"kind":"house_counter","id":"counter","name":text,"at":point+Vector2(0,70)})

func walkable(point: Vector2) -> bool:
	if not Rect2(Vector2.ONE*30,dimensions-Vector2.ONE*60).has_point(point):return false
	for entry in furniture:
		if entry.rect.grow(12).has_point(point):return false
	return true

func interaction(point: Vector2) -> Dictionary:
	var result:Dictionary={};var distance:=68.0
	for entry in interactions:
		var d:float=entry.at.distance_to(point)
		if d<distance:distance=d;result=entry
	return result

func create_actor() -> void:
	actor=system.game.hybrid._card(system.game.player.sprite);actor.reparent(stage)
	actor.material_override=actor.material_override.duplicate();actor.material_override.set_shader_parameter("day_color",Vector3(1.0,0.92,0.80))

func _process(delta: float) -> void:
	if system==null:return
	var game:=system.game
	game.world.clock.active=game.mode=="playing"
	if game.hybrid!=null:
		# Keep camera controls usable without processing the outside renderer.
		var desired:=WorldGrid.point3(Vector2(dimensions.x/2,dimensions.y/2))+Vector3(0,12,14).rotated(Vector3.UP,game.hybrid.target_yaw)
		camera.position=camera.position.lerp(desired,1.0-exp(-10*delta)) if camera.position!=Vector3.ZERO else desired
		camera.look_at(WorldGrid.point3(dimensions/2))
		camera.size=lerpf(camera.size,clampf(game.hybrid.target_zoom,8,18),1.0-exp(-7*delta))
		game.player.view_yaw=game.hybrid.target_yaw
		if actor!=null:game.hybrid._sync(actor,game.player.sprite);actor.position=WorldGrid.point3(game.player.position)

func _draw() -> void:
	if system==null or system.game.hybrid!=null:return
	draw_rect(Rect2(Vector2.ZERO,dimensions),Color("75604b"))
	for entry in furniture:draw_rect(entry.rect,entry.color)
