class_name StreamedLandscape
extends Node3D

var hybrid:HybridWorld
var game:ForestGame
var regions:Dictionary={}
var resource_instances:Dictionary={}
var ground_shadows:Dictionary={}
var materials:Dictionary={}
var house_models:Dictionary={}
var piece_models:Dictionary={}
var house_front_material:ShaderMaterial

func setup(renderer:HybridWorld)->void:
	hybrid=renderer
	game=renderer.game
	name="StreamedWorld"
	game.world.chunk_loaded.connect(load_region)
	game.world.chunk_unloaded.connect(unload_region)
	game.world.resource_removed.connect(remove_resource)
	game.world.house_updated.connect(update_house)
	game.world.piece_updated.connect(update_piece)
	for coord in game.world.chunks:load_region(coord,game.world.chunks[coord])
	for id in game.rpg.houses:update_house(id)
	for id in game.rpg.construction.pieces:update_piece(id)

func load_region(coord:Vector2i,content:Dictionary)->void:
	var parent:=Node3D.new()
	parent.name="Chunk_%d_%d"%[coord.x,coord.y]
	add_child(parent)
	regions[coord]=parent
	_ground(parent,content)
	_painted_water(parent,content)
	_trees(parent,content)
	_rocks(parent,content)
	for animal in content.animal_entries:
		var model:=AnimalVisual.new()
		model.setup(animal)
		parent.add_child(model)
	for id in game.rpg.construction.pieces:
		var entry:Dictionary=game.rpg.construction.pieces[id]
		if Vector2i((ConstructionCatalog.footprint(entry).get_center()/WorldData.CHUNK).floor())==coord:update_piece(id)

func unload_region(coord:Vector2i)->void:
	for id in piece_models.keys():
		if piece_models[id].get_meta("coord")==coord:piece_models[id].queue_free();piece_models.erase(id)
	if regions.has(coord):regions[coord].queue_free();regions.erase(coord)
	for id in resource_instances.keys():
		if resource_instances[id].coord==coord:resource_instances.erase(id)
	ground_shadows.erase(coord)

func update_piece(id:String)->void:
	if piece_models.has(id):piece_models[id].queue_free();piece_models.erase(id)
	if not game.rpg.construction.pieces.has(id):return
	var entry:Dictionary=game.rpg.construction.pieces[id]
	var coord:=Vector2i((ConstructionCatalog.footprint(entry).get_center()/WorldData.CHUNK).floor())
	if not regions.has(coord):return
	var model:=ConstructionVisual.new();model.setup_piece(entry,game.rpg.construction.joints);model.set_meta("coord",coord)
	add_child(model);piece_models[id]=model

