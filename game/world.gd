class_name ForestWorld
extends Node2D

signal chunk_loaded(coord:Vector2i,content:Dictionary)
signal chunk_unloaded(coord:Vector2i)
signal resource_removed(id:String)
signal house_updated(id:String)

var data:Dictionary
var entities:Node2D
var mother_sprite:AnimatedSprite2D
var mother_label:Label
var mother_material:ShaderMaterial
var tree_materials:Array[ShaderMaterial]=[]
var trees:Array[Dictionary]=[]
var seeds:Dictionary={}
var libraries:Dictionary={}
var player:ForestPlayer
var clock:WorldClock
var navigator:AStarGrid2D
var npcs:Dictionary={}
var daylight:CanvasModulate
var hybrid_rendering:=false
var chunks:Dictionary={}
var resources:Dictionary={}
var animals:Dictionary={}
var houses:Dictionary={}
var house_areas:Dictionary={}
var rpg:RPGState
var stream_timer:=0.0
var simulation_timer:=0.0
var population_active:=false
var mother_entry:Dictionary
var nav_resource_cells:Dictionary={}

func _ready()->void:
	rpg=get_parent().rpg
	data=WorldData.generate()
	entities=$Entities
	player=$Entities/Player
	player.position=MapDocument.spawn_point()
	for row in TreeAtlas.ROWS:
		libraries["tree"+str(row)]=TreeAtlas.read()[row]
		tree_materials.append(TreeAtlas.make_wind_material(row))
	var ground:=TileMapLayer.new()
	ground.name="GrassTiles"
	add_child(ground)
	mother_entry=_add_tree({"id":"mother","position":WorldData.MOTHER,"size":255.0,"radius":26.0,"kind":"wood","active":true},entities,true)
	mother_entry.resource.active=MapDocument.base_enabled()
	mother_entry.body.visible=MapDocument.base_enabled()
	if not MapDocument.base_enabled():mother_entry.body.collision_layer=0
	for seed_data in WorldData.SEEDS:
		var seed:=ForestSeed.new()
		seed.setup(seed_data)
		entities.add_child(seed)
		seeds[seed_data.id]=seed
		if not MapDocument.base_enabled():seed.hide();seed.set_deferred("monitorable",false)
	for feature in WorldData.LANDMARKS:
		if not MapDocument.base_enabled():continue
		var area:=_interaction_area(feature.position,feature.range)
		area.set_meta("interaction",feature.merged({"kind":"landmark"}))
		add_child(area)
	_build_settlements()
	_build_water_collisions()
	_build_boundaries()
	_build_population()
	rpg.resource_depleted.connect(_deplete_resource)
	rpg.house_changed.connect(sync_house)
	ensure_region(player.position,true)

func safe_position(point:Vector2)->Vector2:
	if WorldData.can_stand(point,data,10,true):return point
	for radius in range(1,40):
		for i in 16:
			var test:=point+Vector2.from_angle(i*TAU/16)*radius*32
			if WorldData.can_stand(test,data,10,true):return test
	return MapDocument.spawn_point()

func _build_settlements()->void:
	var walls:=StaticBody2D.new()
	walls.name="BuildingCollisions"
	walls.collision_layer=WorldData.SOLID_LAYER
	walls.collision_mask=0
	for rect in data.solid_rects:
		var shape:=CollisionShape2D.new()
		var box:=RectangleShape2D.new()
		box.size=rect.size
		shape.shape=box
		shape.position=rect.get_center()
		walls.add_child(shape)
	add_child(walls)
	for town in KingdomData.towns():
		for kind in ["shop","inn"]:
			if not KingdomData.service_exists(town,kind):continue
			var at:=KingdomData.point(town.id+"_"+kind)
			var area:=_interaction_area(at,95)
			area.name=kind+"_"+town.id
			area.set_meta("interaction",{"kind":kind,"id":town.id,"name":("Comércio" if kind=="shop" else "Estalagem")+" de "+town.name,"range":95.0})
			add_child(area)
	for building in KingdomData.buildings():
		if not building.get("editor",false) or not building.kind in ["forge","tavern"]:continue
		var rect:=KingdomData.building_rect(building)
		var area:=_interaction_area(Vector2(rect.get_center().x,rect.end.y+40),95)
		area.set_meta("interaction",{"kind":"shop" if building.kind=="forge" else "inn","id":building.id,"name":building.name,"range":95.0})
		add_child(area)
	daylight=CanvasModulate.new()
	add_child(daylight)

