class_name ConstructionSystem
extends Node

var game:ForestGame
var selected:=""
var turn:=0
var category:="walls"
var last_minute:=0.0
var preview_result:Dictionary={}
var preview_key:=""

func setup(source:ForestGame)->void:
	game=source;bind_world()

func bind_world()->void:
	last_minute=game.world.clock.day*1440.0+game.world.clock.minute
	if not game.world.clock.minute_changed.is_connected(_time_changed):game.world.clock.minute_changed.connect(_time_changed)

func _time_changed()->void:
	var now:=game.world.clock.day*1440.0+game.world.clock.minute
	var delta:=now-last_minute;last_minute=now
	if game.loading_journey or delta<=0:return
	var working:Dictionary={}
	if delta<10 and game.world.population_active:
		for id in game.rpg.construction.queues:
			var entry:Dictionary=game.rpg.construction.pieces.get(id,{})
			var worker:ForestNPC=game.world.npcs.get(entry.get("worker",""))
			if worker!=null and worker.current_schedule.get("work",false) and not worker.wants_rest and not worker.sleeping and worker.state!="flee" and worker.position.distance_to(ConstructionCatalog.approach(entry))<100:working[id]=true
	var completed:=game.rpg.construction.advance(game.rpg,delta,working)
	if not completed.is_empty():
		game.hud.toast("Produção concluída: "+", ".join(completed.slice(0,3)),4)

func advance_worker(npc:ForestNPC)->bool:
	var id:=game.rpg.construction.assigned(npc.definition.id,"worker")
	if id.is_empty() or npc.wants_rest:return false
	var entry:Dictionary=game.rpg.construction.pieces[id]
	if npc.hunger>0.75:
		var table:=npc.home_override if npc.home_override.is_finite() else npc.nearest_walkable(ConstructionCatalog.approach(entry))
		npc.set_economic_goal(table,"Fazendo uma pausa para comer")
		var account:=game.rpg.npc_account(npc.definition.id)
		if npc.position.distance_to(table)<90 and (account.food>0 or account.gold>=5):
			if account.food>0:account.food-=1
			else:account.gold-=5
			npc.hunger=0.1;npc.clear_economic_goal();game.rpg.changed.emit()
		return true
	if not npc.current_schedule.get("work",false):
		if npc.economic_target.is_finite():npc.clear_economic_goal()
		game.rpg.npc_account(npc.definition.id).job=npc.activity()
		return true
	var label:String="Trabalhando na sua "+ConstructionCatalog.piece(entry.kind).name.to_lower()
	game.rpg.npc_account(npc.definition.id).job=label
	npc.set_economic_goal(npc.nearest_walkable(ConstructionCatalog.approach(entry)),label)
	return true

func show_catalog(which:String="walls")->void:
	category=which if ConstructionCatalog.CATEGORIES.has(which) else "walls"
	ConstructionCatalog.load_data()
	var actions:Array[Dictionary]=[]
	for id in ConstructionCatalog.pieces:
		var definition:=ConstructionCatalog.piece(id)
		if definition.category!=category:continue
		actions.append({"label":definition.name+"\n"+ConstructionCatalog.cost_text(definition.cost),"name":"piece_"+id,"callback":begin_piece.bind(id)})
	actions.append({"label":"Casa completa por etapas","name":"house_kit","callback":game.start_building})
	if not game.rpg.construction.pieces.is_empty():actions.append({"label":"Minhas construções e moradores","callback":show_owned.bind(0)})
	actions.append({"label":"Voltar à aventura","callback":game.close_dialog})
	var body:="Encaixe as peças na grade. Pisos e coberturas podem compartilhar espaço com móveis e paredes.\n\n"+inventory_text()
	if not game.rpg.tools.has("hammer"):body+="\nVocê precisa de um martelo. Compre na ferraria."
	game._open_dialog("CONSTRUÇÃO · "+str(game.rpg.construction.pieces.size())+" PEÇAS","Construir",body,actions,"construction")
	var tabs:=HBoxContainer.new();tabs.add_theme_constant_override("separation",4)
	for id in ConstructionCatalog.CATEGORIES:
		var label:String={"walls":"Paredes","floors":"Chão","furniture":"Móveis","stations":"Estações"}[id]
		var button:=game.hud._button(label,show_catalog.bind(id),true,id!=category)
		button.name="category_"+id;button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size",14);tabs.add_child(button)
	game.hud.modal_content.add_child(tabs);game.hud.modal_content.move_child(tabs,2)
	game.hud.call_deferred("_layout_modal")