func _ground(parent:Node3D,content:Dictionary)->void:
	var view:=SubViewport.new()
	view.name="GroundTexture"
	view.size=Vector2i.ONE*int(WorldData.CHUNK)
	view.disable_3d=true
	view.world_2d=World2D.new()
	view.render_target_update_mode=SubViewport.UPDATE_ONCE
	parent.add_child(view)
	var region:Rect2=content.rect
	var terrain:=WorldData.biome(region.get_center())
	var row:=3 if terrain=="mountains" else (2 if terrain=="coast" else 0)
	if MapDocument.base_enabled() and MapDocument.current.get("generation",2)==2:
		var tile:=ColorRect.new()
		tile.size=Vector2.ONE*512
		var blend:=ShaderMaterial.new()
		blend.shader=load("res://game/shaders/natural_ground.gdshader")
		blend.set_shader_parameter("grass",GroundAtlas.tile(0,0))
		blend.set_shader_parameter("sand",GroundAtlas.tile(2,0))
		blend.set_shader_parameter("stone",GroundAtlas.tile(3,0))
		blend.set_shader_parameter("climate",NaturalLandscape.texture())
		blend.set_shader_parameter("world_origin",region.position)
		tile.material=blend
		view.add_child(tile)
	else:
		var tiles:=TileMapLayer.new()
		tiles.tile_set=GroundAtlas.biome_tiles(row)
		tiles.scale=Vector2.ONE*(64.0/GroundAtlas.TILE_PIXELS)
		tiles.modulate=WorldData.biome_color(region.get_center()) if row==0 else Color.WHITE
		for y in 8:
			for x in 8:tiles.set_cell(Vector2i(x,y),GroundAtlas.grass_variant(content.coord.x*8+x,content.coord.y*8+y),Vector2i.ZERO)
		view.add_child(tiles)
	var roads:=ForestTerrain.new()
	roads.position=-region.position
	roads.build_region(region)
	view.add_child(roads)
	for building in KingdomData.buildings():
		var wall:=KingdomData.building_rect(building)
		if not region.grow(80).intersects(wall):continue
		var shadow:=Polygon2D.new()
		shadow.polygon=PackedVector2Array([wall.position-region.position+Vector2(20,22),Vector2(wall.end.x,wall.position.y)-region.position+Vector2(48,22),wall.end-region.position+Vector2(48,28),Vector2(wall.position.x,wall.end.y)-region.position+Vector2(20,28)])
		shadow.color=Color(0.06,0.09,0.12,0.19)
		view.add_child(shadow)
	var shadows:Dictionary={"view":view,"nodes":{}}
	for tree in content.tree_entries:
		var shape:=Polygon2D.new()
		var points:=PackedVector2Array()
		for i in 12:points.append(tree.body.position-region.position+Vector2(8+cos(i*TAU/12)*tree.size*0.28,6+sin(i*TAU/12)*tree.size*0.09))
		shape.polygon=points
		shape.color=Color(0.08,0.14,0.09,0.22)
		view.add_child(shape)
		shadows.nodes[tree.resource.id]=shape
	ground_shadows[content.coord]=shadows
	var plane:=PlaneMesh.new()
	plane.size=Vector2.ONE*WorldData.CHUNK/64
	var mat:=StandardMaterial3D.new()
	mat.albedo_texture=view.get_texture()
	mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness=1.0
	var node:=MeshInstance3D.new()
	node.mesh=plane
	node.position=Vector3(region.get_center().x/64,-0.025,region.get_center().y/64)
	node.material_override=mat
	node.layers=4
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)

func _trees(parent:Node3D,content:Dictionary)->void:
	var groups:Dictionary={}
	for entry in content.tree_entries:
		var row:int=entry.sprite.get_meta("atlas_row")
		if not groups.has(row):groups[row]=[]
		groups[row].append(entry)
	for row in groups:
		var entries:Array=groups[row]
		if not materials.has(row):
			var texture:=hybrid._bake(entries[0].sprite.sprite_frames.get_frame_texture("default",0))
			var material:=hybrid._forest_material(texture)
			material.set_shader_parameter("day_color",Vector3(game.world.daylight.color.r,game.world.daylight.color.g,game.world.daylight.color.b))
			materials[row]=material
			hybrid.foliage_materials.append(material)
		var quad:=QuadMesh.new()
		quad.size=TreeAtlas.FRAME_SIZE/64
		quad.center_offset=Vector3(0,(TreeAtlas.ANCHOR.y-TreeAtlas.FRAME_SIZE.y/2)/64,0)
		quad.subdivide_depth=6
		var multi:=MultiMesh.new()
		multi.transform_format=MultiMesh.TRANSFORM_3D
		multi.mesh=quad
		multi.instance_count=entries.size()
		for i in entries.size():
			var entry:Dictionary=entries[i]
			var at:=Vector3(entry.body.position.x/64,-entry.sprite.position.y/64,entry.body.position.y/64)
			multi.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ONE*entry.sprite.scale.x),at))
			resource_instances[entry.resource.id]={"multi":multi,"index":i,"coord":content.coord}
		var origin:Vector2=content.rect.position/64
		multi.custom_aabb=AABB(Vector3(origin.x-2,-0.5,origin.y-4),Vector3(12,6,13))
		var node:=MultiMeshInstance3D.new()
		node.multimesh=multi
		node.material_override=materials[row]
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		parent.add_child(node)

