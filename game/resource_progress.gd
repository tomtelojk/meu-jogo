class_name ResourceProgress
extends RefCounted

var states:Dictionary={}
var drops:Dictionary={}
var tiers:Dictionary={}
var skills:Dictionary={"woodcutting":0,"mining":0}
var day:=1
var minute:=0.0
func level(skill:String)->int:return mini(20,1+int(skills.get(skill,0))/60)
func tier(tool:String,bag:Dictionary)->int:return clampi(int(tiers.get(tool,1)),1,3) if bag.has(tool) else 0
func mark(resource:Dictionary)->void:
	var definition:=ResourceRules.definition(resource)
	var at:Vector2=resource.get("position",Vector2.ZERO)
	states[resource.id]={"type":ResourceRules.type_at(resource),"hp":0,"stage":"stump" if definition.tool=="axe" else "spent","regrow":day+definition.days,"minute":minute,"x":at.x,"y":at.y}
func strike(resource:Dictionary,bag:Dictionary,energy:float)->Dictionary:
	var definition:=ResourceRules.definition(resource)
	var tool_tier:=tier(definition.tool,bag)
	if tool_tier<definition.tier:return {"ok":false,"message":"Requer %s de %s."%["machado" if definition.tool=="axe" else "picareta",ResourceRules.TIERS[definition.tier]]}
	var skill_level:=level(definition.skill)
	var cost:=maxf(0.055,(0.16-tool_tier*0.02)*(1.0-(skill_level-1)*0.025))
	if energy+0.0001<cost:return {"ok":false,"message":"Sem energia. Descanse um pouco antes de golpear."}
	var state:Dictionary=states.get(resource.id,{"type":ResourceRules.type_at(resource),"hp":definition.hp,"stage":"standing","regrow":0,"x":resource.position.x,"y":resource.position.y})
	if state.hp<=0:return {"ok":false,"message":"Este recurso está se regenerando."}
	var damage:=roundi([0,12,21,33][tool_tier]*(1.0+(skill_level-1)*0.05))
	state.hp=maxi(0,int(state.hp)-damage);states[resource.id]=state
	skills[definition.skill]=int(skills.get(definition.skill,0))+3
	var finished:bool=state.hp<=0
	if finished:
		mark(resource);skills[definition.skill]+=15
		var loot:=ResourceRules.loot(definition,String(resource.id).hash()^day*1937)
		var rng:=RandomNumberGenerator.new();rng.seed=String(resource.id).hash()^day
		var serial:=0
		for row in loot:
			var remaining:int=row.amount
			while remaining>0:
				var amount:=mini(2,remaining);remaining-=amount
				var direction:=Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(35,85)
				var id:="%s:%d:%d"%[resource.id,day,serial];serial+=1
				drops[id]={"item":row.item,"amount":amount,"x":resource.position.x,"y":resource.position.y,"vx":direction.x,"vy":direction.y,"z":8.0,"vz":rng.randf_range(75,120),"age":0.0}
	return {"ok":true,"finished":finished,"damage":damage,"hp":state.hp,"max_hp":definition.hp,"cost":cost,"message":"%s · %d/%d"%[definition.name,state.hp,definition.hp] if not finished else definition.name+" recolhido: aproxime-se dos materiais."}
func save_data()->Dictionary:return {"states":states.duplicate(true),"drops":drops.duplicate(true),"tiers":tiers.duplicate(),"skills":skills.duplicate()}
func restore(raw:Variant)->void:
	states.clear();drops.clear();tiers.clear();skills={"woodcutting":0,"mining":0}
	if not raw is Dictionary:return
	for tool in ["axe","pickaxe"]:
		var value:Variant=raw.get("tiers",{}).get(tool,1) if raw.get("tiers",{}) is Dictionary else 1
		if number(value):tiers[tool]=clampi(int(value),1,3)
	for skill in skills:
		var value:Variant=raw.get("skills",{}).get(skill,0) if raw.get("skills",{}) is Dictionary else 0
		if number(value):skills[skill]=clampi(int(value),0,1000000)
	for group in ["states","drops"]:
		var entries:Variant=raw.get(group,{})
		if not entries is Dictionary or entries.size()>(50000 if group=="states" else 4096):continue
		for id in entries:
			var value:Variant=entries[id]
			if not id is String or id.length()>140 or not value is Dictionary:continue
			if not number(value.get("x")) or not number(value.get("y")):continue
			if value.x<0 or value.y<0 or value.x>16000 or value.y>12800:continue
			if group=="states":
				if not ResourceRules.DEFINITIONS.has(value.get("type")) or not number(value.get("hp")) or not number(value.get("regrow")):continue
				var hp:=clampi(int(value.hp),0,ResourceRules.DEFINITIONS[value.type].hp)
				states[id]={"type":value.type,"hp":hp,"stage":"standing" if hp>0 else ("stump" if value.type=="wood" else "spent"),"regrow":clampi(int(value.regrow),0,9999999),"x":float(value.x),"y":float(value.y)}
				states[id].minute=clampf(float(value.get("minute",0)),0,1439.999) if number(value.get("minute",0)) else 0.0
			else:
				if not ResourceRules.LABELS.has(value.get("item")) or not number(value.get("amount")):continue
				var clean:={"item":value.item,"amount":clampi(int(value.amount),1,99),"x":float(value.x),"y":float(value.y)}
				for field in ["vx","vy","z","vz","age"]:
					var n:Variant=value.get(field,0)
					clean[field]=clampf(float(n),-500,1000000 if field=="age" else 500) if number(n) else 0.0
				clean.z=maxf(0,clean.z);clean.age=maxf(0,clean.age);drops[id]=clean
static func number(v:Variant)->bool:return (v is int or v is float) and is_finite(float(v))
