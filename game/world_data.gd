class_name WorldData
extends RefCounted

const TILE := 64.0
const COLS := 250
const ROWS := 200
const SIZE := Vector2(16000,12800)
const CHUNK := 512.0
const SPAWN := Vector2(4608,4480)
const MOTHER := Vector2(1536,1497.6)
const CAMP := Vector2(1376,1817.6)
const SIGN := Vector2(1593.6,1644.8)
const SOLID_LAYER := 1
const WATER_LAYER := 16
const BRIDGE_RAIL_LAYER := 32
const RIVER_HALF_WIDTH := 180.0
const BRIDGE_HEIGHT := 52.0
const BRIDGE_RAMP := 64.0
static var BRIDGE_RECT:Rect2 = _bridge_at_height(1280.0)
static var _segments: Array[PackedVector2Array] = []
static var _bridges: Array[Rect2] = []
static var _bridge_revision := -1
static var _effective_bridges: Array[Rect2] = []
const SEEDS: Array[Dictionary] = [
	{"id": "flores", "name": "Semente da alegria", "place": "Clareira das flores", "position": Vector2(1152, 1664)},
	{"id": "outono", "name": "Semente da memória", "place": "Bosque dourado", "position": Vector2(800, 960)},
	{"id": "pedras", "name": "Semente do tempo", "place": "Pedras antigas", "position": Vector2(1664, 608)},
	{"id": "rio", "name": "Semente da calma", "place": "Margem do riacho", "position": Vector2(2688, 1152)},
	{"id": "jardim", "name": "Semente da esperança", "place": "Jardim esquecido", "position": Vector2(2016, 2048)},
]
const LANDMARKS: Array[Dictionary] = [
	{"id": "mother", "name": "Árvore-mãe", "position": MOTHER, "range": 100.0, "text": "Por muitas primaveras, esta árvore protegeu o bosque. Agora seus galhos descansam. Cinco pequenas sementes podem trazer suas folhas de volta."},
	{"id": "camp", "name": "Um lugar para descansar", "position": CAMP, "range": 85.0, "text": "Alguém deixou um caderno junto à barraca:\n\n“Não é preciso ter pressa. A floresta guarda suas sementes nas flores, no outono, nas pedras antigas, depois do riacho e no jardim ao sul.”"},
	{"id": "sign", "name": "Os caminhos do bosque", "position": SIGN, "range": 65.0, "text": "OESTE · Clareira das flores e Bosque dourado\nNORTE · Árvore-mãe e Pedras antigas\nLESTE · Riacho, depois da ponte\nSUDESTE · Jardim esquecido\n\nAbra o mapa com M para encontrar os brilhos dourados."},
]


static func paths()->Array[PackedVector2Array]:
	if MapDocument.base_enabled():return KingdomData.paths()
	return []

static func path_distance(point:Vector2)->float:
	var painted:=MapDocument.terrain_at(point)
	if not painted.is_empty():return 0.0 if painted in ["dirt","stone","moss"] else INF
	var best:=INF
	for path in paths():
		for i in range(1,path.size()):
			var start:=path[i-1]
			var end:=path[i]
			# Reject far segments before asking Geometry2D for a projection.
			var closest:=point.clamp(start.min(end),start.max(end))
			if point.distance_squared_to(closest)>=best*best:continue
			best=minf(best,point.distance_to(Geometry2D.get_closest_point_to_segment(point,start,end)))
	return best

static func river_x(y:float)->float:
	return 8000+sin(y/800.0)*320+sin(y/1900.0)*160

static func river_width(_y:float)->float:
	return RIVER_HALF_WIDTH

static func _bridge_at_height(y:float)->Rect2:
	var span:=river_width(y)+BRIDGE_RAMP+8
	return Rect2(river_x(y)-span,y-32,span*2,64)

static func bridges()->Array[Rect2]:
	if _bridge_revision==MapDocument.revision:return _effective_bridges
	if _bridges.is_empty():
		_bridges.append(BRIDGE_RECT)
		for y in [4800.0,8192.0,11008.0]:
			_bridges.append(_bridge_at_height(y))
	var result:Array[Rect2]=[]
	if MapDocument.base_enabled():result.append_array(_bridges)
	for obj in MapDocument.current.objects:
		if obj.kind=="bridge":result.append(MapDocument.bridge_rect(obj))
	_effective_bridges=result
	_bridge_revision=MapDocument.revision
	return _effective_bridges