func inventory_text()->String:
	var state:RPGState=game.rpg
	var text:="Bolsa: %d madeira · %d pedra · %d cobre · %d ferro"%[state.wood,state.stone,state.copper,state.iron]
	var processed:=PackedStringArray()
	for item in ConstructionCatalog.PROCESSED:
		var amount:=state.construction.amount(state,item)
		if amount>0:processed.append("%d %s"%[amount,ConstructionCatalog.MATERIALS[item]])
	if not processed.is_empty():text+="\n"+" · ".join(processed)
	return text

func begin_piece(kind:String)->void:
	if ConstructionCatalog.piece(kind).is_empty():return
	if not game.rpg.tools.has("hammer"):game.hud.toast("Compre um martelo na ferraria.");return
	game.close_dialog();game.cancel_building()
	if game.mode!="playing":return
	selected=kind;turn=0;game.building_preview=true;game.player.active=false;game.world.set_population_active(false)
	preview_key=""
	var focus:=game.get_viewport().gui_get_focus_owner()
	if focus!=null:focus.release_focus()
	game.hud.toast("Clique para construir · T para girar · B abre o catálogo · Esc cancela",6)
	update_preview()

func candidate(point:Vector2)->Dictionary:
	var at:=ConstructionCatalog.cell(point)
	return {"kind":selected,"x":at.x,"y":at.y,"turn":turn,"open":false}

func can_place(kind:String,point:Vector2,rotation:int=0)->Dictionary:
	if not point.is_finite() or point.distance_to(game.player.position)>500:return {"ok":false,"message":"Escolha um ponto perto de você."}
	var at:=ConstructionCatalog.cell(point)
	var valid:=game.rpg.construction.validate(kind,at,rotation)
	if not valid.ok:return valid
	var entry:={"kind":kind,"x":at.x,"y":at.y,"turn":rotation,"open":false}
	var definition:=ConstructionCatalog.piece(kind)
	var rect:=ConstructionCatalog.footprint(entry)
	# World solids include modular walls: use the immutable village footprints and
	# legacy houses here, allowing floors/roofs underneath a modular object.
	for building in KingdomData.buildings():
		if rect.intersects(KingdomData.building_rect(building).grow(8)):return invalid("Há uma construção muito perto.")
	for house in game.rpg.houses.values():
		if rect.intersects(game.rpg.home_rect(house).grow(8)):return invalid("O terreno desta casa já está reservado.")
	for town in KingdomData.towns():
		if not town.capital and rect.intersects(Rect2(KingdomData.point(town.id+"_plot")-Vector2(96,128),Vector2(192,128)).grow(8)):return invalid("Este lote pertence a um morador.")
	for resource in game.world.data.colliders:
		if resource.get("active",true) and WorldData.circle_hits_rect(resource.position,float(resource.radius)+8,rect):return invalid("Retire as árvores e pedras deste local.")
	for y in range(ceili(rect.size.y/16)+1):
		for x in range(ceili(rect.size.x/16)+1):
			var sample:=rect.position+Vector2(minf(x*16,rect.size.x),minf(y*16,rect.size.y))
			if WorldData.in_river(sample) or WorldData.bridge_at(sample).has_area():return invalid("Construa em terra firme, fora do rio e das pontes.")
			if WorldData.path_distance(sample)<50:return invalid("Deixe as ruas e estradas livres.")
	var collider:=ConstructionCatalog.collision(entry)
	if collider.has_area():
		if collider.grow(13).has_point(game.player.position):return invalid("Você está ocupando este espaço.")
		for npc in game.world.npcs.values():
			if not npc.sleeping and collider.grow(14).has_point(npc.position):return invalid("Espere o morador passar.")
		for animal in game.world.animals.values():
			if animal.alive and collider.grow(14).has_point(animal.position):return invalid("Há um animal neste espaço.")
	if definition.has("station") or definition.get("home",false):
		var approach:=ConstructionCatalog.approach(entry)
		if not WorldData.can_stand(approach,game.world.data,12):return invalid("Deixe livre o acesso à frente desta peça. T gira a entrada.")
	if not game.rpg.tools.has("hammer"):return invalid("É preciso um martelo.")
	if not game.rpg.construction.afford(game.rpg,definition.cost):return invalid("Faltam materiais: "+ConstructionCatalog.cost_text(definition.cost))
	return {"ok":true,"message":definition.name+" · "+ConstructionCatalog.cost_text(definition.cost)}

func invalid(message:String)->Dictionary:return {"ok":false,"message":message}

