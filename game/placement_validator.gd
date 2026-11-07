class_name PlacementValidator
extends RefCounted

const LIMIT:=Vector2(16000,12800)
const DECORATION_MARGIN:=0.5*WorldGrid.UNITS_PER_METRE
static var river_strips:Dictionary={}

static func fail(code:String,message:String,id:String="")->Dictionary:
	return {"ok":false,"code":code,"message":message,"obstacle":id}

static func facing_turn(direction:Vector2)->int:
	var directions:=[Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT]
	var best:=0
	for i in 4:
		if direction.dot(directions[i])>direction.dot(directions[best]):best=i
	return best

static func validate(rect:Rect2,context:Dictionary,options:Dictionary={})->Dictionary:
	if not rect.position.is_finite() or not rect.size.is_finite() or not rect.has_area():return fail("invalid","Área de construção inválida.")
	var rules:PlacementRules=context.get("rules",PlacementRules.defaults())
	var envelope:=rect.grow(DECORATION_MARGIN if options.get("decoration",false) and rules.protect_decorations else 0)
	if not Rect2(Vector2.ONE*WorldGrid.CELL,LIMIT-Vector2.ONE*WorldGrid.CELL*2).encloses(envelope):return fail("bounds","Terreno fora dos limites do continente.")
	var roads:RoadManager=context.get("roads")
	if roads!=null and not options.get("bridge",false) and not options.get("allow_roads",false):
		var road:=roads.overlap(envelope,rules.units("road_margin"))
		if not road.is_empty():return fail("road","Deixe a estrada e sua margem livres.",road.id)
	if not options.get("bridge",false) and water_overlap(envelope.grow(rules.units("water_margin")),context):return fail("water","Mantenha distância da água e das margens do rio.")
	var margin:=rules.units("building_margin")
	for entry in context.get("buildings",[]):
		if entry.id==options.get("ignore_id",""):continue
		var other:Rect2=entry.rect.grow(DECORATION_MARGIN if entry.get("decoration",false) and rules.protect_decorations else 0)
		if envelope.grow(margin).intersects(other,true):return fail("building","Há outra construção muito perto.",entry.id)
	for entry in context.get("reservations",[]):
		if entry.get("owner","")==options.get("owner","player"):continue
		if envelope.grow(margin).intersects(entry.rect,true):return fail("reserved","Este terreno está reservado para um morador.",entry.id)
	for resource in context.get("resources",[]):
		if not resource.get("active",true):continue
		var radius:float=resource_radius(resource)+rules.units("rock_margin")
		if resource.position.distance_to(resource.position.clamp(envelope.position,envelope.end))<=radius:return fail("rock" if resource.get("kind","stone")!="wood" else "tree","Retire as árvores e pedras, preservando a margem do terreno.",str(resource.get("id","")))
	return {"ok":true,"code":"clear","message":"Terreno livre."}

static func resource_radius(resource:Dictionary)->float:
	var radius:float=float(resource.get("radius",14.0))
	if resource.get("kind","stone")!="wood":radius=maxf(radius,float(resource.get("size",0))*WorldGrid.UNITS_PER_METRE/100.0)
	return radius

## Check every painted cell and every 32-unit strip used by the river mesh.
## A narrow inlet inside a large footprint cannot hide between corner probes.
static func water_overlap(rect:Rect2,context:Dictionary)->bool:
	var terrain:Dictionary=context.get("terrain",{})
	var base:bool=context.get("base","reinos")=="reinos"
	var generation:int=context.get("generation",2)
	for y in range(floori(rect.position.y/WorldGrid.CELL),floori(rect.end.y/WorldGrid.CELL)+1):
		for x in range(floori(rect.position.x/WorldGrid.CELL),floori(rect.end.x/WorldGrid.CELL)+1):
			var cell:=Rect2(Vector2(x,y)*WorldGrid.CELL,Vector2.ONE*WorldGrid.CELL)
			if not cell.intersects(rect,true):continue
			var kind:String=terrain.get("%d,%d"%[x,y],"")
			if kind=="water":return true
			if not kind.is_empty() or not base:continue
			var part:=cell.intersection(rect)
			for strip in range(floori(part.position.y/32.0),floori(part.end.y/32.0)+1):
				var polygon:=river_strip(strip,generation)
				if part.end.x<minf(polygon[0].x,polygon[3].x) or part.position.x>maxf(polygon[1].x,polygon[2].x):continue
				if RoadManager.polygon_hits_rect(polygon,part):return true
	return false

