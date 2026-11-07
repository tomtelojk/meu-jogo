class_name ConstructionAudit
extends RefCounted

static func problem(id:String,code:String,message:String,extra:Dictionary={})->Dictionary:
	return {"id":id,"code":code,"message":message}.merged(extra,true)

static func scan(source:Variant,models:Dictionary={},bodies:Dictionary={})->Dictionary:
	var issues:Array=[];var entries:Dictionary={}
	if not source is Dictionary:return {"ok":false,"checked":0,"issues":[problem("","invalid_document","O documento de peças precisa ser um objeto JSON.")]}
	for id in source:
		var entry:Variant=source[id]
		if not entry is Dictionary or not entry.get("kind") is String or ConstructionCatalog.piece(entry.kind).is_empty():issues.append(problem(str(id),"unknown_model","Modelo ausente ou desconhecido."));continue
		if not ResourceProgress.number(entry.get("x")) or not ResourceProgress.number(entry.get("y")) or not ResourceProgress.number(entry.get("turn",0)):
			issues.append(problem(str(id),"invalid_coordinate","Coordenadas ou giro inválidos."));continue
		if not WorldGrid.aligned(entry.x) or not WorldGrid.aligned(entry.y):
			issues.append(problem(str(id),"off_grid","Pivô fora de um vértice do grid.",{"position_cells":[entry.x,entry.y],"snap_cells":[roundi(entry.x),roundi(entry.y)]}))
		if not WorldGrid.aligned(entry.get("turn",0)) or int(entry.get("turn",0)) not in [0,1,2,3]:issues.append(problem(str(id),"rotation","Giro precisa ser 0, 1, 2 ou 3 quartos de volta."))
		if not WorldGrid.aligned(entry.x) or not WorldGrid.aligned(entry.y):continue
		entries[str(id)]=entry
		var occupied:=ConstructionCatalog.footprint(entry)
		if occupied.position.x<WorldGrid.CELL or occupied.position.y<WorldGrid.CELL or occupied.end.x>WorldData.SIZE.x-WorldGrid.CELL or occupied.end.y>WorldData.SIZE.y-WorldGrid.CELL:issues.append(problem(str(id),"world_bounds","Peça fora dos limites de construção do mundo."))
		var expected:=WorldGrid.point3(ConstructionCatalog.pivot(entry));var expected_angle:float=-posmod(int(entry.get("turn",0)),4)*PI/2
		if models.has(id) and is_instance_valid(models[id]):
			var model:Node3D=models[id]
			if model.position.distance_to(expected)>WorldGrid.EPSILON:issues.append(problem(str(id),"model_pivot","O modelo 3D não está no mesmo pivô do save.",{"actual_metres":[model.position.x,model.position.y,model.position.z],"expected_metres":[expected.x,expected.y,expected.z]}))
			if absf(wrapf(model.rotation.y-expected_angle,-PI,PI))>WorldGrid.EPSILON or absf(model.rotation.x)>WorldGrid.EPSILON or absf(model.rotation.z)>WorldGrid.EPSILON:issues.append(problem(str(id),"model_rotation","O giro do modelo diverge do grid."))
			if not model.scale.is_equal_approx(Vector3.ONE):issues.append(problem(str(id),"model_scale","A raiz do modelo precisa ter escala 1, 1, 1."))
		if bodies.has(id) and is_instance_valid(bodies[id]) and bodies[id].position.distance_to(ConstructionCatalog.pivot(entry))>WorldGrid.EPSILON:
			issues.append(problem(str(id),"collision_pivot","O corpo físico e o pivô da peça divergem."))
	var edge_owners:Dictionary={};var slots:Dictionary={}
	for id in entries:
		var entry:Dictionary=entries[id];var definition:=ConstructionCatalog.piece(entry.kind)
		if ConstructionCatalog.is_edge(entry.kind):
			var key:=WorldGrid.edge_key(entry)
			if edge_owners.has(key):issues.append(problem(id,"duplicate_edge","Borda duplicada: "+str(edge_owners[key])+" e "+id+".",{"other":edge_owners[key]}))
			else:edge_owners[key]=id
		else:
			var rect:=ConstructionCatalog.footprint(entry);var start:=WorldGrid.cell_at(rect.position+Vector2.ONE*0.001);var end:=WorldGrid.cell_at(rect.end-Vector2.ONE*0.001)
			for y in range(start.y,end.y+1):
				for x in range(start.x,end.x+1):
					var key:String=definition.layer+":"+WorldGrid.node_key(Vector2i(x,y))
					if slots.has(key):issues.append(problem(id,"overlap","Célula ocupada por "+str(slots[key])+" na mesma camada.",{"other":slots[key],"cell":[x,y]}))
					else:slots[key]=id
	return {"ok":issues.is_empty(),"checked":source.size(),"issues":issues,"grid":{"metres":WorldGrid.CELL_SIZE,"world_units":WorldGrid.CELL,"pivot":"ground_corner","version":WorldGrid.VERSION}}