func _build_population()->void:
	navigator=AStarGrid2D.new()
	navigator.region=Rect2i(0,0,WorldData.COLS,WorldData.ROWS)
	navigator.cell_size=Vector2.ONE*64
	navigator.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigator.update()
	var clearance_samples:Array[Vector2]=[Vector2.ZERO,Vector2(11,0),Vector2(-11,0),Vector2(0,11),Vector2(0,-11)]
	for y in WorldData.ROWS:
		for x in WorldData.COLS:
			var point:=Vector2(x,y)*64
			var water:=false
			for offset in clearance_samples:
				if WorldData.is_water(point+offset):water=true;break
			navigator.set_point_solid(Vector2i(x,y),water or not WorldData.can_stand(point,data,11,true))
	# Keep travel on roads without scanning every road for every grid point.
	for path in WorldData.paths():
		for i in range(1,path.size()):
			var steps:=maxi(1,ceili(path[i].distance_to(path[i-1])/32))
			for step in steps+1:
				var cell:=Vector2i((path[i-1].lerp(path[i],float(step)/steps)/64).round())
				if navigator.is_in_boundsv(cell):navigator.set_point_weight_scale(cell,0.65)
	clock=WorldClock.new()
	add_child(clock)
	for profile in KingdomData.people():
		var npc:=ForestNPC.new()
		npc.setup(profile,player.default_frames,navigator,clock.minute)
		entities.add_child(npc)
		npcs[profile.id]=npc
	clock.minute_changed.connect(_update_population)
	_update_population()

func _update_population()->void:
	for npc in npcs.values():npc.apply_schedule(clock.minute)
	var hour:=clock.minute/60.0
	var color:=Color(0.98,0.98,0.94)
	if hour<5 or hour>=21:color=Color(0.39,0.49,0.67)
	elif hour<7:color=Color(0.56,0.58,0.64).lerp(color,(hour-5)/2)
	elif hour>=17:color=Color(0.98,0.92,0.81).lerp(Color(0.39,0.49,0.67),(hour-17)/4)
	daylight.color=color

func set_population_active(value:bool)->void:
	population_active=value
	clock.active=value
	for npc in npcs.values():npc.active=value
	for animal in animals.values():animal.active=value

func reset_population()->void:
	clock.set_time(8.5,1)
	for npc in npcs.values():npc.apply_schedule(clock.minute,true)

func population_data()->Dictionary:
	var result:Dictionary={}
	for id in npcs:result[id]={"x":npcs[id].position.x,"y":npcs[id].position.y}
	return result

func restore_population(saved:Dictionary)->void:
	for id in npcs:
		var v=saved.get(id,{})
		if v is Dictionary and (v.get("x") is float or v.get("x") is int) and (v.get("y") is float or v.get("y") is int):
			var p:=Vector2(v.x,v.y)
			if p.is_finite() and WorldData.can_stand(p,data):
				npcs[id].position=p
				npcs[id].refresh_presence()
				npcs[id].plan_route()

