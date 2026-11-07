class_name RPGState
extends RefCounted

signal changed
signal resource_depleted(id:String)
signal house_changed(id:String)

const ITEMS := {
	"axe":{"name":"Machado","price":25,"kind":"tool"},
	"pickaxe":{"name":"Picareta","price":30,"kind":"tool"},
	"hammer":{"name":"Martelo","price":15,"kind":"tool"},
	"sword":{"name":"Espada","price":35,"kind":"tool"},
	"bread":{"name":"Provisão","price":5,"kind":"consumable"},
}
const STAGES := ["Terreno","Fundação","Paredes","Casa concluída"]
const BUILD_COSTS := [{"wood":15,"stone":10},{"wood":20,"stone":5},{"wood":15,"stone":5}]
const HOUSE_HP:=[40,120,240,400]
const HOUSE_MATERIALS:=[{"wood":0,"stone":0},{"wood":15,"stone":10},{"wood":35,"stone":15},{"wood":50,"stone":20}]
var gold := 100
var wood := 0
var stone := 0
var copper:=0
var iron:=0
var resources:=ResourceProgress.new()
var construction:=ConstructionState.new()
var relationships:=RelationshipState.new()
var politics:=FactionState.new()
var food := 2
var meat := 0
var xp := 0
var health := 100
var tools:Dictionary = {}
var discovered:Dictionary = {}
var depleted:Dictionary = {}
var houses:Dictionary = {}
var npc_accounts:Dictionary = {}
var contracts:Dictionary = {}
var last_event := ""
var produce_times:Dictionary={}
var placement_provider:Callable

func level()->int:
	return 1+xp/100

func buy(item:String,owner:String="player",price_factor:float=1.0)->Dictionary:
	if not ITEMS.has(item):return result(false,"Mercadoria desconhecida.")
	var data:Dictionary=ITEMS[item]
	var price:=maxi(1,ceili(float(data.price)*price_factor))
	if owner=="player":
		if data.kind=="tool" and tools.has(item):return result(false,"Você já possui "+data.name+".")
		if gold<price:return result(false,"Faltam moedas. Venda recursos ou aceite uma encomenda.")
		gold-=price
		if data.kind=="tool":tools[item]=true
		else:food+=1
	else:
		var account:=npc_account(owner)
		if data.kind=="tool" and account.tools.has(item):return result(false,"Ferramenta já comprada.")
		if account.gold<data.price:return result(false,"Economizando moedas.")
		account.gold-=data.price
		if data.kind=="tool":account.tools[item]=true
		else:account.food+=1
	changed.emit()
	return result(true,("Você comprou " if owner=="player" else "Comprou ")+data.name+".")

func sell(kind:String,amount:int)->Dictionary:
	if not kind in ["wood","stone","meat","copper","iron"]:return result(false,"Material desconhecido.")
	var owned:int=get(kind)
	if amount<=0 or owned<amount:return result(false,"Você não tem material suficiente.")
	if kind=="wood":wood-=amount
	elif kind=="stone":stone-=amount
	elif kind=="meat":meat-=amount
	elif kind=="copper":copper-=amount
	elif kind=="iron":iron-=amount
	else:return result(false,"Material desconhecido.")
	gold+=amount*{"wood":2,"stone":3,"meat":4,"copper":7,"iron":12}[kind]
	changed.emit()
	return result(true,"Venda concluída. As moedas estão na sua bolsa.")

func eat()->Dictionary:
	if food<=0:return result(false,"Compre provisões no comércio ou na estalagem.")
	if health>=100:return result(false,"Sua vida já está completa.")
	food-=1
	health=mini(100,health+30)
	changed.emit()
	return result(true,"Você recuperou 30 pontos de vida.")