func _rocks(parent:Node3D,content:Dictionary)->void:
	if content.rock_entries.is_empty():return
	var veins:Array[Dictionary]=[]
	var multi:=MultiMesh.new()
	multi.transform_format=MultiMesh.TRANSFORM_3D
	multi.use_colors=true
	var sphere:=SphereMesh.new()
	sphere.radial_segments=8
	sphere.rings=4
	multi.mesh=sphere
	multi.instance_count=content.rock_entries.size()
	for i in content.rock_entries.size():
		var entry:Dictionary=content.rock_entries[i]
		var scale:=Vector3(entry.size/50,entry.size/70,entry.size/52)
		multi.set_instance_transform(i,Transform3D(Basis.from_scale(scale),Vector3(entry.body.position.x/64,scale.y*0.5,entry.body.position.y/64)))
		var kind:String=entry.resource.get("type","stone")
		multi.set_instance_color(i,Color({"stone":"92968d","hard_stone":"656c78","copper_ore":"777a71","iron_ore":"737d83","basalt":"454354"}.get(kind,"92968d")).darkened((i%3)*0.08))
		if kind in ["copper_ore","iron_ore"]:
			for chip in 4:
				veins.append({"at":Vector3(entry.body.position.x/64+sin(chip*2.1)*scale.x*0.26,scale.y*(0.68+(chip%2)*0.12),entry.body.position.y/64+cos(chip*2.1)*scale.z*0.30),"color":Color("d78e56") if kind=="copper_ore" else Color("c3d2da"),"id":entry.resource.id})
		resource_instances[entry.resource.id]={"multi":multi,"index":i,"coord":content.coord}
	var node:=MultiMeshInstance3D.new()
	node.multimesh=multi
	var mat:=StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo=true
	mat.roughness=1
	node.material_override=mat
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	if not veins.is_empty():
		var flecks:=MultiMesh.new();flecks.transform_format=MultiMesh.TRANSFORM_3D;flecks.use_colors=true
		var chip_mesh:=BoxMesh.new();chip_mesh.size=Vector3(0.10,0.045,0.08);flecks.mesh=chip_mesh;flecks.instance_count=veins.size()
		for i in veins.size():
			flecks.set_instance_transform(i,Transform3D(Basis(Vector3.UP,i*1.3),veins[i].at));flecks.set_instance_color(i,veins[i].color)
			var resource:Dictionary=resource_instances[veins[i].id]
			if not resource.has("veins"):resource.veins=[]
			resource.veins.append({"multi":flecks,"index":i})
		var ore:=MultiMeshInstance3D.new();ore.multimesh=flecks;ore.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var ore_mat:=StandardMaterial3D.new();ore_mat.vertex_color_use_as_albedo=true;ore_mat.roughness=0.75;ore.material_override=ore_mat;parent.add_child(ore)

func remove_resource(id:String)->void:
	if not resource_instances.has(id):return
	var entry:Dictionary=resource_instances[id]
	entry.multi.set_instance_transform(entry.index,Transform3D(Basis.from_scale(Vector3.ZERO),Vector3.ZERO))
	for vein in entry.get("veins",[]):vein.multi.set_instance_transform(vein.index,Transform3D(Basis.from_scale(Vector3.ZERO),Vector3.ZERO))
	if ground_shadows.has(entry.coord):
		var shadows:Dictionary=ground_shadows[entry.coord]
		if shadows.nodes.has(id):
			shadows.nodes[id].hide()
			shadows.nodes[id].queue_free()
			shadows.nodes.erase(id)
			shadows.view.render_target_update_mode=SubViewport.UPDATE_ONCE

