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
var gold := 100
var wood := 0
var stone := 0
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

func level()->int:
	return 1+xp/100

func buy(item:String,owner:String="player")->Dictionary:
	if not ITEMS.has(item):return result(false,"Mercadoria desconhecida.")
	var data:Dictionary=ITEMS[item]
	if owner=="player":
		if data.kind=="tool" and tools.has(item):return result(false,"Você já possui "+data.name+".")
		if gold<data.price:return result(false,"Faltam moedas. Venda recursos ou aceite uma encomenda.")
		gold-=data.price
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
	var owned:int=wood if kind=="wood" else (stone if kind=="stone" else meat)
	if amount<=0 or owned<amount:return result(false,"Você não tem material suficiente.")
	if kind=="wood":wood-=amount
	elif kind=="stone":stone-=amount
	elif kind=="meat":meat-=amount
	else:return result(false,"Material desconhecido.")
	gold+=amount*(3 if kind=="stone" else (4 if kind=="meat" else 2))
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

func discover(id:String)->bool:
	if discovered.has(id):return false
	discovered[id]=true
	xp+=25
	changed.emit()
	return true

func claim(position:Vector2,owner:String="player")->Dictionary:
	var id:="home_"+owner
	if not position.is_finite() or position.x<192 or position.y<192 or position.x>WorldData.SIZE.x-192 or position.y>WorldData.SIZE.y-192:return result(false,"Terreno fora dos limites do continente.")
	if houses.has(id):return result(false,"Você já tem um terreno. Conclua sua casa primeiro.")
	if owner=="player":
		if gold<20:return result(false,"O terreno custa 20 moedas.")
		gold-=20
	else:
		var account:=npc_account(owner)
		if account.gold<20:return result(false,"Economizando para o terreno.")
		account.gold-=20
	houses[id]={"owner":owner,"x":position.x,"y":position.y,"stage":0}
	house_changed.emit(id)
	changed.emit()
	return result(true,"Terreno reservado. Use um martelo para construir em três etapas.")

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
	house_changed.emit(id)
	changed.emit()
	return result(true,STAGES[house.stage]+"!"+(" Agora você tem seu próprio lar." if house.stage==3 else " Prepare material para a próxima etapa."))

func npc_account(id:String)->Dictionary:
	if not npc_accounts.has(id):npc_accounts[id]={"gold":100,"wood":0,"stone":0,"tools":{},"job":"Começando a jornada","clock":0.0,"task":"","last_wage":0,"food":0}
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
	return Rect2(Vector2(house.x-96,house.y-128),Vector2(192,128))

func save_data()->Dictionary:
	return {"gold":gold,"wood":wood,"stone":stone,"food":food,"meat":meat,"xp":xp,"health":health,"tools":tools.keys(),"discovered":discovered.keys(),"depleted":depleted.keys(),"houses":houses.duplicate(true),"npc_accounts":npc_accounts.duplicate(true),"contracts":contracts.duplicate(),"produce_times":produce_times.duplicate()}

func restore(data:Dictionary)->void:
	for key in ["gold","wood","stone","food","meat","xp","health"]:
		var value=data.get(key,get(key))
		if (value is int or value is float) and is_finite(float(value)):set(key,clampi(int(value),0,999999))
	health=clampi(health,1,100)
	tools.clear();discovered.clear();depleted.clear();houses.clear();npc_accounts.clear();contracts.clear();produce_times.clear()
	for key in ["tools","discovered","depleted"]:
		var values=data.get(key,[])
		if values is Array:
			for id in values:
				if id is String and (key!="tools" or ITEMS.has(id) and ITEMS[id].kind=="tool"):get(key)[id]=true
	var saved_houses=data.get("houses",{})
	if saved_houses is Dictionary:
		for id in saved_houses:
			var h=saved_houses[id]
			if h is Dictionary and h.get("owner") is String and (h.get("x") is int or h.get("x") is float) and (h.get("y") is int or h.get("y") is float):
				var p:=Vector2(h.x,h.y)
				if p.is_finite() and p.x>192 and p.y>192 and p.x<WorldData.SIZE.x-192 and p.y<WorldData.SIZE.y-192:
					houses[id]={"owner":h.owner,"x":p.x,"y":p.y,"stage":clampi(int(h.get("stage",0)),0,3)}
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