func ensure_region(point:Vector2,immediate:bool=false)->void:
	var center:=Vector2i(floori(point.x/WorldData.CHUNK),floori(point.y/WorldData.CHUNK))
	var pending:Array[Vector2i]=[]
	var changed:=false
	for coord in chunks.keys():
		if absi(coord.x-center.x)>2 or absi(coord.y-center.y)>2:_unload_chunk(coord);changed=true
	for y in range(-2,3):
		for x in range(-2,3):
			var coord:=center+Vector2i(x,y)
			if coord.x<0 or coord.y<0 or coord.x*WorldData.CHUNK>=WorldData.SIZE.x or coord.y*WorldData.CHUNK>=WorldData.SIZE.y:continue
			if not chunks.has(coord):pending.append(coord)
	pending.sort_custom(func(a:Vector2i,b:Vector2i):return Vector2(a-center).length_squared()<Vector2(b-center).length_squared())
	for i in (pending.size() if immediate else mini(1,pending.size())):_load_chunk(pending[i]);changed=true
	if changed:_reindex_active()

func _load_chunk(coord:Vector2i)->void:
	var content:=WorldData.generate_chunk(coord,data)
	var node:=Node2D.new()
	node.name="Region_%d_%d"%[coord.x,coord.y]
	entities.add_child(node)
	content.node=node
	content.tree_entries=[]
	content.rock_entries=[]
	content.animal_entries=[]
	for resource in content.trees:
		if rpg.depleted.has(resource.id):continue
		var entry:=_add_tree(resource,node)
		content.tree_entries.append(entry)
		resources[resource.id]=entry
	for resource in content.rocks:
		if rpg.depleted.has(resource.id):continue
		var body:=StaticBody2D.new()
		body.position=resource.position
		var shape:=CollisionShape2D.new()
		var circle:=CircleShape2D.new()
		circle.radius=resource.radius
		shape.shape=circle
		body.add_child(shape)
		_add_resource_area(body,resource)
		node.add_child(body)
		var entry:={"body":body,"resource":resource,"size":resource.size}
		content.rock_entries.append(entry)
		resources[resource.id]=entry
	for definition in content.animals:
		if rpg.depleted.has(definition.id):continue
		var animal:=WorldAnimal.new()
		animal.setup(definition,get_parent())
		animal.active=population_active
		node.add_child(animal)
		animals[definition.id]=animal
		content.animal_entries.append(animal)
	chunks[coord]=content
	chunk_loaded.emit(coord,content)

func _unload_chunk(coord:Vector2i)->void:
	var content:Dictionary=chunks[coord]
	for entry in content.tree_entries+content.rock_entries:resources.erase(entry.resource.id)
	for animal in content.animal_entries:animals.erase(animal.animal_id)
	content.node.queue_free()
	chunks.erase(coord)
	chunk_unloaded.emit(coord)

func _reindex_active()->void:
	trees.assign([mother_entry])
	data.trees=[]
	data.colliders=[mother_entry.resource]
	for content in chunks.values():
		for entry in content.tree_entries:
			trees.append(entry)
			if entry.resource.get("active",true):data.trees.append(entry.resource)
		for entry in content.tree_entries+content.rock_entries:data.colliders.append(entry.resource)
	WorldData.index_obstacles(data)
	var previous:=nav_resource_cells
	nav_resource_cells={}
	for obstacle in data.colliders:
		if not obstacle.get("active",true):continue
		var cell:=Vector2i((obstacle.position/64).round())
		if navigator.is_in_boundsv(cell):nav_resource_cells[cell]=true
	var static_data:={"solid_grid":data.solid_grid,"collision_grid":{}}
	for cell in previous:
		if navigator.is_in_boundsv(cell):navigator.set_point_solid(cell,not WorldData.can_stand(Vector2(cell)*64,static_data,11))
	for cell in nav_resource_cells:navigator.set_point_solid(cell,true)