func update_house(id:String)->void:
	if house_models.has(id):house_models[id].queue_free();house_models.erase(id)
	if not game.rpg.houses.has(id):return
	var house:Dictionary=game.rpg.houses[id]
	var node:=Node3D.new()
	node.name=id
	node.position=WorldGrid.point3(game.rpg.home_rect(house).position)
	node.set_meta("grid_pivot","ground_corner")
	add_child(node)
	house_models[id]=node
	if house.stage>=3:
		var model:=BuildingVisual.new()
		model.setup({"id":id,"name":id,"kind":"timber" if house.owner=="player" else "cottage","realm":KingdomData.realm_at(Vector2(house.x,house.y)),"tile":Vector2(house.x,house.y)/64,"size":Vector2(192,128)})
		node.add_child(model)
		_house_label(node,house)
		_localize_house(node)
		return
	var parts:Array[Dictionary]=[]
	var x:float=house.x/64
	var z:float=house.y/64-1
	if house.stage==0:
		for side in [-1,1]:
			for front in [-1,1]:parts.append({"at":Vector3(x+side*1.5,0.3,z+front),"size":Vector3(0.08,0.6,0.08),"color":Color("a69465")})
	else:
		parts.append({"at":Vector3(x,0.08,z),"size":Vector3(3,0.16,2),"color":Color("818278")})
		if house.stage>=1:
			for side in [-1,1]:
				for front in [-1,1]:parts.append({"at":Vector3(x+side*1.42,0.8,z+front*0.92),"size":Vector3(0.13,1.6,0.13),"color":Color("7c5938")})
		if house.stage>=2:
			parts.append({"at":Vector3(x,0.85,z-0.92),"size":Vector3(3,1.5,0.16),"color":Color("bdad8a")})
			for side in [-1,1]:parts.append({"at":Vector3(x+side*1.42,0.85,z),"size":Vector3(0.16,1.5,2),"color":Color("b39a72")})
			parts.append({"at":Vector3(x,0.85,z+0.93),"size":Vector3(3,1.5,0.16),"color":Color("c3b38d")})
			parts.append({"at":Vector3(x,0.65,z+1.025),"size":Vector3(0.6,1.2,0.02),"color":Color("6d4b32")})
	if not parts.is_empty():
		var multi:=MultiMesh.new()
		multi.transform_format=MultiMesh.TRANSFORM_3D
		multi.use_colors=true
		multi.mesh=BoxMesh.new()
		multi.instance_count=parts.size()
		for i in parts.size():
			multi.set_instance_transform(i,Transform3D(Basis.from_scale(parts[i].size),parts[i].at))
			multi.set_instance_color(i,parts[i].color)
		var model:=MultiMeshInstance3D.new()
		model.multimesh=multi
		var mat:=StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo=true
		mat.roughness=1
		model.material_override=mat
		model.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(model)

	if house.stage>=2:
		var texture:Texture2D=load("res://assets/tomate/villages.png")
		var region:Rect2=load("res://game/settlements.gd").REGIONS[2]
		var atlas:=AtlasTexture.new()
		atlas.atlas=texture
		atlas.region=Rect2(region.position+region.size*Vector2(0.12,0.55),region.size*Vector2(0.76,0.45))
		var face:=Sprite3D.new()
		face.texture=hybrid._bake(atlas)
		face.centered=false
		face.offset=Vector2(-face.texture.get_width()/2.0,0)
		face.pixel_size=3.0/face.texture.get_width()
		face.position=Vector3(x,0.02,z+1.035)
		face.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if house_front_material==null:
			house_front_material=hybrid._material(face.texture)
			house_front_material.set_shader_parameter("face_camera",false)
			house_front_material.set_shader_parameter("day_color",Vector3(game.world.daylight.color.r,game.world.daylight.color.g,game.world.daylight.color.b))
			hybrid.facade_materials.append(house_front_material)
		face.material_override=house_front_material
		node.add_child(face)
	_house_label(node,house)
	_localize_house(node)

func _localize_house(node:Node3D)->void:
	for child in node.get_children():
		if child is Node3D:child.position-=node.position

func _house_label(node:Node3D,house:Dictionary)->void:
	var x:float=house.x/64
	var z:float=house.y/64-1
	var label:=Label3D.new()
	label.text=("Seu lar" if house.stage==3 else "Sua obra") if house.owner=="player" else "Casa de "+KingdomData.person(house.owner).get("name","morador")
	label.position=Vector3(x,3.25 if house.stage>=2 else 0.7,z)
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size=0.005
	label.font_size=28
	node.add_child(label)

func _painted_water(parent:Node3D,content:Dictionary)->void:
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count:=0
	for y in 8:
		for x in 8:
			var at:Vector2=content.rect.position+Vector2(x,y)*64
			if MapDocument.terrain_at(at+Vector2.ONE)!="water":continue
			var a:=Vector3(at.x/64,-0.005,at.y/64)
			for offset in [Vector3.ZERO,Vector3(0,0,1),Vector3(1,0,0),Vector3(1,0,0),Vector3(0,0,1),Vector3(1,0,1)]:
				var p:Vector3=a+offset
				surface.set_uv(Vector2(p.x,p.z));surface.set_uv2(Vector2.ZERO)
				surface.set_normal(Vector3.UP);surface.add_vertex(p)
			count+=1
	if count==0:return
	var water:=MeshInstance3D.new()
	water.name="PaintedWater"
	water.mesh=surface.commit()
	water.material_override=hybrid.river_material
	water.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.layers=2
	parent.add_child(water)
