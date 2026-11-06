class_name OpenEconomy
extends Node

var game:ForestGame
var elapsed:=0.0

func setup(source:ForestGame)->void:
	game=source

func _process(delta:float)->void:
	if game==null or game.mode!="playing" or game.building_preview:return
	elapsed+=delta
	if elapsed<1.0:return
	var dt:=elapsed
	elapsed=0
	for id in game.world.npcs:
		var npc:ForestNPC=game.world.npcs[id]
		if npc.sleeping or npc.wants_rest:continue
		var account:=game.rpg.npc_account(id)
		var minute:=game.world.clock.day*1440+floori(game.world.clock.minute)
		if minute-int(account.last_wage)>=20:
			account.gold+=2
			account.last_wage=minute
		if npc.definition.get("builder",false):advance_builder(npc,dt)
		else:
			account.job=npc.activity()
			var town:String=npc.definition.get("town","")
			var tool:String={"Lenhador":"axe","Mineiro":"pickaxe","Artesã":"hammer"}.get(npc.definition.role,"")
			if not town.is_empty() and not tool.is_empty() and not account.tools.has(tool) and npc.position.distance_to(KingdomData.point(town+"_shop"))<95:game.rpg.buy(tool,id)

func advance_builder(npc:ForestNPC,delta:float)->void:
	var id:String=npc.definition.id
	var account:=game.rpg.npc_account(id)
	var town:String=npc.definition.town
	var shop:=KingdomData.point(town+"_shop")
	for tool in ["axe","pickaxe","hammer"]:
		if not account.tools.has(tool):
			account.job="Comprando "+RPGState.ITEMS[tool].name.to_lower()
			npc.set_economic_goal(shop,account.job)
			if npc.position.distance_to(shop)<95:game.rpg.buy(tool,id)
			return
	var home_id:="home_"+id
	var site:=KingdomData.point(town+"_plot")
	if not game.rpg.houses.has(home_id):
		account.job="Reservando terreno para minha casa"
		npc.set_economic_goal(site,account.job)
		if npc.position.distance_to(site)<95:game.rpg.claim(site,id)
		return
	var house:Dictionary=game.rpg.houses[home_id]
	if house.stage>=3:
		account.job="Minha casa está pronta"
		if npc.economic_target.is_finite():
			npc.economic_target=Vector2(INF,INF)
			npc.plan_route()
		return
	var costs:Dictionary=RPGState.BUILD_COSTS[house.stage]
	var kind:="wood" if account.wood<costs.wood else ("stone" if account.stone<costs.stone else "")
	if not kind.is_empty():
		var resource_id:=""
		for index in 20:
			var candidate:=kind+"_"+town+"_"+str(index)
			if not game.rpg.depleted.has(candidate):resource_id=candidate;break
		if resource_id.is_empty():
			account.job="Comprando material para minha casa"
			npc.set_economic_goal(shop,account.job)
			var price:=10 if kind=="wood" else 12
			if npc.position.distance_to(shop)<95 and account.gold>=price:
				account.gold-=price
				account[kind]+=5 if kind=="wood" else 4
				game.rpg.changed.emit()
			return
		var work:=KingdomData.point(town+"_"+kind)
		account.job="Juntando madeira para minha casa" if kind=="wood" else "Extraindo pedra para minha casa"
		npc.set_economic_goal(work,account.job)
		if npc.position.distance_to(work)>250:return
		account.clock+=delta
		if account.clock<5:return
		account.clock=0
		game.rpg.harvest(resource_id,kind,npc.definition.id)
		return

	account.job="Construindo "+RPGState.STAGES[house.stage+1].to_lower()
	npc.set_economic_goal(site+Vector2(0,48),account.job)
	if npc.position.distance_to(site+Vector2(0,48))<95:
		account.clock+=delta
		if account.clock>=5:
			account.clock=0
			game.rpg.build(home_id,id)
