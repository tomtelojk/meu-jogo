class_name RoadManager
extends RefCounted

signal changed

## Authoritative curves + painted road cells, shared by rendering and placement.
## Queries use whole rectangles against swept segments, including round caps.
const HALF_WIDTH:=44.0
const BORDER_WIDTH:=7.5
const ROAD_MATERIALS:=["dirt","stone","moss"]
const BUCKET:=512.0
const TILE:=WorldGrid.CELL
var roads:Array[Dictionary]=[]
var areas:Array[Dictionary]=[]
var cells:Dictionary={}
var terrain:Dictionary={}
var segment_grid:Dictionary={}
var segments:Array[Dictionary]=[]
static var _cached:RoadManager
static var _revision:=-1

static func current()->RoadManager:
	if _cached==null or _revision!=MapDocument.revision:
		_cached=for_document(MapDocument.current);_revision=MapDocument.revision
	return _cached

static func for_document(document:Dictionary)->RoadManager:
	var manager:=RoadManager.new()
	if document.get("base")=="reinos":
		var paths:=KingdomData.paths(int(document.get("generation",2)))
		for i in paths.size():manager.register_path("road_"+str(i),paths[i])
		for town in KingdomData.SETTLEMENTS:manager.register_plaza(town.id,town.position)
	manager.set_terrain(document.get("terrain",{}))
	return manager

func register_path(id:String,points:PackedVector2Array,half_width:float=HALF_WIDTH,border:float=BORDER_WIDTH,notify:bool=true)->void:
	if points.size()<2 or half_width<=0:return
	var curve:=Curve3D.new()
	for point in points:
		if not point.is_finite():return
		curve.add_point(WorldGrid.point3(point))
	var road:={"id":id,"points":points,"curve":curve,"half_width":half_width,"border":maxf(0,border)}
	roads.append(road)
	curve.changed.connect(_curve_updated.bind(id))
	_index_segments(road)
	if notify:changed.emit()

func _index_segments(road:Dictionary)->void:
	var points:PackedVector2Array=road.points
	for i in range(1,points.size()):
		if points[i].distance_squared_to(points[i-1])<0.0001:continue
		var segment:={"id":road.id,"a":points[i-1],"b":points[i],"radius":road.half_width+road.border}
		segment.bounds=Rect2(segment.a.min(segment.b),(segment.b-segment.a).abs()).grow(segment.radius)
		var index:=segments.size();segments.append(segment)
		var bounds:Rect2=segment.bounds
		for y in range(floori(bounds.position.y/BUCKET),floori(bounds.end.y/BUCKET)+1):
			for x in range(floori(bounds.position.x/BUCKET),floori(bounds.end.x/BUCKET)+1):
				var key:=Vector2i(x,y)
				if not segment_grid.has(key):segment_grid[key]=[]
				segment_grid[key].append(index)

func register_curve(id:String,curve:Curve3D,width_metres:float)->void:
	var points:=project_curve(curve)
	register_path(id,points,width_metres*WorldGrid.UNITS_PER_METRE/2.0,BORDER_WIDTH,false)
	for road in roads:
		if road.id!=id:continue
		road.curve.changed.disconnect(_curve_updated.bind(id));road.curve=curve
		curve.changed.connect(_curve_updated.bind(id));break
	changed.emit()

static func project_curve(curve:Curve3D)->PackedVector2Array:
	var points:=PackedVector2Array()
	for point in curve.get_baked_points():points.append(Vector2(point.x,point.z)*WorldGrid.UNITS_PER_METRE)
	return points

func _curve_updated(id:String)->void:
	for road in roads:
		if road.id==id:road.points=project_curve(road.curve);break
	segment_grid.clear();segments.clear()
	for road in roads:_index_segments(road)
	changed.emit()

func register_plaza(id:String,center:Vector2)->void:
	var polygon:=PackedVector2Array()
	for i in 32:polygon.append(center+Vector2(cos(i*TAU/32)*140,sin(i*TAU/32)*100))
	areas.append({"id":"plaza_"+id,"polygon":polygon,"bounds":Rect2(center-Vector2(140,100),Vector2(280,200))})

func set_terrain(painted:Dictionary)->void:
	terrain=painted.duplicate();cells.clear()
	for key in painted:
		if painted[key] in ROAD_MATERIALS:cells[key]=painted[key]

func paths()->Array[PackedVector2Array]:
	var result:Array[PackedVector2Array]=[]
	for road in roads:result.append(road.points)
	return result

static func rect_polygon(rect:Rect2)->PackedVector2Array:
	return PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])

static func segment_hits_rect(a:Vector2,b:Vector2,rect:Rect2)->bool:
	if rect.has_point(a) or rect.has_point(b):return true
	var polygon:=rect_polygon(rect)
	for i in 4:
		if Geometry2D.segment_intersects_segment(a,b,polygon[i],polygon[(i+1)%4])!=null:return true
	return false

