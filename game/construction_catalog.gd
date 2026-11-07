class_name ConstructionCatalog
extends RefCounted

const GRID:=WorldGrid.CELL
const CATEGORIES:={"walls":"Paredes e cobertura","floors":"Chão","furniture":"Móveis","stations":"Estações de trabalho"}
const MATERIALS:={"wood":"madeira","stone":"pedra","copper":"cobre","iron":"ferro","plank":"tábuas","stone_block":"blocos de pedra","iron_ingot":"lingotes de ferro","copper_ingot":"lingotes de cobre","food":"provisões","meat":"carne","wedding_ring":"aliança"}
const PROCESSED:=["plank","stone_block","iron_ingot","copper_ingot","wedding_ring"]
static var pieces:Dictionary={}
static var recipes:Dictionary={}

static func load_data()->void:
	if not pieces.is_empty():return
	var document:Variant=JSON.parse_string(FileAccess.get_file_as_string("res://game/data/construction.json"))
	assert(document is Dictionary,"Catálogo de construção ausente.")
	for entry in document.pieces:pieces[entry.id]=entry
	for entry in document.recipes:recipes[entry.id]=entry

static func piece(id:String)->Dictionary:
	load_data();return pieces.get(id,{})

static func recipe(id:String)->Dictionary:
	load_data();return recipes.get(id,{})

static func cell(point:Vector2)->Vector2i:return WorldGrid.cell_at(point)
static func is_edge(kind:String)->bool:return piece(kind).get("snap","")=="edge"
static func size_cells(kind:String)->Vector2i:
	var size:Array=piece(kind).get("size",[1,1]);return Vector2i(size[0],size[1])

static func snap(kind:String,point:Vector2,turn:int=0)->Dictionary:
	# Ray projection can land a few floating-point units below an exact line.
	# This tolerance belongs to cursor snap, never to occupied-cell queries.
	var at:=cell(point+Vector2.ONE*WorldGrid.CELL*WorldGrid.EPSILON)
	if is_edge(kind):
		if posmod(turn,2)==0:at.y=roundi(point.y/GRID);at.x+=1 if posmod(turn,4)==2 else 0
		else:at.x=roundi(point.x/GRID);at.y+=1 if posmod(turn,4)==3 else 0
	else:at=WorldGrid.anchor(at,size_cells(kind),turn)
	return {"kind":kind,"x":at.x,"y":at.y,"turn":posmod(turn,4),"open":false}

static func pivot(entry:Dictionary)->Vector2:return Vector2(entry.x,entry.y)*GRID

static func footprint(entry:Dictionary)->Rect2:
	if is_edge(entry.kind):
		var points:=WorldGrid.edge_points(entry);var start:=WorldGrid.world(points[0]);var end:=WorldGrid.world(points[1]);var half:=WorldGrid.WALL_THICKNESS*WorldGrid.UNITS_PER_METRE/2
		return Rect2(start.min(end)-Vector2(0,half),Vector2(GRID,half*2)) if points[0].y==points[1].y else Rect2(start.min(end)-Vector2(half,0),Vector2(half*2,GRID))
	return WorldGrid.rect(Vector2i(roundi(entry.x),roundi(entry.y)),size_cells(entry.kind),int(entry.get("turn",0)))

static func network(entries:Dictionary)->Dictionary:
	var result:Dictionary={}
	for entry in entries.values():
		if not entry is Dictionary or not is_edge(entry.get("kind","")):continue
		var key:=WorldGrid.edge_key(entry)
		for point in WorldGrid.edge_points(entry):
			var node:=WorldGrid.node_key(point)
			if not result.has(node):result[node]=[]
			if not key in result[node]:result[node].append(key);result[node].sort()
	return result

static func wall_parts(entry:Dictionary,joints:Dictionary={})->Dictionary:
	var points:=WorldGrid.edge_points(entry);var own:=WorldGrid.edge_key(entry);var trims:Array[float]=[0.0,0.0];var posts:Array[Vector2]=[]
	for i in 2:
		var incident:Array=joints.get(WorldGrid.node_key(points[i]),[])
		if incident.size()<2:continue
		trims[i]=WorldGrid.WALL_THICKNESS/2
		if incident[0]==own:posts.append(Vector2(float(i)*WorldGrid.CELL_SIZE,0))
	return {"start":trims[0],"end":WorldGrid.CELL_SIZE-trims[1],"posts":posts}

static func transform_rect(entry:Dictionary,local:Rect2)->Rect2:
	var point:=pivot(entry);var angle:=int(entry.get("turn",0))*PI/2
	var first:=local.position.rotated(angle)*WorldGrid.UNITS_PER_METRE+point
	var result:=Rect2(first,Vector2.ZERO)
	for corner in [local.position+Vector2(local.size.x,0),local.end,local.position+Vector2(0,local.size.y)]:result=result.expand(corner.rotated(angle)*WorldGrid.UNITS_PER_METRE+point)
	return result

static func collision_parts(entry:Dictionary,joints:Dictionary={})->Array[Rect2]:
	var output:Array[Rect2]=[]
	if is_edge(entry.kind):
		var parts:=wall_parts(entry,joints);var width:=WorldGrid.WALL_THICKNESS
		if entry.kind!="door" or not entry.get("open",false):output.append(transform_rect(entry,Rect2(parts.start,-width/2,parts.end-parts.start,width)))
		for point in parts.posts:output.append(transform_rect(entry,Rect2(point-Vector2.ONE*width/2,Vector2.ONE*width)))
		return output
	var size:=Vector2(piece(entry.kind).collision[0],piece(entry.kind).collision[1])
	if size==Vector2.ZERO:return output
	if int(entry.get("turn",0))%2:size=Vector2(size.y,size.x)
	output.append(Rect2(footprint(entry).get_center()-size/2,size));return output

static func collision(entry:Dictionary,joints:Dictionary={})->Rect2:
	var parts:=collision_parts(entry,joints)
	if parts.is_empty():return Rect2()
	var result:Rect2=parts[0]
	for part in parts.slice(1):result=result.merge(part)
	return result

static func reserved(entry:Dictionary)->Array[Rect2]:
	if not is_edge(entry.kind):return [footprint(entry)]
	var closed:=entry.duplicate();closed.open=false;return collision_parts(closed)

static func approach(entry:Dictionary)->Vector2:
	var rect:=footprint(entry)
	return rect.get_center()+Vector2.DOWN.rotated(int(entry.get("turn",0))*PI/2)*(maxf(rect.size.x,rect.size.y)/2+32)

static func cost_text(cost:Dictionary)->String:
	var labels:=PackedStringArray()
	for item in cost:labels.append("%d %s"%[cost[item],MATERIALS.get(item,item)])
	return " · ".join(labels)