static func bridge_at(point:Vector2)->Rect2:
	for rect in bridges():
		if rect.has_point(point):return rect
	return Rect2()

static func in_river(point:Vector2)->bool:
	var painted:=MapDocument.terrain_at(point)
	if not painted.is_empty():return painted=="water"
	return MapDocument.base_enabled() and absf(point.x-river_x(point.y))<river_width(point.y)

static func is_water(point:Vector2)->bool:
	return in_river(point) and bridge_at(point).size==Vector2.ZERO

static func rails_for_bridge(rect:Rect2)->Array[Rect2]:
	return [Rect2(rect.position+Vector2(0,-6.4),Vector2(rect.size.x,6.4)),Rect2(Vector2(rect.position.x,rect.end.y),Vector2(rect.size.x,6.4))]

static func bridge_rails()->Array[Rect2]:
	var result:Array[Rect2]=[]
	for rect in bridges():result.append_array(rails_for_bridge(rect))
	return result

static func bridge_height(point:Vector2)->float:
	var rect:=bridge_at(point)
	if rect.size==Vector2.ZERO:return 0.0
	return BRIDGE_HEIGHT*clampf(minf(point.x-rect.position.x,rect.end.x-point.x)/BRIDGE_RAMP,0,1)

static func circle_hits_rect(point:Vector2,radius:float,rect:Rect2)->bool:
	return point.distance_squared_to(point.clamp(rect.position,rect.end))<radius*radius

static func generate()->Dictionary:
	var result:={"trees":[],"decor":[],"colliders":[],"collision_grid":{},"solid_rects":[],"solid_grid":{},"npc_markers":[]}
	for building in KingdomData.buildings():result.solid_rects.append(KingdomData.building_rect(building))
	reindex_solids(result)
	return result

static func reindex_solids(data:Dictionary)->void:
	data.solid_grid.clear()
	for rect in data.solid_rects:
		for y in range(floori(rect.position.y/256),floori(rect.end.y/256)+1):
			for x in range(floori(rect.position.x/256),floori(rect.end.x/256)+1):
				var key:=Vector2i(x,y)
				if not data.solid_grid.has(key):data.solid_grid[key]=[]
				data.solid_grid[key].append(rect)

static func index_obstacles(data:Dictionary)->void:
	data.collision_grid.clear()
	for obstacle in data.colliders:
		if not obstacle.get("active",true):continue
		var cell:=Vector2i(floori(obstacle.position.x/128),floori(obstacle.position.y/128))
		if not data.collision_grid.has(cell):data.collision_grid[cell]=[]
		data.collision_grid[cell].append(obstacle)

static func can_stand(point:Vector2,data:Dictionary,radius:float=10.0,allow_swimming:bool=false)->bool:
	if point.x<38.4 or point.y<38.4 or point.x>SIZE.x-38.4 or point.y>SIZE.y-38.4:return false
	var cell:=Vector2i(floori(point.x/256),floori(point.y/256))
	var rects:Array=[]
	for y in range(-1,2):
		for x in range(-1,2):rects.append_array(data.solid_grid.get(cell+Vector2i(x,y),[]))
	for rect in rects:
		if circle_hits_rect(point,radius,rect):return false
	if not allow_swimming:
		for rect in bridge_rails():
			if circle_hits_rect(point,radius,rect):return false
		for offset in [Vector2.ZERO,Vector2(radius,0),Vector2(-radius,0),Vector2(0,radius),Vector2(0,-radius)]:
			if is_water(point+offset):return false
	var grid_cell:=Vector2i(floori(point.x/128),floori(point.y/128))
	for y in range(-1,2):
		for x in range(-1,2):
			for obstacle in data.collision_grid.get(grid_cell+Vector2i(x,y),[]):
				if obstacle.get("active",true) and point.distance_to(obstacle.position)<radius+obstacle.radius:return false
	return true

static func biome(point:Vector2)->String:
	if not MapDocument.base_enabled():return "meadow"
	if point.y<2304 and point.x>3000:return "mountains"
	if point.y>11264:return "coast"
	if (point-Vector2(2400,10240)).length()<1900 or (point-Vector2(13000,10500)).length()<1500 or point.x<2700 and point.y<2600:return "woodland"
	return "plains" if point.x<river_x(point.y) else "meadow"

