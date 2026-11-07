class_name RelationshipCatalog
extends RefCounted

const GIFTS:=["food","meat","wood","stone","copper","iron","plank","stone_block","copper_ingot","iron_ingot"]
const CLASSES:={"wanderer":"Viajante","artisan":"Artesão","guardian":"Guardião","ranger":"Explorador"}
const FACTIONS:={"free":"Sem bandeira","aurelia":"Aurélia","valverde":"Valverde"}
const TASTES:={"love":{"name":"Ama","affinity":12},"like":{"name":"Gosta","affinity":6},"neutral":{"name":"Neutro","affinity":1},"hate":{"name":"Odeia","affinity":-10}}
static var data:Dictionary={}

static func load_data()->void:
	if not data.is_empty():return
	var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string("res://game/data/relationships.json"))
	assert(parsed is Dictionary,"Dados de relacionamentos ausentes.")
	data=parsed

static func profile(person:Dictionary)->Dictionary:
	load_data()
	var base:String=person.get("appearance",person.get("id",""))
	var own:Dictionary=data.npcs.get(person.get("id",""),data.npcs.get(base,{}))
	var role:String=person.get("role","")
	var group:String=own.get("group",{"Ferreiro":"craft","Artesã":"craft","Construtor":"craft","Comerciante":"trade","Mercador":"trade","Mineiro":"miner","Lenhador":"wood","Herbalista":"nature","Agricultor":"nature","Agricultora":"nature","Pastor":"nature","Cartógrafo":"scholar"}.get(role,"guard" if role.contains("Guarda") else "craft"))
	var result:Dictionary=data.groups[group].duplicate(true)
	result.merge(own,true);result.group=group
	if own.has("quest"):result.quest=data.groups[group].quest.merged(own.quest,true)
	var age:Variant=person.get("age",own.get("age",22+posmod(String(person.id).hash(),37)))
	result.age=clampi(int(age),0,120) if ResourceProgress.number(age) else 22
	result.romance=person.get("romance",true)==true and result.age>=18
	result.story=own.get("story","Guardo pequenas economias para melhorar minha casa e ter mais tempo para os amigos. Quero que meu trabalho deixe algo bom para este povoado.")
	# Different neighbors of the same profession still have individual preferences.
	if own.is_empty() and posmod(String(person.id).hash(),2)==1:
		var loved:String=result.loves[0];result.loves[0]=result.likes[0];result.likes[0]=loved
	return result

static func taste(person:Dictionary,item:String)->String:
	var preferences:=profile(person)
	if item in preferences.loves:return "love"
	if item in preferences.likes:return "like"
	if item in preferences.hates:return "hate"
	return "neutral"

static func dialogue(id:String)->Dictionary:load_data();return data.dialogues.get(id,{})
static func event(id:String)->Dictionary:load_data();return data.events.get(id,{})
static func label(item:String)->String:return ConstructionCatalog.MATERIALS.get(item,item)