func harvest(id:String,kind:String,owner:String="player")->Dictionary:
	if depleted.has(id):return result(false,"Este recurso já foi recolhido.")
	var tool:="axe" if kind=="wood" else "pickaxe"
	var bag:Dictionary=tools if owner=="player" else npc_account(owner).tools
	if not bag.has(tool):return result(false,"É preciso um "+ITEMS[tool].name.to_lower()+". Visite uma ferraria.")
	depleted[id]=true
	resources.mark({"id":id,"kind":kind})
	if owner=="player":
		if kind=="wood":wood+=5
		else:stone+=4
		xp+=8
	else:
		var account:=npc_account(owner)
		account[kind]+=5 if kind=="wood" else 4
	resource_depleted.emit(id)
	changed.emit()
	return result(true,"+5 madeira · +8 XP" if kind=="wood" else "+4 pedra · +8 XP")

func strike_resource(resource:Dictionary,energy:float)->Dictionary:
	if depleted.has(resource.id):return result(false,"Este recurso está se regenerando.")
	var hit:=resources.strike(resource,tools,energy)
	if hit.ok:
		if hit.finished:
			depleted[resource.id]=true;xp+=8;resource_depleted.emit(resource.id)
		changed.emit()
	return hit

func upgrade_tool(tool:String,price_factor:float=1.0)->Dictionary:
	if not tool in ["axe","pickaxe"] or not tools.has(tool):return result(false,"Compre a ferramenta primeiro.")
	var tier:=resources.tier(tool,tools)
	if tier>=3:return result(false,"Sua ferramenta já é de ferro.")
	var price:=ceili((40 if tier==1 else 90)*price_factor)
	if gold<price or (tier==1 and (wood<5 or stone<10)) or (tier==2 and iron<6):return result(false,"Melhoria de pedra: 40 moedas, 5 madeira, 10 pedra. Ferro: 90 moedas e 6 ferro.")
	gold-=price
	if tier==1:wood-=5;stone-=10
	else:iron-=6
	resources.tiers[tool]=tier+1;changed.emit()
	return result(true,ITEMS[tool].name+" de "+ResourceRules.TIERS[tier+1]+" preparado.")

func discover(id:String)->bool:
	if discovered.has(id):return false
	discovered[id]=true
	xp+=25
	changed.emit()
	return true

func claim(position:Vector2,owner:String="player",options:Dictionary={})->Dictionary:
	var kit_options:=HouseKit.clean_options(options)
	var size:=HouseKit.size_for(kit_options.house_style,kit_options.house_seed,kit_options.house_turn) if not kit_options.is_empty() else Vector2(192,128)
	var corner:=(position-Vector2(size.x/2,size.y)).snapped(Vector2.ONE*WorldGrid.CELL)
	position=corner+Vector2(size.x/2,size.y)
	var id:="home_"+owner
	if not position.is_finite() or position.x<192 or position.y<192 or position.x>WorldData.SIZE.x-192 or position.y>WorldData.SIZE.y-192:return result(false,"Terreno fora dos limites do continente.")
	if houses.has(id):return result(false,"Você já tem um terreno. Conclua sua casa primeiro.")
	var footprint:=Rect2(corner,size)
	var context:Dictionary=placement_provider.call(footprint.grow(PlacementValidator.DECORATION_MARGIN)) if placement_provider.is_valid() else PlacementValidator.runtime_context(self)
	var valid:=PlacementValidator.validate(footprint,context,{"decoration":true,"owner":owner})
	if not valid.ok:return result(false,valid.message)
	if owner=="player":
		if gold<20:return result(false,"O terreno custa 20 moedas.")
		gold-=20
	else:
		var account:=npc_account(owner)
		if account.gold<20:return result(false,"Economizando para o terreno.")
		account.gold-=20
	houses[id]={"owner":owner,"x":position.x,"y":position.y,"stage":0,"hp":HOUSE_HP[0]}
	houses[id].merge(kit_options)
	house_changed.emit(id)
	changed.emit()
	return result(true,"Terreno reservado. Use um martelo para construir em três etapas.")

static func snap_home(point:Vector2)->Vector2:
	var corner:=(point-Vector2(96,128)).snapped(Vector2.ONE*WorldGrid.CELL)
	return corner+Vector2(96,128)