func _add_tree(resource:Dictionary,parent:Node2D,mother:bool=false)->Dictionary:
	var body:=StaticBody2D.new()
	body.position=resource.position
	var sprite:=AnimatedSprite2D.new()
	var row:=TreeAtlas.variant(resource.position)
	if resource.get("variant")=="autumn_tree":row=1
	if mother:row=TreeAtlas.DRY_ROW
	elif row==TreeAtlas.DRY_ROW:row=TreeAtlas.CALM_ROW
	sprite.sprite_frames=libraries["tree"+str(row)]
	sprite.set_meta("atlas_row",row)
	sprite.centered=false
	sprite.offset=-TreeAtlas.ANCHOR
	sprite.position.y=3
	sprite.scale=Vector2.ONE*resource.size/TreeAtlas.REFERENCE_SIZE
	sprite.material=tree_materials[row]
	sprite.stop()
	body.add_child(sprite)
	var shape:=CollisionShape2D.new()
	var circle:=CircleShape2D.new()
	circle.radius=resource.radius
	shape.shape=circle
	body.add_child(shape)
	if not mother:_add_resource_area(body,resource)
	parent.add_child(body)
	if mother:
		mother_sprite=sprite
		mother_material=TreeAtlas.make_wind_material(row,0.15)
		mother_sprite.material=mother_material
		mother_label=Label.new()
		mother_label.text="Árvore ancestral · tradição do vale"
		body.add_child(mother_label)
	return {"body":body,"sprite":sprite,"size":resource.size,"resource":resource}

func _add_resource_area(body:Node2D,resource:Dictionary)->void:
	var area:=_interaction_area(Vector2.ZERO,62)
	area.set_meta("interaction",{"kind":"resource","id":resource.id,"resource_kind":resource.kind,"name":"Árvore" if resource.kind=="wood" else "Rocha","range":62.0})
	body.add_child(area)

func _interaction_area(point:Vector2,radius:float)->Area2D:
	var area:=Area2D.new()
	area.position=point
	area.collision_layer=2
	area.collision_mask=0
	area.monitoring=false
	var shape:=CollisionShape2D.new()
	var circle:=CircleShape2D.new()
	circle.radius=radius
	shape.shape=circle
	area.add_child(shape)
	return area

func _deplete_resource(id:String)->void:
	if not resources.has(id):return
	var entry:Dictionary=resources[id]
	entry.resource.active=false
	if entry.has("sprite"):entry.sprite.hide()
	for child in entry.body.get_children():
		if child is CollisionShape2D:child.set_deferred("disabled",true)
		if child is Area2D:child.set_deferred("monitorable",false)
	resource_removed.emit(id)
	WorldData.index_obstacles(data)
	var cell:=Vector2i((entry.resource.position/64).round())
	nav_resource_cells.erase(cell)
	for obstacle in data.colliders:
		if obstacle.get("active",true) and Vector2i((obstacle.position/64).round())==cell:nav_resource_cells[cell]=true;break
	_refresh_navigation_rect(Rect2(entry.resource.position-Vector2(64,64),Vector2(128,128)))

func refresh_rpg()->void:
	for id in houses.keys():
		if not rpg.houses.has(id):sync_house(id)
	for id in rpg.depleted.keys():_deplete_resource(id)
	for id in rpg.houses:sync_house(id)

func sync_house(id:String)->void:
	var old_rect:=Rect2()
	if houses.has(id):
		old_rect=houses[id].get_meta("footprint",Rect2())
		houses[id].queue_free()
		houses.erase(id)
	if house_areas.has(id):house_areas[id].queue_free();house_areas.erase(id)
	if rpg.houses.has(id):
		var house:Dictionary=rpg.houses[id]
		if house.stage==3 and npcs.has(house.owner):
			var npc:ForestNPC=npcs[house.owner]
			npc.home_override=Vector2(house.x,house.y+64)
			npc.refresh_presence()
			npc.plan_route()
		var node:=StaticBody2D.new()
		node.name=id
		node.collision_layer=WorldData.SOLID_LAYER
		node.collision_mask=0
		node.set_meta("footprint",rpg.home_rect(house))
		if house.stage>0:
			var shape:=CollisionShape2D.new()
			var box:=RectangleShape2D.new()
			box.size=Vector2(192,128)
			shape.shape=box
			shape.position=Vector2(house.x,house.y-64)
			node.add_child(shape)
		add_child(node)
		houses[id]=node
		var area:=_interaction_area(Vector2(house.x,house.y+36),90)
		area.set_meta("interaction",{"kind":"house","id":id,"name":"Minha casa" if house.owner=="player" else "Casa de "+KingdomData.person(house.owner).get("name","morador"),"range":90.0})
		add_child(area)
		house_areas[id]=area
	data.solid_rects.clear()
	for building in KingdomData.buildings():data.solid_rects.append(KingdomData.building_rect(building))
	for built in rpg.houses.values():
		if built.stage>0:data.solid_rects.append(rpg.home_rect(built))
	WorldData.reindex_solids(data)
	if old_rect.size!=Vector2.ZERO:_refresh_navigation_rect(old_rect)
	if rpg.houses.has(id):_refresh_navigation_rect(rpg.home_rect(rpg.houses[id]))
	house_updated.emit(id)