func update_preview()->void:
	if selected.is_empty():return
	var point:=game.hybrid.world_position(game.get_viewport().get_mouse_position()) if game.hybrid!=null else game.get_global_mouse_position()
	game.building_point=Vector2(ConstructionCatalog.cell(point))*ConstructionCatalog.GRID
	var key:=selected+str(turn)+str(game.building_point)+str(game.rpg.construction.serial)+str(game.rpg.construction.pieces.size())+inventory_text()
	if key!=preview_key:
		preview_key=key;preview_result=can_place(selected,game.building_point,turn)
	if game.hybrid!=null:game.hybrid.preview_piece(candidate(game.building_point),preview_result.ok)
	game.hud.show_interaction(preview_result.message,game.hybrid.screen_position(game.player.position) if game.hybrid!=null else Vector2(640,400))
	game.hud.interaction_label.text=preview_result.message
	game.hud.controls.text="Clique · Construir    T · Girar    B · Catálogo    Esc / botão direito · Sair"

func place(point:Vector2)->Dictionary:
	var valid:=can_place(selected,point,turn)
	if not valid.ok:game.hud.toast(valid.message);return valid
	var result:=game.rpg.construction.place(game.rpg,selected,ConstructionCatalog.cell(point),turn)
	if result.ok:
		game.audio.impact(true);game.save_journey()
		if game.building_preview:update_preview()
	game.hud.toast(result.message,2)
	return result

func near(id:String)->bool:
	return game.rpg.construction.pieces.has(id) and ConstructionCatalog.footprint(game.rpg.construction.pieces[id]).grow(100).has_point(game.player.position)

func show_owned(page:int=0)->void:
	var ids:Array=game.rpg.construction.pieces.keys()
	ids.sort_custom(func(a:String,b:String):return ConstructionCatalog.footprint(game.rpg.construction.pieces[a]).get_center().distance_squared_to(game.player.position)<ConstructionCatalog.footprint(game.rpg.construction.pieces[b]).get_center().distance_squared_to(game.player.position))
	var actions:Array[Dictionary]=[]
	for i in range(page*7,mini(ids.size(),page*7+7)):
		var entry:Dictionary=game.rpg.construction.pieces[ids[i]]
		var distance:=roundi(ConstructionCatalog.footprint(entry).get_center().distance_to(game.player.position)/64)
		actions.append({"label":ConstructionCatalog.piece(entry.kind).name+" · "+str(distance)+" passos","callback":show_piece.bind(ids[i])})
	if page>0:actions.append({"label":"Página anterior","callback":show_owned.bind(page-1)})
	if (page+1)*7<ids.size():actions.append({"label":"Próxima página","callback":show_owned.bind(page+1)})
	actions.append({"label":"Catálogo de construção","callback":show_catalog.bind(category)})
	game._open_dialog("SEU ASSENTAMENTO","Minhas construções","Aproxime-se de uma estrutura e use E para produzir, reparar ou designar um morador.",actions,"construction_owned")

func show_piece(id:String)->void:
	if not game.rpg.construction.pieces.has(id):show_owned();return
	var entry:Dictionary=game.rpg.construction.pieces[id];var definition:=ConstructionCatalog.piece(entry.kind)
	var body:="Vida: %d/%d\n"%[entry.hp,definition.hp]
	var actions:Array[Dictionary]=[]
	if not near(id):
		body+="Vá até a estrutura para usá-la. Célula: %d, %d."%[entry.x,entry.y]
	else:
		if definition.has("station"):
			body+="\nReceitas desta estação. Um trabalhador presente produz 25% mais rápido durante seu turno.\n"
			body+=queue_text(id)
			actions.append({"label":"Receitas e produção","name":"station_recipes","callback":show_recipes.bind(id)})
			actions.append({"label":"Gerenciar fila","name":"station_queue","callback":show_queue.bind(id)})
			body+="\nTrabalhador: "+person_name(entry.worker)
			actions.append({"label":"Designar trabalhador","name":"assign_worker","callback":show_assignments.bind(id,"worker",0)})
		if entry.kind=="bed":
			body+="\nMorador: "+person_name(entry.resident)
			body+="\nCamas livres permitem descansar, salvar e definir seu ponto de retorno."
			if entry.resident.is_empty():actions.append({"label":"Descansar e salvar","name":"bed_rest","callback":rest_bed.bind(id)})
			actions.append({"label":"Designar morador","name":"assign_resident","callback":show_assignments.bind(id,"resident",0)})
		if entry.kind=="door":actions.append({"label":"Fechar porta" if entry.open else "Abrir porta","name":"toggle_door","callback":toggle_door.bind(id)})
		if int(entry.hp)<int(definition.hp):actions.append({"label":"Reparar · "+ConstructionCatalog.cost_text(game.rpg.construction.repair_cost(id)),"name":"repair_piece","callback":repair.bind(id)})
		actions.append({"label":"Desmontar peça…","name":"remove_piece","callback":confirm_remove.bind(id)})
	actions.append({"label":"Minhas construções","callback":show_owned.bind(0)})
	actions.append({"label":"Continuar explorando","callback":game.close_dialog})
	game._open_dialog("CONSTRUÇÃO",definition.name,body,actions,"structure")