func build(id:String,owner:String="player")->Dictionary:
	if not houses.has(id) or houses[id].owner!=owner:return result(false,"Este terreno pertence a outro morador.")
	var house:Dictionary=houses[id]
	if house.stage>=3:return result(false,"A casa já está pronta. Você pode descansar nela.")
	var account:Dictionary={"tools":tools,"wood":wood,"stone":stone} if owner=="player" else npc_account(owner)
	if not account.tools.has("hammer"):return result(false,"Compre um martelo na ferraria.")
	var cost:Dictionary=BUILD_COSTS[house.stage]
	if account.wood<cost.wood or account.stone<cost.stone:return result(false,"Esta etapa precisa de %d madeira e %d pedra."%[cost.wood,cost.stone])
	if owner=="player":
		wood-=cost.wood
		stone-=cost.stone
		xp+=35
	else:
		account.wood-=cost.wood
		account.stone-=cost.stone
	house.stage+=1
	house.hp=HOUSE_HP[house.stage]
	house_changed.emit(id)
	changed.emit()
	return result(true,STAGES[house.stage]+"!"+(" Agora você tem seu próprio lar." if house.stage==3 else " Prepare material para a próxima etapa."))

func house_repair_cost(id:String)->Dictionary:
	if not houses.has(id):return {}
	var house:Dictionary=houses[id];var cost:Dictionary={}
	var missing:=1.0-float(house.get("hp",HOUSE_HP[house.stage]))/float(HOUSE_HP[house.stage])
	if missing<=0 or house.stage==0:return cost
	for item in HOUSE_MATERIALS[house.stage]:cost[item]=maxi(1,ceili(HOUSE_MATERIALS[house.stage][item]*missing*0.5))
	return cost

func repair_house(id:String)->Dictionary:
	if not houses.has(id) or houses[id].owner!="player":return result(false,"Esta casa pertence a outro morador.")
	if not tools.has("hammer"):return result(false,"Reparar exige um martelo.")
	var cost:=house_repair_cost(id)
	if cost.is_empty():return result(false,"Casa em perfeito estado.")
	if not construction.afford(self,cost):return result(false,"Reparo: "+ConstructionCatalog.cost_text(cost))
	construction.transfer(self,cost,-1);houses[id].hp=HOUSE_HP[houses[id].stage]
	house_changed.emit(id);changed.emit()
	return result(true,"Casa reparada.")

func damage_house(id:String,damage:int)->Dictionary:
	if not houses.has(id) or damage<=0:return {"ok":false,"destroyed":false}
	var house:Dictionary=houses[id]
	house.hp=maxi(0,int(house.get("hp",HOUSE_HP[house.stage]))-damage)
	var destroyed:bool=house.hp==0
	if destroyed:houses.erase(id)
	house_changed.emit(id);changed.emit()
	return {"ok":true,"destroyed":destroyed}

func npc_account(id:String)->Dictionary:
	if not npc_accounts.has(id):npc_accounts[id]={"gold":100,"wood":0,"stone":0,"tools":{},"goods":{},"job":"Começando a jornada","clock":0.0,"task":"","last_wage":0,"food":0,"meal_stamp":""}
	return npc_accounts[id]

func deliver(town:String,day:int)->Dictionary:
	if int(contracts.get(town,0))==day:return result(false,"A encomenda de hoje já foi entregue. Volte amanhã.")
	if wood<15 or stone<8:return result(false,"Encomenda: 15 madeira e 8 pedra. Pagamento: 80 moedas e 40 XP.")
	wood-=15
	stone-=8
	gold+=80
	xp+=40
	contracts[town]=day
	changed.emit()
	return result(true,"Encomenda entregue: +80 moedas · +40 XP.")

func home_rect(house:Dictionary)->Rect2:
	var options:=HouseKit.clean_options(house)
	var size:=HouseKit.size_for(options.house_style,options.house_seed,options.house_turn) if not options.is_empty() else Vector2(192,128)
	return Rect2(Vector2(house.x-size.x/2,house.y-size.y),size)