static func segment_distance(a:Vector2,b:Vector2,rect:Rect2)->float:
	if segment_hits_rect(a,b,rect):return 0.0
	var distance:=minf(a.distance_to(a.clamp(rect.position,rect.end)),b.distance_to(b.clamp(rect.position,rect.end)))
	for corner in rect_polygon(rect):distance=minf(distance,corner.distance_to(Geometry2D.get_closest_point_to_segment(corner,a,b)))
	return distance

static func polygon_hits_rect(polygon:PackedVector2Array,rect:Rect2)->bool:
	if polygon.is_empty():return false
	if Geometry2D.is_point_in_polygon(rect.get_center(),polygon):return true
	for i in polygon.size():
		if segment_hits_rect(polygon[i],polygon[(i+1)%polygon.size()],rect):return true
	return false

func _indices(rect:Rect2)->Array:
	var found:Dictionary={}
	for y in range(floori(rect.position.y/BUCKET),floori(rect.end.y/BUCKET)+1):
		for x in range(floori(rect.position.x/BUCKET),floori(rect.end.x/BUCKET)+1):
			for index in segment_grid.get(Vector2i(x,y),[]):found[index]=true
	return found.keys()

func _unpainted_parts(rect:Rect2)->Array[Rect2]:
	if terrain.is_empty():return [rect]
	var result:Array[Rect2]=[]
	for y in range(floori(rect.position.y/TILE),floori(rect.end.y/TILE)+1):
		for x in range(floori(rect.position.x/TILE),floori(rect.end.x/TILE)+1):
			var key:="%d,%d"%[x,y]
			if terrain.has(key):continue
			var part:=rect.intersection(Rect2(Vector2(x,y)*TILE,Vector2.ONE*TILE))
			if part.has_area():result.append(part)
	return result

func overlap(rect:Rect2,margin:float=0.0)->Dictionary:
	var query:=rect.grow(maxf(0,margin))
	for y in range(floori(query.position.y/TILE),floori(query.end.y/TILE)+1):
		for x in range(floori(query.position.x/TILE),floori(query.end.x/TILE)+1):
			var key:="%d,%d"%[x,y]
			if cells.has(key) and query.intersects(Rect2(Vector2(x,y)*TILE,Vector2.ONE*TILE),true):return {"id":"tile_"+key,"kind":"road_cell"}
	for index in _indices(query):
		var segment:Dictionary=segments[index]
		if not query.intersects(segment.bounds,true) or segment_distance(segment.a,segment.b,query)>segment.radius:continue
		for part in _unpainted_parts(query):
			if segment_distance(segment.a,segment.b,part)<=segment.radius:return {"id":segment.id,"kind":"road_curve"}
	for area in areas:
		if not query.intersects(area.bounds,true):continue
		for part in _unpainted_parts(query):
			if polygon_hits_rect(area.polygon,part):return {"id":area.id,"kind":"plaza"}
	return {}

func nearest(point:Vector2)->Dictionary:
	var result:Dictionary={};var best:=INF
	var indices:=_indices(Rect2(point-Vector2.ONE*512,Vector2.ONE*1024))
	for index in indices:
		var segment:Dictionary=segments[index]
		var at:=Geometry2D.get_closest_point_to_segment(point,segment.a,segment.b)
		var distance:=at.distance_squared_to(point)
		if distance<best:
			best=distance;result={"id":segment.id,"point":at,"tangent":(segment.b-segment.a).normalized(),"radius":segment.radius,"distance":sqrt(distance)}
	if best>512*512:
		for segment in segments:
			var at:=Geometry2D.get_closest_point_to_segment(point,segment.a,segment.b)
			var distance:=at.distance_squared_to(point)
			if distance<best:best=distance;result={"id":segment.id,"point":at,"tangent":(segment.b-segment.a).normalized(),"radius":segment.radius,"distance":sqrt(distance)}
	return result

func center_distance(point:Vector2)->float:
	var painted:String=terrain.get(MapDocument.cell_key(WorldGrid.cell_at(point)),"")
	if not painted.is_empty():return 0.0 if painted in ROAD_MATERIALS else INF
	var best:=INF
	# Query only local segments; the caller uses this for vegetation and trails.
	for index in _indices(Rect2(point-Vector2.ONE*256,Vector2.ONE*512)):
		var segment:Dictionary=segments[index]
		best=minf(best,point.distance_to(Geometry2D.get_closest_point_to_segment(point,segment.a,segment.b)))
	return best

func make_paths(parent:Node3D)->Node3D:
	var group:=parent.get_node_or_null("RoadManagerPaths") as Node3D
	if group==null:group=Node3D.new();group.name="RoadManagerPaths";parent.add_child(group)
	for road in roads:
		var path:=group.get_node_or_null(NodePath(road.id)) as Path3D
		if path==null:path=Path3D.new();path.name=road.id;group.add_child(path)
		path.curve=road.curve
		path.set_meta("width_metres",road.half_width*2/WorldGrid.UNITS_PER_METRE)
		path.set_meta("border_metres",road.border/WorldGrid.UNITS_PER_METRE)
	return group