func _refresh_navigation_rect(rect:Rect2)->void:
	if navigator==null:return
	var static_data:={"solid_grid":data.solid_grid,"collision_grid":{}}
	for y in range(floori(rect.position.y/64)-1,ceili(rect.end.y/64)+2):
		for x in range(floori(rect.position.x/64)-1,ceili(rect.end.x/64)+2):
			var cell:=Vector2i(x,y)
			if navigator.is_in_boundsv(cell):navigator.set_point_solid(cell,nav_resource_cells.has(cell) or not WorldData.can_stand(Vector2(cell)*64,static_data,11))

func _build_water_collisions()->void:
	var water:=StaticBody2D.new()
	water.name="StreamCollision"
	water.collision_layer=WorldData.WATER_LAYER
	water.collision_mask=0
	if MapDocument.base_enabled():
		var cuts:Array[float]=[]
		for y in range(0,int(WorldData.SIZE.y)+1,64):cuts.append(float(y))
		for bridge in WorldData.bridges():cuts.append(bridge.position.y);cuts.append(bridge.end.y)
		cuts.sort()
		for i in range(1,cuts.size()):
			var a:=cuts[i-1]
			var b:=cuts[i]
			if b<=a:continue
			var polygon:=PackedVector2Array([Vector2(WorldData.river_x(a)-WorldData.river_width(a),a),Vector2(WorldData.river_x(a)+WorldData.river_width(a),a),Vector2(WorldData.river_x(b)+WorldData.river_width(b),b),Vector2(WorldData.river_x(b)-WorldData.river_width(b),b)])
			var pieces:Array[PackedVector2Array]=[polygon]
			var min_x:=floori((minf(WorldData.river_x(a),WorldData.river_x(b))-WorldData.RIVER_HALF_WIDTH)/64)
			var max_x:=floori((maxf(WorldData.river_x(a),WorldData.river_x(b))+WorldData.RIVER_HALF_WIDTH)/64)
			for x in range(min_x,max_x+1):
				var cell:=Vector2i(x,floori((a+b)/2/64))
				var painted:String=MapDocument.current.terrain.get(MapDocument.cell_key(cell),"")
				if not painted.is_empty() and painted!="water":pieces=_clip_water(pieces,Rect2(Vector2(cell)*64,Vector2.ONE*64))
			for bridge in WorldData.bridges():
				if bridge.position.y<=a and bridge.end.y>=b:pieces=_clip_water(pieces,bridge)
			_add_water_polygons(water,pieces)
	for rect in MapDocument.water_rects():
		var pieces:Array[Rect2]=[rect]
		for bridge in WorldData.bridges():
			var remaining:Array[Rect2]=[]
			for part in pieces:remaining.append_array(_subtract_water_rect(part,bridge))
			pieces=remaining
		for part in pieces:_add_water_polygons(water,[_rect_polygon(part)])
	add_child(water)
	var rails:=StaticBody2D.new()
	rails.name="BridgeRails"
	rails.collision_layer=WorldData.BRIDGE_RAIL_LAYER
	rails.collision_mask=0
	for rect in WorldData.bridge_rails():
		var shape:=CollisionShape2D.new()
		var box:=RectangleShape2D.new()
		box.size=rect.size
		shape.shape=box
		shape.position=rect.get_center()
		rails.add_child(shape)
	add_child(rails)