func save_data()->Dictionary:
	return {"gold":gold,"wood":wood,"stone":stone,"copper":copper,"iron":iron,"resources":resources.save_data(),"construction":construction.save_data(),"relationships":relationships.save_data(),"politics":politics.save_data(),"food":food,"meat":meat,"xp":xp,"health":health,"tools":tools.keys(),"discovered":discovered.keys(),"depleted":depleted.keys(),"houses":houses.duplicate(true),"npc_accounts":npc_accounts.duplicate(true),"contracts":contracts.duplicate(),"produce_times":produce_times.duplicate()}

func restore(data:Dictionary)->void:
	for key in ["gold","wood","stone","copper","iron","food","meat","xp","health"]:
		var value=data.get(key,get(key))
		if (value is int or value is float) and is_finite(float(value)):set(key,clampi(int(value),0,999999))
	health=clampi(health,1,100)
	resources.restore(data.get("resources",{}))
	construction.restore(data.get("construction",{}))
	relationships.restore(data.get("relationships",{}))
	politics.restore(data.get("politics",{}))
	tools.clear();discovered.clear();depleted.clear();houses.clear();npc_accounts.clear();contracts.clear();produce_times.clear()
	for key in ["tools","discovered","depleted"]:
		var values=data.get(key,[])
		if values is Array:
			for id in values:
				if (id is String or id is StringName) and (key!="tools" or ITEMS.has(id) and ITEMS[id].kind=="tool"):get(key)[String(id)]=true
	var saved_houses=data.get("houses",{})
	if saved_houses is Dictionary:
		for id in saved_houses:
			var h=saved_houses[id]
			if h is Dictionary and h.get("owner") is String and (h.get("x") is int or h.get("x") is float) and (h.get("y") is int or h.get("y") is float):
				var p:=Vector2(h.x,h.y)
				if p.is_finite() and p.x>192 and p.y>192 and p.x<WorldData.SIZE.x-192 and p.y<WorldData.SIZE.y-192:
					var stage:=clampi(int(h.get("stage",0)),0,3)
					var hp:int=clampi(int(h.get("hp",HOUSE_HP[stage])),1,HOUSE_HP[stage]) if ResourceProgress.number(h.get("hp",HOUSE_HP[stage])) else HOUSE_HP[stage]
					houses[id]={"owner":h.owner,"x":p.x,"y":p.y,"stage":stage,"hp":hp}
					houses[id].merge(HouseKit.clean_options(h))
					if ResourceProgress.number(h.get("house_turn")):houses[id].house_turn=posmod(int(h.house_turn),4)
	var accounts=data.get("npc_accounts",{})
	if accounts is Dictionary:
		for id in accounts:
			if not id is String or not accounts[id] is Dictionary or KingdomData.person(id).is_empty():continue
			var source:Dictionary=accounts[id]
			var account:=npc_account(id)
			for key in ["clock","last_wage"]:
				var timer=source.get(key,0)
				if (timer is int or timer is float) and is_finite(float(timer)):account[key]=clampf(float(timer),0,1e10)
			if source.get("job") is String:account.job=source.job.left(160)
			if source.get("meal_stamp") is String:account.meal_stamp=source.meal_stamp.left(40)
			if source.get("goods") is Dictionary:
				for item in RelationshipCatalog.GIFTS:
					if ResourceProgress.number(source.goods.get(item)):account.goods[item]=clampi(int(source.goods[item]),0,999999)
			for key in ["gold","wood","stone","food"]:
				var value=source.get(key,0)
				if (value is int or value is float) and is_finite(float(value)):account[key]=clampi(int(value),0,999999)
			if source.get("tools") is Dictionary:
				for tool in source.tools:
					if ITEMS.has(tool) and ITEMS[tool].kind=="tool":account.tools[tool]=true
	var production=data.get("produce_times",{})
	if production is Dictionary:
		for id in production:
			if production[id] is int or production[id] is float:
				if is_finite(float(production[id])):produce_times[id]=float(production[id])
	var jobs=data.get("contracts",{})
	if jobs is Dictionary:
		for id in jobs:
			if jobs[id] is int or jobs[id] is float:contracts[id]=clampi(int(jobs[id]),0,999999)
	changed.emit()

func result(ok:bool,message:String)->Dictionary:
	last_event=message
	return {"ok":ok,"message":message}
