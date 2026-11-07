class_name PlacementAudit
extends RefCounted

static func _entries(document:Dictionary,save:Dictionary)->Array[Dictionary]:
	var result:Array[Dictionary]=KingdomData.buildings_for_document(document)
	var houses:Variant=save.get("rpg",{}).get("houses",{})
	var format:=RPGState.new()
	if houses is Dictionary:
		for id in houses:
			var home:Variant=houses[id]
			if not home is Dictionary or not home.get("owner") is String or not ResourceProgress.number(home.get("x")) or not ResourceProgress.number(home.get("y")):continue
			var entry:=HouseKit.from_home(id,home,format);entry.source="save";result.append(entry)
	return result

static func context(document:Dictionary,save:Dictionary={})->Dictionary:
	var ctx:=PlacementValidator.map_context(document)
	ctx.buildings=ctx.buildings.filter(func(entry:Dictionary):return entry.get("bridge",false))
	for entry in _entries(document,save):ctx.buildings.append({"id":entry.id,"rect":KingdomData.building_rect(entry),"decoration":true})
	var pieces:Variant=save.get("rpg",{}).get("construction",{}).get("pieces",{})
	if pieces is Dictionary:
		for id in pieces:
			var entry:Variant=pieces[id]
			if entry is Dictionary and not ConstructionCatalog.piece(entry.get("kind","")).is_empty() and ResourceProgress.number(entry.get("x")) and ResourceProgress.number(entry.get("y")):
				ctx.buildings.append({"id":id,"rect":ConstructionCatalog.footprint(entry)})
	return ctx

static func scan(document:Dictionary,save:Dictionary={})->Dictionary:
	var ctx:=context(document,save);var cache:Dictionary={};var issues:Array=[]
	var entries:=_entries(document,save)
	for entry in entries:
		var rect:=KingdomData.building_rect(entry)
		var resources:Array=ctx.resources.duplicate()
		ctx.resources=resources+PlacementValidator.nearby_resources(document,rect.grow(64),ctx,cache)
		var checked:=PlacementValidator.validate(rect,ctx,{"ignore_id":entry.id,"decoration":true})
		ctx.resources=resources
		if not checked.ok:issues.append({"id":entry.id,"name":entry.name,"source":entry.get("source","map"),"code":checked.code,"message":checked.message,"obstacle":checked.obstacle,"position_world":[entry.tile.x*64,entry.tile.y*64],"size_metres":[rect.size.x/64,rect.size.y/64]})
	var rules:PlacementRules=ctx.rules
	return {"ok":issues.is_empty(),"checked":entries.size(),"issues":issues,"road_curves":ctx.roads.roads.size(),"painted_road_cells":ctx.roads.cells.size(),"generation":document.get("generation",2),"margins_metres":{"road":rules.road_margin,"water":rules.water_margin,"rock":rules.rock_margin,"building":rules.building_margin,"decorations":rules.protect_decorations}}

static func begin_repair(document:Dictionary,save:Dictionary={},radius:float=-1)->Dictionary:
	var out:=document.duplicate(true);var journey:=save.duplicate(true)
	var by_id:Dictionary={}
	for entry in _entries(out,journey):by_id[entry.id]=entry
	return {"document":out,"save":journey,"before":scan(out,journey),"context":context(out,journey),"cache":{},"moved":[],"unresolved":[],"by_id":by_id,"cursor":0,"radius":radius}

static func repair_step(state:Dictionary,batch:int=2)->bool:
	for i in batch:
		if state.cursor>=state.before.issues.size():return true
		var issue:Dictionary=state.before.issues[state.cursor];state.cursor+=1
		_repair_one(state,issue)
	return state.cursor>=state.before.issues.size()

static func _repair_one(state:Dictionary,issue:Dictionary)->void:
	var out:Dictionary=state.document;var journey:Dictionary=state.save;var ctx:Dictionary=state.context
	var cache:Dictionary=state.cache;var by_id:Dictionary=state.by_id
	var moved:Array=state.moved;var unresolved:Array=state.unresolved;var radius:float=state.radius
	var entry:Dictionary=by_id[issue.id]
	var resources:Array=ctx.resources.duplicate()
	var distance:float=ctx.rules.units("relocation_radius") if radius<0 else radius
	ctx.resources=resources+PlacementValidator.nearby_resources(out,KingdomData.building_rect(entry).grow(distance+64),ctx,cache)
	var found:=PlacementValidator.find_site(entry,ctx,distance)
	ctx.resources=resources
	if not found.ok:unresolved.append(issue);return
	var target:Dictionary=found.building
	if entry.get("source")=="save":
		var home:Dictionary=journey.rpg.houses[entry.id]
		home.x=target.tile.x*64;home.y=target.tile.y*64;home.house_turn=target.get("house_turn",0)
	elif String(entry.id).begins_with("base_building_"):
		if not out.has("building_overrides"):out.building_overrides={}
		out.building_overrides[entry.id]={"x":target.tile.x*64,"y":target.tile.y*64,"house_turn":target.get("house_turn",0)}
	else:
		for obj in out.objects:
			if obj.id==entry.id:obj.x=target.tile.x*64;obj.y=target.tile.y*64;obj.house_turn=target.get("house_turn",0);break
	for obstacle in ctx.buildings:
		if obstacle.id==entry.id:obstacle.rect=KingdomData.building_rect(target);break
	if journey.get("interior",{}).get("house")==entry.id:
		var exit:=HouseKit.approach(target);journey.x=exit.x;journey.y=exit.y
	var old_rect:=KingdomData.building_rect(entry)
	var exit:=HouseKit.approach(target)
	for npc in out.objects+out.get("npcs",{}).values():
		if npc.get("kind","npc")!="npc" or not ResourceProgress.number(npc.get("home_x")) or not ResourceProgress.number(npc.get("home_y")):continue
		if old_rect.grow(64).has_point(Vector2(npc.home_x,npc.home_y)):npc.home_x=exit.x;npc.home_y=exit.y
	moved.append({"id":entry.id,"name":entry.name,"from":issue.position_world,"to":[target.tile.x*64,target.tile.y*64],"rotation_degrees":target.get("house_turn",0)*90})

static func finish_repair(state:Dictionary)->Dictionary:
	var after:=scan(state.document,state.save)
	return {"ok":after.ok,"document":state.document,"save":state.save,"before":state.before,"after":after,"moved":state.moved,"unresolved":state.unresolved}

static func repair(document:Dictionary,save:Dictionary={},radius:float=-1)->Dictionary:
	var state:=begin_repair(document,save,radius)
	while not repair_step(state,32):pass
	return finish_repair(state)