func _rect_polygon(rect:Rect2)->PackedVector2Array:
	return PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])

func _subtract_water_rect(rect:Rect2,cut:Rect2)->Array[Rect2]:
	# Rectangle subtraction avoids polygon holes becoming solid colliders when
	# the bridge sits completely inside a large lake.
	if not rect.intersects(cut):return [rect]
	var hole:=rect.intersection(cut)
	var result:Array[Rect2]=[]
	for part in [Rect2(rect.position,Vector2(rect.size.x,hole.position.y-rect.position.y)),Rect2(Vector2(rect.position.x,hole.end.y),Vector2(rect.size.x,rect.end.y-hole.end.y)),Rect2(Vector2(rect.position.x,hole.position.y),Vector2(hole.position.x-rect.position.x,hole.size.y)),Rect2(Vector2(hole.end.x,hole.position.y),Vector2(rect.end.x-hole.end.x,hole.size.y))]:
		if part.size.x>0 and part.size.y>0:result.append(part)
	return result

func _clip_water(pieces:Array[PackedVector2Array],rect:Rect2)->Array[PackedVector2Array]:
	var output:Array[PackedVector2Array]=[]
	for polygon in pieces:output.append_array(Geometry2D.clip_polygons(polygon,_rect_polygon(rect)))
	return output

func _add_water_polygons(body:StaticBody2D,pieces:Array[PackedVector2Array])->void:
	for points in pieces:
		if points.size()<3:continue
		var polygon:=CollisionPolygon2D.new()
		polygon.polygon=points
		body.add_child(polygon)

func _build_boundaries()->void:
	var body:=StaticBody2D.new()
	body.name="WorldBoundary"
	var s:=WorldData.SIZE
	for rect in [Rect2(-100,-100,s.x+200,128.4),Rect2(-100,s.y-28.4,s.x+200,128.4),Rect2(-100,0,128.4,s.y),Rect2(s.x-28.4,0,128.4,s.y)]:
		var shape:=CollisionShape2D.new()
		var box:=RectangleShape2D.new()
		box.size=rect.size
		shape.shape=box
		shape.position=rect.get_center()
		body.add_child(shape)
	add_child(body)

func apply_progress(collected:Dictionary,complete:bool)->void:
	for id in seeds:
		if collected.has(id):seeds[id].gather()
		else:seeds[id].gathered=false;seeds[id].show();seeds[id].set_deferred("monitorable",true)
	var row:=TreeAtlas.CALM_ROW if complete else TreeAtlas.DRY_ROW
	mother_sprite.sprite_frames=libraries["tree"+str(row)]
	mother_material=TreeAtlas.make_wind_material(row,1.0 if complete else 0.15)
	mother_sprite.material=mother_material

func burst(point:Vector2,amount:int=15)->void:
	# Gameplay feedback is handled by the 3D scene and the HUD.
	pass

func _process(delta:float)->void:
	stream_timer+=delta
	if stream_timer>=0.12:
		stream_timer=0
		ensure_region(player.position)
	simulation_timer+=delta
	if simulation_timer<0.25:return
	var step:=simulation_timer
	simulation_timer=0
	var markers:Array[Dictionary]=[]
	for npc in npcs.values():
		var nearby:bool=npc.position.distance_squared_to(player.position)<1800*1800
		npc.set_physics_process(nearby)
		if not nearby and population_active:npc.advance_offscreen(step)
		if not npc.sleeping:markers.append({"position":npc.position,"realm":npc.definition.realm})
	data.npc_markers=markers