func person_name(id:String)->String:return KingdomData.person(id).get("name","Ninguém designado")

func show_recipes(id:String)->void:
	if not near(id):game.hud.toast("Aproxime-se da bancada.");return
	var station:String=ConstructionCatalog.piece(game.rpg.construction.pieces[id].kind).get("station","")
	var actions:Array[Dictionary]=[]
	for key in ConstructionCatalog.recipes:
		var recipe:=ConstructionCatalog.recipe(key)
		if recipe.station==station:actions.append({"label":recipe.name+" · %d min"%recipe.minutes,"name":"recipe_"+key,"callback":show_recipe.bind(id,key)})
	actions.append({"label":"Fila e estação","callback":show_piece.bind(id)})
	game._open_dialog("FABRICAÇÃO",ConstructionCatalog.piece(game.rpg.construction.pieces[id].kind).name,inventory_text()+"\n\nO tempo de produção acompanha o relógio do mundo. Menus e construção pausam o relógio.",actions,"recipes")

func show_recipe(id:String,key:String)->void:
	if not near(id):return
	var recipe:=ConstructionCatalog.recipe(key)
	var output:String=ConstructionCatalog.cost_text(recipe.get("output",{})) if recipe.has("output") else RPGState.ITEMS[recipe.tool].name
	if recipe.get("tool","") in ["axe","pickaxe"]:output+=" de "+ResourceRules.TIERS[int(recipe.tier)]
	var body:="Custo por unidade: "+ConstructionCatalog.cost_text(recipe.cost)+"\nResultado: "+output+"\nTempo: %d minutos por unidade\n\n"%recipe.minutes+inventory_text()
	var actions:Array[Dictionary]=[{"label":"Produzir 1 unidade","name":"craft_one","callback":enqueue.bind(id,key,1)}]
	if not recipe.has("tool"):actions.append({"label":"Produzir 5 unidades","name":"craft_five","callback":enqueue.bind(id,key,5)})
	actions.append({"label":"Voltar às receitas","callback":show_recipes.bind(id)})
	game._open_dialog("RECEITA",recipe.name,body,actions,"recipe")

func enqueue(id:String,key:String,count:int)->void:
	if not near(id):return
	_time_changed()
	var result:=game.rpg.construction.enqueue(game.rpg,id,key,count)
	if result.ok:game.save_journey();show_queue(id)
	game.hud.toast(result.message)

func queue_text(id:String)->String:
	var jobs:Array=game.rpg.construction.queues.get(id,[])
	if jobs.is_empty():return "Fila vazia."
	var lines:=PackedStringArray()
	for i in jobs.size():
		var job:Dictionary=jobs[i]
		lines.append("%d. %s ×%d · %.1f min%s"%[i+1,ConstructionCatalog.recipe(job.recipe).name,job.count,job.remaining," (em produção)" if i==0 else ""])
	return "\n".join(lines)

func show_queue(id:String)->void:
	if not near(id):return
	var body:=queue_text(id)+"\n\nOs materiais já estão reservados. Ao cancelar, as unidades ainda não concluídas são devolvidas. Saia do menu para o tempo passar."
	if int(game.rpg.construction.pieces[id].hp)<=float(ConstructionCatalog.piece(game.rpg.construction.pieces[id].kind).hp)*0.25:body+="\n\nProdução pausada: repare a estação."
	var actions:Array[Dictionary]=[]
	var jobs:Array=game.rpg.construction.queues.get(id,[])
	for i in jobs.size():actions.append({"label":"Cancelar pedido "+str(i+1),"name":"cancel_job_"+str(i),"callback":cancel_job.bind(id,i)})
	actions.append({"label":"Adicionar receita","callback":show_recipes.bind(id)})
	actions.append({"label":"Voltar à estação","callback":show_piece.bind(id)})
	actions.append({"label":"Continuar explorando","callback":game.close_dialog})
	game._open_dialog("FILA DE PRODUÇÃO","Pedidos",body,actions,"craft_queue")

func cancel_job(id:String,index:int)->void:
	if not near(id):return
	var result:=game.rpg.construction.cancel_job(game.rpg,id,index);game.save_journey();show_queue(id);game.hud.toast(result.message)