static func biome_color(point:Vector2)->Color:
	match biome(point):
		"mountains":return Color("a3a5a2")
		"coast":return Color("d4bf8c")
		"plains":return Color("d4d49a")
		_:return Color.WHITE

static func generate_chunk(coord:Vector2i,data:Dictionary)->Dictionary:
	var rect:=Rect2(Vector2(coord)*CHUNK,Vector2.ONE*CHUNK)
	var result:={"coord":coord,"rect":rect,"trees":[],"rocks":[],"animals":[]}
	if not MapDocument.base_enabled():return MapDocument.filter_chunk(result)
	var rng:=RandomNumberGenerator.new()
	var terrain_data:={"solid_grid":data.solid_grid,"collision_grid":{}}
	rng.seed=(coord.x*73856093)^(coord.y*19349663)^88277
	for y in 8:
		for x in 8:
			rng.seed=((coord.x*8+x)*73856093)^((coord.y*8+y)*19349663)^88277
			var point:=rect.position+Vector2(x+0.2+rng.randf()*0.6,y+0.2+rng.randf()*0.6)*TILE
			var terrain:=biome(point)
			if not can_stand(point,terrain_data,34) or path_distance(point)<85:continue
			var reserved:=false
			for planned in KingdomData.SETTLEMENTS:
				if Rect2(planned.position+Vector2(1472,640),Vector2(384,384)).grow(32).has_point(point):reserved=true;break
				if planned.capital:continue
				if Rect2(KingdomData.point(planned.id+"_plot")-Vector2(128,160),Vector2(256,224)).has_point(point):reserved=true;break
			if reserved:continue
			var town:=KingdomData.nearest_town(point)
			var near_town:bool=point.distance_to(town.position)<1400
			var chance:=0.32 if terrain=="woodland" else (0.025 if near_town else 0.075)
			var id:="%d_%d_%d"%[coord.x,coord.y,y*8+x]
			if terrain!="mountains" and terrain!="coast" and rng.randf()<chance:
				result.trees.append({"id":"wood_"+id,"position":point,"radius":12.0,"size":115.0+rng.randf()*40,"kind":"wood","active":true})
			elif rng.randf()<(0.17 if terrain=="mountains" else 0.025):
				result.rocks.append({"id":"stone_"+id,"position":point,"radius":14.0,"size":30+rng.randf()*15,"kind":"stone","active":true})
	# Dedicated groves and quarries make each town's gathering economy usable.
	for town in KingdomData.SETTLEMENTS:
		for kind in ["wood","stone"]:
			var center:Vector2=KingdomData.point(town.id+"_"+kind)
			for i in 20:
				var point:=center+Vector2((i%5-2)*56,(i/5-1)*56)
				if not rect.has_point(point) or not can_stand(point,terrain_data,24):continue
				var resource:={"id":kind+"_"+town.id+"_"+str(i),"position":point,"radius":12.0 if kind=="wood" else 14.0,"size":130.0 if kind=="wood" else 38.0,"kind":kind,"active":true}
				result["trees" if kind=="wood" else "rocks"].append(resource)
	rng.seed=(coord.x*73856093)^(coord.y*19349663)^4431
	if not rect.has_point(MOTHER) and rng.randf()<0.65:
		var center:=rect.get_center()+Vector2(rng.randf_range(-120,120),rng.randf_range(-120,120))
		if can_stand(center,data,45) and path_distance(center)>100:
			var species:="deer" if biome(center)=="woodland" else ("boar" if rng.randf()<0.3 else "rabbit")
			result.animals.append({"id":"wild_%d_%d"%[coord.x,coord.y],"position":center,"species":species})
	for town in KingdomData.SETTLEMENTS:
		for i in 6:
			var point:Vector2=town.position+Vector2(1536+(i%3)*64,768+(i/3)*96)
			if rect.has_point(point) and can_stand(point,terrain_data,24):result.animals.append({"id":"farm_"+town.id+"_"+str(i),"position":point,"species":"cow" if i<3 else "chicken"})
	return MapDocument.filter_chunk(result)

static func location_name(point:Vector2)->String:
	if not MapDocument.base_enabled():return MapDocument.current.name
	var town:=KingdomData.nearest_town(point)
	if point.distance_to(town.position)<1500:return town.name
	match biome(point):
		"mountains":return "Montanhas de Pedra Alta"
		"coast":return "Costa do Sul"
		"woodland":return "Bosques da fronteira"
		"plains":return "Planícies de Aurélia"
		_:return "Campos de Valverde"