static func river_strip(index:int,generation:int)->PackedVector2Array:
	var key:=Vector2i(index,2 if generation>=2 else 1)
	if not river_strips.has(key):
		var y0:=index*32.0;var y1:=y0+32.0
		var c0:=NaturalLandscape.river_center(y0) if generation>=2 else 8000+sin(y0/800.0)*320+sin(y0/1900.0)*160
		var c1:=NaturalLandscape.river_center(y1) if generation>=2 else 8000+sin(y1/800.0)*320+sin(y1/1900.0)*160
		var r0:=NaturalLandscape.river_width(y0) if generation>=2 else 180.0
		var r1:=NaturalLandscape.river_width(y1) if generation>=2 else 180.0
		river_strips[key]=PackedVector2Array([Vector2(c0-r0,y0),Vector2(c0+r0,y0),Vector2(c1+r1,y1),Vector2(c1-r1,y1)])
	return river_strips[key]

static func water_at(point:Vector2,document:Dictionary)->bool:
	var kind:String=document.get("terrain",{}).get(MapDocument.cell_key(WorldGrid.cell_at(point)),"")
	if not kind.is_empty():return kind=="water"
	if document.get("base")!="reinos":return false
	var natural:bool=int(document.get("generation",2))>=2
	var center:=NaturalLandscape.river_center(point.y) if natural else 8000+sin(point.y/800.0)*320+sin(point.y/1900.0)*160
	return absf(point.x-center)<(NaturalLandscape.river_width(point.y) if natural else 180.0)

static func map_context(document:Dictionary,resources:Array=[],manager:RoadManager=null)->Dictionary:
	var buildings:Array=[]
	for building in KingdomData.buildings_for_document(document):buildings.append({"id":building.id,"rect":KingdomData.building_rect(building),"decoration":true})
	if document.get("base")=="reinos":
		var bridges:=WorldData.bridges_for_document(document)
		for i in 4:buildings.append({"id":"bridge_base_"+str(i),"rect":bridges[i],"bridge":true})
	for obj in document.get("objects",[]):
		if obj.kind=="bridge":buildings.append({"id":obj.id,"rect":MapDocument.bridge_rect(obj),"bridge":true})
	var all_resources:=resources.duplicate()
	var present:Dictionary={}
	for resource in resources:present[resource.get("id","")]=true
	for obj in document.get("objects",[]):
		if obj.kind in MapDocument.NATURE and not present.has(obj.id):all_resources.append({"id":obj.id,"position":Vector2(obj.x,obj.y),"radius":12.0 if obj.kind in ["tree","autumn_tree"] else 14.0,"size":obj.size if obj.kind in ["tree","autumn_tree"] else minf(55,obj.size*0.3),"kind":"wood" if obj.kind in ["tree","autumn_tree"] else "stone"})
	var reservations:Array=[]
	if document.get("base")=="reinos":
		for town in KingdomData.SETTLEMENTS:reservations.append({"id":"farm_"+town.id,"owner":"public_farm","rect":Rect2(town.position+Vector2(1472,640),Vector2(384,384))})
	return {"roads":RoadManager.for_document(document) if manager==null else manager,"buildings":buildings,"resources":all_resources,"terrain":document.get("terrain",{}),"base":document.get("base","vazio"),"generation":int(document.get("generation",2)),"rules":PlacementRules.defaults(),"reservations":reservations}