static func assets()->Dictionary:
	ConstructionCatalog.load_data();var modules:Array=[];var outside:Array=[]
	for kind in ConstructionCatalog.pieces:
		var definition:=ConstructionCatalog.piece(kind);var model:=ConstructionVisual.new();model.setup_piece({"kind":kind,"x":0,"y":0,"turn":0,"open":false})
		var bounds:AABB=model.visual_mesh.transform*model.visual_mesh.get_aabb();var size:=Vector2(ConstructionCatalog.size_cells(kind))*WorldGrid.CELL_SIZE;var errors:Array[String]=[]
		var floor:float=WorldGrid.ROOF_BOTTOM if kind=="roof" else 0.0
		if absf(bounds.position.y-floor)>0.001:errors.append("Base vertical fora do padrão.")
		if absf(bounds.end.y-float(definition.height))>0.001:errors.append("Altura do mesh diverge do catálogo.")
		if ConstructionCatalog.is_edge(kind):
			if absf(bounds.position.x)>0.001 or absf(bounds.end.x-WorldGrid.CELL_SIZE)>0.001 or absf(bounds.size.z-WorldGrid.WALL_THICKNESS)>0.001:errors.append("Parede ou porta excede o segmento ou a espessura comum.")
		elif definition.layer in ["floor","roof"]:
			if absf(bounds.position.x)>0.001 or absf(bounds.position.z)>0.001 or absf(bounds.size.x-size.x)>0.001 or absf(bounds.size.z-size.y)>0.001:errors.append("Superfície não preenche exatamente sua célula.")
		elif bounds.position.x<WorldGrid.WALL_THICKNESS/2-0.001 or bounds.position.z<WorldGrid.WALL_THICKNESS/2-0.001 or bounds.end.x>size.x-WorldGrid.WALL_THICKNESS/2+0.001 or bounds.end.z>size.y-WorldGrid.WALL_THICKNESS/2+0.001:errors.append("Objeto invade a folga reservada às paredes.")
		var row:={"id":kind,"name":definition.name,"source":"game/construction_visual.gd","allocation_metres":[size.x,size.y],"minimum_metres":[bounds.position.x,bounds.position.y,bounds.position.z],"maximum_metres":[bounds.end.x,bounds.end.y,bounds.end.z],"errors":errors,"ok":errors.is_empty()}
		modules.append(row)
		if not errors.is_empty():outside.append(kind)
		model.free()
	var prefabs:Array=[]
	for kind in MapDocument.BUILDINGS:
		var size:=MapDocument.building_size(kind)/WorldGrid.UNITS_PER_METRE
		var fractional:bool=not WorldGrid.aligned(size.x/WorldGrid.CELL_SIZE) or not WorldGrid.aligned(size.y/WorldGrid.CELL_SIZE)
		prefabs.append({"id":kind,"source":"game/building_visual.gd","size_metres":[size.x,size.y],"modular":false,"fractional_size":fractional,"reason":"Prédio completo do editor/cenário; não é uma peça do catálogo modular."})
	for kind in ["library","barracks"]:prefabs.append({"id":kind,"source":"game/building_visual.gd","size_metres":[2.75,2.0],"modular":false,"fractional_size":true,"reason":"Prédio completo da base dos reinos; não é uma peça do catálogo modular."})
	for prefab in prefabs:
		var model:=BuildingVisual.new();model.setup({"id":"audit_"+prefab.id,"name":prefab.id,"kind":prefab.id,"realm":"aurelia","tile":Vector2.ZERO,"size":Vector2(prefab.size_metres[0],prefab.size_metres[1])*WorldGrid.UNITS_PER_METRE,"style":0})
		var bounds:AABB=model.visual_mesh.transform*model.visual_mesh.get_aabb()
		prefab.mesh_size_metres=[bounds.size.x,bounds.size.y,bounds.size.z];prefab.oversized_mesh=bounds.position.x< -0.001 or bounds.position.z< -0.001 or bounds.end.x>prefab.size_metres[0]+0.001 or bounds.end.z>prefab.size_metres[1]+0.001
		model.free()
	var instances:Array=[]
	for building in KingdomData.buildings():
		var rect:=KingdomData.building_rect(building);var size:=rect.size/WorldGrid.UNITS_PER_METRE
		instances.append({"id":building.id,"kind":building.kind,"name":building.name,"size_metres":[size.x,size.y],"position_metres":[rect.position.x/WorldGrid.UNITS_PER_METRE,rect.position.y/WorldGrid.UNITS_PER_METRE],"aligned":WorldGrid.aligned(rect.position.x/WorldGrid.CELL) and WorldGrid.aligned(rect.position.y/WorldGrid.CELL) and WorldGrid.aligned(size.x/WorldGrid.CELL_SIZE) and WorldGrid.aligned(size.y/WorldGrid.CELL_SIZE)})
	return {"ok":outside.is_empty(),"modules":modules,"outside_standard":outside,"environment_prefabs":prefabs,"environment_instances":instances}

static func unwrap(document:Variant)->Variant:
	if not document is Dictionary:return document
	if document.get("rpg") is Dictionary:return document.rpg.get("construction",{})
	if document.get("construction") is Dictionary:return document.construction
	return document

static func saved(document:Variant)->Dictionary:
	var state:Variant=unwrap(document)
	if not state is Dictionary:return scan(state)
	var report:=scan(state.get("pieces",{}))
	if not state.get("pieces",{}) is Dictionary:return report
	var version:int=int(state.get("grid_version",1)) if ResourceProgress.number(state.get("grid_version",1)) else 1
	if version<WorldGrid.VERSION and not state.get("pieces",{}).is_empty():
		report.ok=false;report.issues.push_front(problem("","legacy_grid","Save anterior ao pivô de canto; será migrado ao carregar, com cópia do arquivo original."))
	return report

static func write_report(path:String,report:Dictionary)->Error:
	var absolute:=ProjectSettings.globalize_path(path)
	var directory:=DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if directory!=OK:return directory
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null:return FileAccess.get_open_error()
	file.store_string(JSON.stringify(report,"  "));file.flush();return file.get_error()
