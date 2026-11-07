class_name FactionCatalog
extends RefCounted

static var data:Dictionary={}

static func load_data()->void:
	if not data.is_empty():return
	var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string("res://game/data/factions.json"))
	assert(parsed is Dictionary,"Dados de facções ausentes.")
	data=parsed

static func faction(id:String)->Dictionary:load_data();return data.factions.get(id,{})
static func guild(id:String)->Dictionary:load_data();return data.guilds.get(id,{})
static func territory(id:String)->Dictionary:load_data();return data.territories.get(id,{})
static func other(id:String)->String:return "valverde" if id=="aurelia" else "aurelia"
static func standing(value:int)->String:
	if value<=-30:return "Hostil"
	if value>=70:return "Herói"
	if value>=30:return "Aliado"
	return "Neutro"
static func price_factor(value:int)->float:
	if value>=70:return 0.8
	if value>=30:return 0.9
	if value<0:return 1.25
	return 1.0
static func rank(marks:int)->int:
	var result:=0;load_data()
	for i in data.ranks.size():
		if marks>=int(data.ranks[i].marks):result=i
	return result
static func rank_name(marks:int)->String:load_data();return data.ranks[rank(marks)].name
static func headquarters(id:String)->Vector2:
	var entry:=guild(id)
	return KingdomData.point(entry.anchor) if not entry.is_empty() else Vector2(INF,INF)
static func town(id:String)->Dictionary:
	for entry in KingdomData.towns():
		if entry.id==id:return entry
	return {}
static func town_faction(rpg:RPGState,id:String)->String:
	var entry:=town(id)
	if entry.is_empty():
		for building in KingdomData.buildings():
			if building.id==id and building.get("editor",false) and building.kind in ["forge","tavern"]:return building.realm
		return ""
	return rpg.politics.control(id) if not territory(id).is_empty() else entry.realm
static func service_name(id:String)->String:
	var entry:=town(id)
	if not entry.is_empty():return entry.name
	for building in KingdomData.buildings():
		if building.id==id:return building.name
	return id
static func guard(profile:Dictionary)->bool:
	# Capital woodcutters also serve in the local volunteer watch.
	return String(profile.get("role","")).contains("Guarda") or profile.get("id","") in ["aurelia_resident_0","valverde_resident_0"]
