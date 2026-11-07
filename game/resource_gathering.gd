class_name ResourceGathering
extends Node

var game:ForestGame
var elapsed:=0.0
func setup(source:ForestGame)->void:game=source
func strike(id:String)->Dictionary:
	if game.mode!="playing" or game.action_delay>0 or game.housing!=null and game.housing.inside():return {"ok":false,"message":""}
	if not game.world.resources.has(id):return {"ok":false,"message":"Recurso distante."}
	var entry:Dictionary=game.world.resources[id]
	if game.player.position.distance_to(entry.resource.position)>64:return {"ok":false,"message":"Aproxime-se do recurso."}
	game.rpg.resources.day=game.world.clock.day;game.rpg.resources.minute=game.world.clock.minute
	var result:=game.rpg.strike_resource(entry.resource,game.player.stamina)
	if result.ok:
		game.action_delay=0.48;game.player.stamina=maxf(0,game.player.stamina-result.cost);game.player.exertion_delay=1.0
		game.audio.impact(entry.resource.kind=="wood")
		if game.hybrid!=null:game.hybrid.resource_fx.hit(entry,result.damage,result.finished)
		game.save_journey()
	game.hud.toast(result.message,1.5)
	return result
func _physics_process(delta:float)->void:
	if game==null or game.mode!="playing" or game.building_preview or game.housing!=null and game.housing.inside():return
	var progress:ResourceProgress=game.rpg.resources
	for id in progress.drops.keys():
		var drop:Dictionary=progress.drops[id]
		var at:=Vector2(drop.x,drop.y)
		if at.distance_squared_to(game.player.position)>1800*1800:continue
		drop.age+=delta
		var speed:=Vector2(drop.vx,drop.vy)
		var distance:=at.distance_to(game.player.position)
		if drop.age>0.5 and distance<110:
			speed=speed.move_toward(at.direction_to(game.player.position)*260,700*delta)
		else:speed=speed.move_toward(Vector2.ZERO,65*delta)
		var next:=at+speed*delta
		if WorldData.can_stand(next,game.world.data,2,true):at=next
		else:speed*=-0.35
		drop.x=at.x;drop.y=at.y;drop.vx=speed.x;drop.vy=speed.y
		drop.vz-=300*delta;drop.z+=drop.vz*delta
		if drop.z<0:drop.z=0;drop.vz=-drop.vz*0.28 if absf(drop.vz)>18 else 0.0
		if drop.age>0.5 and at.distance_to(game.player.position)<23:
			# Remove first: a save or a second frame cannot award the same drop twice.
			progress.drops.erase(id)
			game.rpg.set(drop.item,int(game.rpg.get(drop.item))+int(drop.amount));game.rpg.changed.emit()
			game.hud.toast("+%d %s"%[drop.amount,ResourceRules.LABELS[drop.item]],1.2);game.save_journey()
	elapsed+=delta
	if elapsed>=1.0:
		elapsed=0;regenerate()
func regenerate()->void:
	game.rpg.resources.day=game.world.clock.day
	var changed:=false
	for id in game.rpg.resources.states.keys():
		var state:Dictionary=game.rpg.resources.states[id]
		if state.hp>0 or state.regrow>game.world.clock.day:continue
		if state.regrow==game.world.clock.day and game.world.clock.minute<float(state.get("minute",0)):continue
		var at:=Vector2(state.x,state.y)
		if at.distance_to(game.player.position)<64:continue
		var occupied:=false
		for piece in game.rpg.construction.pieces.values():
			if ConstructionCatalog.footprint(piece).grow(24).has_point(at):occupied=true;break
		if occupied:continue
		if at!=Vector2.ZERO and not WorldData.can_stand(at,game.world.data,16,true):continue
		game.rpg.depleted.erase(id);game.rpg.resources.states.erase(id)
		game.world.regrow_resource(id,at);changed=true
	if changed:game.rpg.changed.emit();game.save_journey()
