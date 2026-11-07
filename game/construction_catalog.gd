class_name ConstructionCatalog
extends RefCounted

const GRID:=64.0
const CATEGORIES:={"walls":"Paredes e cobertura","floors":"Chão","furniture":"Móveis","stations":"Estações de trabalho"}
const MATERIALS:={"wood":"madeira","stone":"pedra","copper":"cobre","iron":"ferro","plank":"tábuas","stone_block":"blocos de pedra","iron_ingot":"lingotes de ferro","copper_ingot":"lingotes de cobre"}
const PROCESSED:=["plank","stone_block","iron_ingot","copper_ingot"]
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

static func cell(point:Vector2)->Vector2i:return Vector2i((point/GRID).round())

static func footprint(entry:Dictionary)->Rect2:
	var definition:=piece(entry.kind)
	var size:=Vector2(definition.size[0],definition.size[1])*GRID
	if int(entry.get("turn",0))%2:size=Vector2(size.y,size.x)
	return Rect2(Vector2(entry.x,entry.y)*GRID-Vector2.ONE*GRID/2,size)

static func collision(entry:Dictionary)->Rect2:
	var definition:=piece(entry.kind)
	if entry.kind=="door" and entry.get("open",false):return Rect2()
	var size:=Vector2(definition.collision[0],definition.collision[1])
	if size==Vector2.ZERO:return Rect2()
	if int(entry.get("turn",0))%2:size=Vector2(size.y,size.x)
	return Rect2(footprint(entry).get_center()-size/2,size)

static func approach(entry:Dictionary)->Vector2:
	var rect:=footprint(entry)
	return rect.get_center()+Vector2.DOWN.rotated(int(entry.get("turn",0))*PI/2)*(maxf(rect.size.x,rect.size.y)/2+32)

static func cost_text(cost:Dictionary)->String:
	var labels:=PackedStringArray()
	for item in cost:labels.append("%d %s"%[cost[item],MATERIALS.get(item,item)])
	return " · ".join(labels)
