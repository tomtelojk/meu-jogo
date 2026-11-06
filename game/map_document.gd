class_name MapDocument
extends RefCounted

# The editor stores data, never scripts or engine resources. The default world
# remains a template; edited worlds and their adventures have separate IDs.
const ACTIVE_PATH := "user://maps/active.json"
const DRAFT_PATH := "user://maps/draft.json"
const TERRAIN := ["grass", "dirt", "sand", "stone", "moss", "water"]
const BUILDINGS := ["cottage", "timber", "stone_house", "tavern", "forge", "tower", "castle"]
const STRUCTURES := ["cottage", "timber", "stone_house", "tavern", "forge", "tower", "castle", "bridge"]
const NATURE := ["tree", "autumn_tree", "rock"]
const ANIMALS := ["cow", "chicken", "deer", "rabbit", "boar"]
const FACES := ["bento", "lia", "tomas", "iris", "eron", "aurel", "caio", "mila", "farmer"]
const LIMIT := Vector2(16000,12800)
static var current: Dictionary = original()
static var points: Dictionary = {}
static var _mask: Texture2D
static var revision := 0

static func original() -> Dictionary:
	return {"version":1,"id":"reinos","name":"Entre os dois reinos","base":"reinos","generation":2,"spawn":[4608,4480],"terrain":{},"objects":[],"removed":{},"npcs":{}}

static func blank() -> Dictionary:
	var doc := original()
	doc.id = new_id()
	doc.name = "Meu novo mundo"
	doc.base = "vazio"
	doc.spawn = [8000,6400]
	return doc

static func new_id() -> String:
	return "mapa_%d_%d" % [int(Time.get_unix_time_from_system()),Time.get_ticks_usec() % 1000000]

static func base_enabled() -> bool:
	return current.base == "reinos"

static func cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x,cell.y]

static func cell_at(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x/64),floori(point.y/64))

static func terrain_at(point: Vector2) -> String:
	return current.terrain.get(cell_key(cell_at(point)), "")

static func spawn_point() -> Vector2:
	return Vector2(current.spawn[0],current.spawn[1])

static func activate(doc: Dictionary) -> bool:
	var checked := validate(doc)
	if not checked.ok:return false
	current = checked.document
	revision+=1
	points.clear()
	_mask = null
	for obj in current.objects:
		if obj.kind == "npc":_index_npc(obj.id,obj)
	for id in current.npcs:
		_index_npc(id,current.npcs[id])
	return true

static func _index_npc(id: String, obj: Dictionary) -> void:
	for place in ["home","work","social"]:
		points["map_"+id+"_"+place] = Vector2(obj.get(place+"_x",obj.x),obj.get(place+"_y",obj.y))

static func removed(id: String) -> bool:
	return current.removed.has(id)

static func custom_buildings() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for obj in current.objects:
		if obj.kind in BUILDINGS:
			result.append({"id":obj.id,"name":obj.name,"kind":obj.kind,"style":obj.style,"realm":obj.realm,"tile":Vector2(obj.x,obj.y)/64,"size":building_size(obj.kind),"editor":true})
	return result

static func building_size(kind: String) -> Vector2:
	match kind:
		"bridge":return Vector2(512,96)
		"castle":return Vector2(448,288)
		"tower":return Vector2(128,128)
		"tavern","forge":return Vector2(224,160)
		"timber":return Vector2(192,144)
		_:return Vector2(176,128)

static func bridge_rect(obj:Dictionary) -> Rect2:
	return Rect2(Vector2(obj.x,obj.y)-Vector2(256,48),Vector2(512,96))