static func runtime_context(rpg:RPGState,resources:Array=[],include_modules:bool=true)->Dictionary:
	var context:=map_context(MapDocument.current,resources,RoadManager.current())
	for id in rpg.houses:context.buildings.append({"id":id,"rect":rpg.home_rect(rpg.houses[id]),"decoration":true})
	if include_modules:
		for id in rpg.construction.pieces:context.buildings.append({"id":id,"rect":ConstructionCatalog.footprint(rpg.construction.pieces[id])})
	var reservations:Array=context.reservations
	for town in KingdomData.towns():
		if town.capital:continue
		var at:=KingdomData.point(town.id+"_plot")
		reservations.append({"id":"plot_"+town.id,"owner":town.id+"_resident_0","rect":Rect2(at-Vector2(96,128),Vector2(192,128))})
	context.reservations=reservations
	context.resources=context.resources.filter(func(resource:Dictionary):return not rpg.depleted.has(resource.get("id","")))
	return context

static func nearby_resources(document:Dictionary,rect:Rect2,context:Dictionary,cache:Dictionary)->Array:
	var result:Array=[]
	if document.get("base")!="reinos":return result
	if not context.has("solid_data"):
		var data:={"solid_rects":[],"solid_grid":{},"collision_grid":{}}
		for entry in context.buildings:data.solid_rects.append(entry.rect)
		WorldData.reindex_solids(data);context.solid_data=data
		context.places=KingdomData.places_for_document(document)
	for y in range(floori(rect.position.y/WorldData.CHUNK),floori(rect.end.y/WorldData.CHUNK)+1):
		for x in range(floori(rect.position.x/WorldData.CHUNK),floori(rect.end.x/WorldData.CHUNK)+1):
			var coord:=Vector2i(x,y)
			if not cache.has(coord):
				var chunk:=WorldData.generate_chunk(coord,context.solid_data,document,context)
				cache[coord]=chunk.trees+chunk.rocks
			result.append_array(cache[coord])
	return result

static func find_site(data:Dictionary,context:Dictionary,radius:float=-1,orient:bool=true)->Dictionary:
	var rules:PlacementRules=context.get("rules",PlacementRules.defaults())
	var limit:=ceili((rules.units("relocation_radius") if radius<0 else radius)/WorldGrid.CELL)
	var max_distance:float=rules.units("relocation_radius") if radius<0 else radius
	var origin:=KingdomData.building_rect(data).get_center()
	var roads:RoadManager=context.get("roads")
	for ring in range(limit+1):
		for y in range(-ring,ring+1):
			for x in range(-ring,ring+1):
				if ring>0 and absi(x)!=ring and absi(y)!=ring:continue
				var candidate:=data.duplicate(true)
				var center:=origin+Vector2(x,y)*WorldGrid.CELL
				if center.distance_to(origin)>max_distance:continue
				if orient and roads!=null and candidate.kind in HouseKit.KINDS:
					var near:=roads.nearest(center)
					if not near.is_empty():candidate.house_turn=facing_turn(near.point-center)
					if candidate.has("house_style"):candidate.size=HouseKit.size_for(candidate.house_style,HouseKit.seed_for(candidate),candidate.house_turn)
				var size:Vector2=candidate.size
				var corner:=(center-size/2).snapped(Vector2.ONE*WorldGrid.CELL)
				candidate.tile=Vector2(corner.x+size.x/2,corner.y+size.y)/WorldGrid.UNITS_PER_METRE
				if KingdomData.building_rect(candidate).get_center().distance_to(origin)>max_distance:continue
				var valid:=validate(KingdomData.building_rect(candidate),context,{"ignore_id":data.get("id",""),"decoration":true,"bridge":candidate.kind=="bridge","owner":data.get("owner","player")})
				if valid.ok:return {"ok":true,"building":candidate}
	return {"ok":false,"message":"Não há terreno livre dentro do raio de realocação."}
