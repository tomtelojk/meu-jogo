class_name ResourceRules
extends RefCounted

# All destructibles use the same health, tool, loot and regeneration contract.
const DEFINITIONS:={
	"wood":{"name":"Árvore","hp":36,"tool":"axe","tier":1,"days":3,"skill":"woodcutting","drops":[{"item":"wood","min":5,"max":7,"chance":1.0}]},
	"stone":{"name":"Rocha","hp":40,"tool":"pickaxe","tier":1,"days":5,"skill":"mining","drops":[{"item":"stone","min":4,"max":6,"chance":1.0}]},
	"hard_stone":{"name":"Rocha dura","hp":70,"tool":"pickaxe","tier":2,"days":5,"skill":"mining","drops":[{"item":"stone","min":7,"max":9,"chance":1.0}]},
	"copper_ore":{"name":"Minério de cobre","hp":64,"tool":"pickaxe","tier":2,"days":5,"skill":"mining","drops":[{"item":"copper","min":3,"max":5,"chance":1.0},{"item":"stone","min":1,"max":2,"chance":0.5}]},
	"iron_ore":{"name":"Minério de ferro","hp":80,"tool":"pickaxe","tier":2,"days":7,"skill":"mining","drops":[{"item":"iron","min":3,"max":4,"chance":1.0},{"item":"stone","min":1,"max":3,"chance":0.5}]},
	"basalt":{"name":"Basalto compacto","hp":100,"tool":"pickaxe","tier":3,"days":7,"skill":"mining","drops":[{"item":"stone","min":10,"max":14,"chance":1.0},{"item":"iron","min":1,"max":2,"chance":0.4}]}
}
const TIERS:=["Sem ferramenta","Madeira","Pedra","Ferro"]
const LABELS:={"wood":"madeira","stone":"pedra","copper":"cobre","iron":"ferro"}
static func definition(resource:Dictionary)->Dictionary:
	return DEFINITIONS.get(resource.get("type",resource.get("kind","stone")),DEFINITIONS.stone)
static func type_at(resource:Dictionary)->String:
	return String(resource.get("type",resource.get("kind","stone")))
static func loot(definition:Dictionary,seed_value:int)->Array[Dictionary]:
	var rng:=RandomNumberGenerator.new();rng.seed=seed_value
	var out:Array[Dictionary]=[]
	for row in definition.drops:
		if rng.randf()<=row.chance:out.append({"item":row.item,"amount":rng.randi_range(row.min,row.max)})
	return out