static func objects_in(region: Rect2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for obj in current.objects:
		if region.has_point(Vector2(obj.x,obj.y)):result.append(obj)
	return result

static func filter_chunk(content: Dictionary) -> Dictionary:
	for group in ["trees","rocks","animals"]:
		var kept: Array = []
		if base_enabled():
			for obj in content[group]:
				if not removed(obj.id) and terrain_at(obj.position).is_empty():kept.append(obj)
		content[group] = kept
	for obj in objects_in(content.rect):
		var at := Vector2(obj.x,obj.y)
		if obj.kind in NATURE:
			var wood: bool = obj.kind != "rock"
			content["trees" if wood else "rocks"].append({"id":obj.id,"position":at,"radius":12.0 if wood else 14.0,"size":obj.size,"kind":"wood" if wood else "stone","active":true,"variant":obj.kind})
		elif obj.kind in ANIMALS:
			content.animals.append({"id":obj.id,"position":at,"species":obj.kind})
	return content

static func water_mask() -> Texture2D:
	if _mask == null:
		var image := Image.create(250,200,false,Image.FORMAT_RGB8)
		image.fill(Color.BLACK)
		for key in current.terrain:
			var c := parse_cell(key)
			image.set_pixel(c.x,c.y,Color(1,1 if current.terrain[key]=="water" else 0,0))
		_mask = ImageTexture.create_from_image(image)
	return _mask

static func water_rects() -> Array[Rect2]:
	# Merge tile runs in both axes: a large painted lake needs very few shapes.
	var result: Array[Rect2] = []
	var open: Dictionary = {}
	for y in 200:
		var next: Dictionary = {}
		var x := 0
		while x < 250:
			if current.terrain.get(cell_key(Vector2i(x,y)),"") != "water":x+=1;continue
			var start := x
			while x < 250 and current.terrain.get(cell_key(Vector2i(x,y)),"")=="water":x+=1
			var key := "%d:%d" % [start,x]
			var rect: Rect2 = open.get(key,Rect2(start*64,y*64,(x-start)*64,0))
			rect.size.y+=64
			next[key]=rect
		for key in open:
			if not next.has(key):result.append(open[key])
		open=next
	for rect in open.values():result.append(rect)
	return result

static func parse_cell(value: String) -> Vector2i:
	return Vector2i(int(value.get_slice(",",0)),int(value.get_slice(",",1)))

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _position(x: Variant, y: Variant) -> bool:
	return _number(x) and _number(y) and x>=64 and y>=64 and x<=LIMIT.x-64 and y<=LIMIT.y-64

static func validate(raw: Variant) -> Dictionary:
	var fail := {"ok":false,"message":"Mapa inválido. Use um JSON exportado pelo editor do jogo."}
	if not raw is Dictionary or raw.get("version") != 1:return fail
	var id: Variant = raw.get("id","")
	if not id is String or id.is_empty() or id.length()>80 or not id.is_valid_identifier():return fail
	if not raw.get("base") in ["reinos","vazio"]:return fail
	if not raw.get("name") is String or raw.name.length()>80:return fail
	var spawn: Variant = raw.get("spawn")
	if not spawn is Array or spawn.size()!=2 or not _position(spawn[0],spawn[1]):return fail
	for field in ["terrain","removed","npcs"]:
		if not raw.get(field) is Dictionary:return fail
	if raw.terrain.size()>50000 or raw.removed.size()>20000 or raw.npcs.size()>200:return fail
	for key in raw.terrain:
		if not key is String or key.count(",")!=1 or not raw.terrain[key] in TERRAIN:return fail
		var pieces: PackedStringArray = key.split(",")
		if not pieces[0].is_valid_int() or not pieces[1].is_valid_int():return fail
		var cell := parse_cell(key)
		if cell.x<0 or cell.y<0 or cell.x>=250 or cell.y>=200 or key!=cell_key(cell):return fail
	if not raw.get("objects") is Array or raw.objects.size()>5000:return fail
	var clean := original()
	clean.id=id;clean.name=raw.name;clean.base=raw.base;clean.spawn=spawn.duplicate()
	clean.generation=2 if raw.get("generation",2 if id=="reinos" else 1)==2 else 1
	clean.terrain=raw.terrain.duplicate()
	var ids: Dictionary = {}
	for entry in raw.objects:
		if not entry is Dictionary or not entry.get("kind","") in STRUCTURES+NATURE+ANIMALS+["npc"]:return fail
		if not entry.get("id") is String or not entry.id.begins_with("obj_") or not entry.id.is_valid_identifier() or ids.has(entry.id):return fail
		if not _position(entry.get("x"),entry.get("y")):return fail
		var obj := clean_object(entry)
		if obj.is_empty():return fail
		if obj.kind in STRUCTURES:
			var rect := Rect2(Vector2(obj.x,obj.y)-Vector2(building_size(obj.kind).x/2,building_size(obj.kind).y),building_size(obj.kind))
			if obj.kind=="bridge":rect=bridge_rect(obj)
			if not Rect2(Vector2(32,32),LIMIT-Vector2(64,64)).encloses(rect):return fail
		clean.objects.append(obj);ids[obj.id]=true
	for key in raw.removed:
		if not key is String or key.length()>100:return fail
		clean.removed[key]=true
	for key in raw.npcs:
		if not key is String or key.length()>80 or not raw.npcs[key] is Dictionary:return fail
		var npc: Dictionary = raw.npcs[key].merged({"id":key,"kind":"npc"},true)
		if not _position(npc.get("x"),npc.get("y")):return fail
		var checked := clean_object(npc)
		if checked.is_empty():return fail
		clean.npcs[key]=checked
	return {"ok":true,"document":clean,"message":"Mapa carregado."}

static func clean_object(entry: Dictionary) -> Dictionary:
	var obj := {"id":entry.id,"kind":entry.kind,"x":float(entry.x),"y":float(entry.y),"name":str(entry.get("name","Morador" if entry.kind=="npc" else "Construção")).left(60),"style":0,"realm":"aurelia","size":130.0,"appearance":"farmer"}
	var style: Variant = entry.get("style",0)
	var size: Variant = entry.get("size",130)
	if not _number(style) or not _number(size):return {}
	obj.style=clampi(int(style),0,5)
	obj.size=clampf(float(size),32,220)
	obj.realm="valverde" if entry.get("realm")=="valverde" else "aurelia"
	obj.appearance=entry.get("appearance","farmer") if entry.get("appearance","farmer") in FACES else "farmer"
	if obj.kind=="npc":
		for place in ["home","work","social"]:
			var x: Variant=entry.get(place+"_x",obj.x)
			var y: Variant=entry.get(place+"_y",obj.y)
			if not _position(x,y):return {}
			obj[place+"_x"]=float(x);obj[place+"_y"]=float(y)
	return obj

static func read_file(path: String) -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	if file==null:return {"ok":false,"message":"Não foi possível abrir esse arquivo."}
	if file.get_length()>8*1024*1024:return {"ok":false,"message":"O mapa ultrapassa o limite de 8 MB."}
	return validate(JSON.parse_string(file.get_as_text()))

static func write_file(path: String, doc: Dictionary) -> Error:
	var checked := validate(doc)
	if not checked.ok:return ERR_INVALID_DATA
	var folder := ProjectSettings.globalize_path(path).get_base_dir()
	var error := DirAccess.make_dir_recursive_absolute(folder)
	if error!=OK:return error
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null:return FileAccess.get_open_error()
	file.store_string(JSON.stringify(checked.document,"\t"))
	file.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(path+".tmp"),ProjectSettings.globalize_path(path))
