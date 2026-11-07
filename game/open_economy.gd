class_name OpenEconomy
extends Node

var game:ForestGame
var elapsed:=0.0
var work_timers:Dictionary={}
var food_timers:Dictionary={}

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
		if npc.companion_mode:continue
		if npc.sleeping or npc.wants_rest:continue
		var account:=game.rpg.npc_account(id)
		var minute:=game.world.clock.day*1440+floori(game.world.clock.minute)
		if minute-int(account.last_wage)>=20:
			account.gold+=2
			account.last_wage=minute
		if npc.current_schedule.get("meal",false):advance_meal(npc);continue
		if npc.economic_target.is_finite() and npc.economic_activity=="Almoçando com os vizinhos":npc.clear_economic_goal()
		if game.construction!=null and game.construction.advance_worker(npc):continue
		if npc.definition.get("builder",false) and not npc.current_schedule.get("social",false):advance_builder(npc,dt)
		else:advance_worker(npc,dt)

func advance_meal(npc:ForestNPC)->void:
	var account:=game.rpg.npc_account(npc.definition.id)
	var stamp:=str(game.world.clock.day)+":"+str(npc.current_schedule.hour)
	if account.meal_stamp==stamp:return
	var at:=npc.nearest_walkable(npc._scheduled_point())
	npc.set_economic_goal(at,"Almoçando com os vizinhos");account.job=npc.activity()
	if npc.position.distance_to(at)>90:return
	if account.food>0:account.food-=1
	elif account.gold>=5:account.gold-=5
	else:return
	account.meal_stamp=stamp;npc.hunger=0.1;npc.clear_economic_goal();game.rpg.changed.emit()

func advance_worker(npc:ForestNPC,delta:float)->void:
	var id:String=npc.definition.id
	var account:=game.rpg.npc_account(id)
	account.job=npc.activity()
	var town:String=npc.definition.get("town","aurelia" if npc.definition.realm=="aurelia" else "valverde")
	if npc.definition.get("editor",false):return
	var tool:String={"Lenhador":"axe","Mineiro":"pickaxe","Artesã":"hammer","Ferreiro":"hammer"}.get(npc.definition.role,"")
	var shop:=KingdomData.point(town+"_shop")
	var trade_kind:String={"Lenhador":"wood","Mineiro":"stone"}.get(npc.definition.role,"")
	if not trade_kind.is_empty() and int(account[trade_kind])>=10 and npc.position.distance_to(shop)<100:
		account[trade_kind]-=10;account.gold+=20 if trade_kind=="wood" else 30;game.rpg.changed.emit()
	if not tool.is_empty() and not account.tools.has(tool):
		npc.set_economic_goal(KingdomData.point(town+"_shop_"+str(npc.personality_seed%6)),"Indo comprar "+RPGState.ITEMS[tool].name.to_lower())
		if npc.position.distance_to(shop)<100:
			var purchased:=game.rpg.buy(tool,id)
			if purchased.ok:npc.clear_economic_goal()
		return
	if npc.hunger>0.75:
		var inn:=KingdomData.point(town+"_inn")
		npc.set_economic_goal(inn,"Procurando uma refeição")
		if npc.position.distance_to(inn)<110 and account.gold>=5:
			account.gold-=5;npc.hunger=0.1;npc.clear_economic_goal();game.rpg.changed.emit()
		return
	if not npc.current_schedule.get("work",false):
		if npc.economic_target.is_finite():npc.clear_economic_goal()
		return
	work_timers[id]=float(work_timers.get(id,0))+delta
	if work_timers[id]<12:return
	work_timers[id]=0.0
	var kind:String={"Lenhador":"wood","Mineiro":"stone"}.get(npc.definition.role,"")
	if kind.is_empty():
		if npc.state=="work":account.gold+=1
		return
	var center:=KingdomData.point(town+"_"+kind)
	if npc.position.distance_to(center)>400:return
	for index in 20:
		var resource_id:=kind+"_"+town+"_"+str(index)
		if not game.rpg.depleted.has(resource_id):game.rpg.harvest(resource_id,kind,id);break

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
