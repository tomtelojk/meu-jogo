class_name ReactiveGrass
extends MultiMeshInstance3D

var hybrid:HybridWorld
var patches:Dictionary={}
var material:ShaderMaterial
var pending:=false
var piece_rects:Dictionary={}
func setup(renderer:HybridWorld)->void:
	hybrid=renderer;name="ReactiveGrass";layers=8;cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	multimesh=MultiMesh.new();multimesh.transform_format=MultiMesh.TRANSFORM_3D
	var shape:=SurfaceTool.new();shape.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in 3:
		var right:=Vector3(cos(blade*PI/3),0,sin(blade*PI/3))*0.045
		var bottom:=Vector3((blade-1)*0.04,0,0)
		var tip:=bottom+Vector3(0.035,0.22+(blade%2)*0.1,0)
		for index in 3:
			shape.set_uv(Vector2(0,1 if index==2 else 0));shape.set_color(Color("769646") if blade%2 else Color("537f3d"));shape.set_normal(Vector3.UP)
			shape.add_vertex([bottom-right,bottom+right,tip][index])
	multimesh.mesh=shape.commit()
	material=ShaderMaterial.new();material.shader=load("res://game/shaders/reactive_grass.gdshader");material_override=material
	hybrid.game.world.chunk_loaded.connect(load_region);hybrid.game.world.chunk_unloaded.connect(unload_region)
	hybrid.game.world.piece_updated.connect(refresh_piece)
	for id in hybrid.game.rpg.construction.pieces:piece_rects[id]=ConstructionCatalog.footprint(hybrid.game.rpg.construction.pieces[id])
	for coord in hybrid.game.world.chunks:load_region(coord,hybrid.game.world.chunks[coord])
func load_region(coord:Vector2i,content:Dictionary)->void:
	var rng:=RandomNumberGenerator.new();rng.seed=coord.x*9173+coord.y*719+1477
	var positions:Array[Transform3D]=[]
	for i in 36:
		var point:Vector2=content.rect.position+Vector2(rng.randf(),rng.randf())*512
		var painted:=MapDocument.terrain_at(point)
		if not painted.is_empty() and painted!="grass":continue
		if WorldData.in_river(point) or WorldData.biome(point) in ["mountains","coast"] or WorldData.path_distance(point)<78:continue
		if not WorldData.can_stand(point,hybrid.game.world.data,16,true):continue
		var covered:=false
		for entry in hybrid.game.rpg.construction.pieces.values():
			if ConstructionCatalog.footprint(entry).grow(6).has_point(point):covered=true;break
		if covered:continue
		var scale:=rng.randf_range(0.75,1.25)
		positions.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*scale),Vector3(point.x/64,0.012,point.y/64)))
	patches[coord]=positions;_queue_flush()
func unload_region(coord:Vector2i)->void:patches.erase(coord);_queue_flush()
func refresh_piece(id:String)->void:
	var rect:Rect2=piece_rects.get(id,Rect2())
	if hybrid.game.rpg.construction.pieces.has(id):
		rect=ConstructionCatalog.footprint(hybrid.game.rpg.construction.pieces[id]);piece_rects[id]=rect
	else:piece_rects.erase(id)
	for y in range(floori(rect.position.y/512),floori(rect.end.y/512)+1):
		for x in range(floori(rect.position.x/512),floori(rect.end.x/512)+1):
			var coord:=Vector2i(x,y)
			if hybrid.game.world.chunks.has(coord):load_region(coord,hybrid.game.world.chunks[coord])
func _queue_flush()->void:
	if pending:return
	pending=true;call_deferred("_flush")
func _flush()->void:
	pending=false
	var rows:Array[Transform3D]=[]
	for patch in patches.values():rows.append_array(patch)
	multimesh.instance_count=rows.size()
	for i in rows.size():multimesh.set_instance_transform(i,rows[i])