func show_assignments(id:String,slot:String,page:int=0)->void:
	if not near(id):return
	var ids:Array=game.world.npcs.keys()
	ids.sort_custom(func(a:String,b:String):return game.world.npcs[a].position.distance_squared_to(game.player.position)<game.world.npcs[b].position.distance_squared_to(game.player.position))
	var actions:Array[Dictionary]=[]
	for i in range(page*6,mini(ids.size(),page*6+6)):
		var profile:Dictionary=game.world.npcs[ids[i]].definition
		actions.append({"label":profile.name+" · "+profile.role,"name":"assign_"+profile.id,"callback":assign.bind(id,slot,profile.id)})
	if page>0:actions.append({"label":"Página anterior","callback":show_assignments.bind(id,slot,page-1)})
	if (page+1)*6<ids.size():actions.append({"label":"Próxima página","callback":show_assignments.bind(id,slot,page+1)})
	actions.append({"label":"Deixar sem designação","callback":assign.bind(id,slot,"")})
	actions.append({"label":"Voltar à estrutura","callback":show_piece.bind(id)})
	game._open_dialog("MORADORES","Escolher morador" if slot=="resident" else "Escolher trabalhador","Cada cama recebe um morador, e cada estação recebe um trabalhador. Reatribuir transfere a designação anterior. O NPC mantém suas pausas, passeios e descanso.",actions,"assignments")

func assign(id:String,slot:String,npc:String)->void:
	if not near(id):return
	var result:=game.rpg.construction.assign(game.rpg,id,npc,slot);game.save_journey();show_piece(id);game.hud.toast(result.message)

func repair(id:String)->void:
	if not near(id):return
	var result:=game.rpg.construction.repair(game.rpg,id);game.save_journey();show_piece(id);game.hud.toast(result.message)

func damage_obstacle(point:Vector2,amount:int)->void:
	if game.mode!="playing" or game.building_preview:return
	for id in game.rpg.construction.pieces:
		var rect:=ConstructionCatalog.collision(game.rpg.construction.pieces[id])
		if rect.has_area() and rect.grow(15).has_point(point):
			var result:=game.rpg.construction.damage(game.rpg,id,amount)
			if result.get("destroyed",false):game.hud.toast(result.message)
			game.save_journey();return
	for id in game.rpg.houses:
		var house:Dictionary=game.rpg.houses[id]
		if house.owner=="player" and house.stage>0 and game.rpg.home_rect(house).grow(15).has_point(point):
			var result:=game.rpg.damage_house(id,amount)
			if result.destroyed:game.hud.toast("Sua casa foi destruída. Você manteve o inventário.")
			game.save_journey();return

func toggle_door(id:String)->void:
	if not near(id):return
	var entry:Dictionary=game.rpg.construction.pieces[id]
	if entry.open:
		var shut:=entry.duplicate();shut.open=false;var rect:=ConstructionCatalog.collision(shut).grow(15)
		if rect.has_point(game.player.position):game.hud.toast("Afaste-se para fechar a porta.");return
		for npc in game.world.npcs.values():
			if not npc.sleeping and rect.has_point(npc.position):game.hud.toast("Espere o morador passar.");return
		for animal in game.world.animals.values():
			if animal.alive and rect.has_point(animal.position):game.hud.toast("Espere o animal passar.");return
	entry.open=not entry.open;game.rpg.construction.piece_changed.emit(id);game.rpg.changed.emit();game.save_journey();show_piece(id)

func rest_bed(id:String)->void:
	if not near(id) or not game.rpg.construction.pieces[id].resident.is_empty():return
	game.rpg.construction.player_bed=id
	game.rest_until_morning();game.hud.toast("Você descansou e salvou. Esta cama é seu ponto de retorno.")

func respawn()->Vector2:
	var id:=game.rpg.construction.player_bed
	if game.rpg.construction.pieces.has(id):return game.world.safe_position(ConstructionCatalog.approach(game.rpg.construction.pieces[id]))
	return Vector2(INF,INF)

func confirm_remove(id:String)->void:
	if not near(id):return
	game._open_dialog("DESMONTAR","Remover esta peça?","Você recupera até metade do custo, de acordo com a vida restante. Pedidos pendentes são cancelados e seus materiais reservados voltam à bolsa. Moradia e trabalho ligados à peça são liberados.",[{"label":"Manter a peça","callback":show_piece.bind(id)},{"label":"Desmontar","name":"confirm_remove","callback":remove.bind(id)}],"remove_structure")

func remove(id:String)->void:
	if not near(id):return
	var result:=game.rpg.construction.remove(game.rpg,id);game.save_journey();game.close_dialog();game.hud.toast(result.message)
