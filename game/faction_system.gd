class_name FactionSystem
extends Node

var game:ForestGame
var posts:Array[Dictionary]=[]
var markers:Array[Node]=[]
var guard_origins:Dictionary={}
var guard_cooldowns:Dictionary={}
var timer:=0.0
var last_safe:=Vector2(INF,INF)
var gate_message:=0.0
var uniform_material:Material
var applied_uniform:="?"
var previous_clothing:=Color.WHITE

func state()->FactionState:return game.rpg.politics
func day()->int:return game.world.clock.day
func setup(source:ForestGame)->void:game=source;FactionCatalog.load_data();bind_world()
func bind_world()->void:
	guard_origins.clear();guard_cooldowns.clear();last_safe=Vector2(INF,INF);applied_uniform="?"
	for npc in game.world.npcs.values():npc.enforcement_target=Vector2(INF,INF)
	call_deferred("rebuild_posts")

func rebuild_posts()->void:
	for node in markers:
		if is_instance_valid(node):node.queue_free()
	markers.clear();posts.clear()
	if not MapDocument.base_enabled():return
	for id in FactionCatalog.data.guilds:
		if state().guild_available(id):add_post("guild",id,FactionCatalog.headquarters(id),FactionCatalog.guild(id).name)
	for id in FactionCatalog.data.territories:
		var town:=FactionCatalog.town(id)
		if not town.is_empty():add_post("territory",id,town.position+Vector2(0,640),"Posto de "+town.name)
	update_uniform()

func add_post(kind:String,id:String,point:Vector2,label:String)->void:
	point=game.world.safe_position(point)
	var color:=post_color(kind,id)
	var marker:=Node2D.new();marker.position=point;game.world.entities.add_child(marker);markers.append(marker)
	marker.draw.connect(func():
		marker.draw_rect(Rect2(-2,-76,4,76),Color("5c4633"))
		marker.draw_rect(Rect2(2,-76,34,22),post_color(kind,id))
		marker.draw_rect(Rect2(12,-71,5,12),Color("fff1cc")))
	var text:=Label.new();text.text=label;text.position=Vector2(-150,-106);text.size=Vector2(300,26);text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;text.add_theme_font_size_override("font_size",9);text.add_theme_color_override("font_outline_color",Color.BLACK);text.add_theme_constant_override("outline_size",4);marker.add_child(text)
	var entry:Dictionary={"kind":kind,"id":id,"point":point,"label":label,"marker":marker}
	if game.hybrid!=null:
		marker.hide()
		var root:=Node3D.new();root.position=Vector3(point.x/64,0,point.y/64);game.hybrid.add_child(root);markers.append(root)
		for part in [{"position":Vector3(0,0.6,0),"size":Vector3(0.055,1.2,0.055),"color":Color("5c4633")},{"position":Vector3(0.27,1.04,0),"size":Vector3(0.53,0.34,0.035),"color":color}]:
			var mesh:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=part.size;mesh.mesh=box;mesh.position=part.position
			var material:=StandardMaterial3D.new();material.albedo_color=part.color;material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mesh.material_override=material;root.add_child(mesh)
			if part.color==color:entry.flag_material=material
		var title:=Label3D.new();title.text=label;title.position=Vector3(0,1.6,0);title.billboard=BaseMaterial3D.BILLBOARD_ENABLED;title.font=load("res://assets/ui/rpg_pixel.fnt");title.font_size=10;title.pixel_size=0.012;title.no_depth_test=false;title.outline_size=3;root.add_child(title)
	posts.append(entry)

func post_color(kind:String,id:String)->Color:return Color(FactionCatalog.guild(id).color) if kind=="guild" else Color(FactionCatalog.faction(state().control(id)).color)
func refresh_flags()->void:
	for entry in posts:
		if is_instance_valid(entry.marker):entry.marker.queue_redraw()
		if entry.has("flag_material"):entry.flag_material.albedo_color=post_color(entry.kind,entry.id)
	game.hud.minimap.queue_redraw()

func nearby_interaction()->Dictionary:
	var closest:Dictionary={};var distance:=90.0
	for entry in posts:
		var d:float=game.player.position.distance_to(entry.point)
		if d<distance:closest={"kind":"politics_post","id":entry.id,"post_kind":entry.kind,"name":entry.label,"position":entry.point};distance=d
	return closest
func near_post(kind:String,id:String)->bool:
	for entry in posts:
		if entry.kind==kind and entry.id==id and game.player.position.distance_to(entry.point)<180:return true
	return false
func near_hq(id:String)->bool:
	var guild:=FactionCatalog.guild(id)
	return near_post("guild",id) or not guild.is_empty() and game.social.near(guild.master)
func at_service()->bool:
	for entry in posts:
		if game.player.position.distance_to(entry.point)<180:return true
	for id in ["aurel","caio"]:
		if game.social.near(id):return true
	return false

func _process(delta:float)->void:
	update_uniform()
	if game.mode!="playing":return
	gate_message=maxf(0,gate_message-delta);timer+=delta
	if timer<0.5:return
	timer=0;state().advance(day());state().visit(game.player.position)
	for id in guard_cooldowns:guard_cooldowns[id]=maxf(0,guard_cooldowns[id]-0.5)
	update_guards()

func _physics_process(_delta:float)->void:
	if game==null or game.mode!="playing" or not MapDocument.base_enabled():return
	for town in KingdomData.towns():
		if not town.capital or state().reputation(game.rpg,town.realm)>-30:continue
		var court:=Rect2(town.position-Vector2(600,760),Vector2(1200,1080))
		if court.has_point(game.player.position):
			game.player.position=last_safe if last_safe.is_finite() and not court.grow(20).has_point(last_safe) else game.world.safe_position(town.position+Vector2(0,480))
			game.player.velocity=Vector2.ZERO;game.player.restore_surface()
			if game.hybrid!=null:game.hybrid.snap_camera()
			if gate_message<=0:game.hud.toast("Entrada negada na praça de "+town.name+". Repare sua reputação em um posto.",5);gate_message=5
			return
	last_safe=game.player.position

func clear_guard(id:String)->void:
	if not game.world.npcs.has(id):guard_origins.erase(id);return
	var npc:ForestNPC=game.world.npcs[id];npc.enforcement_target=Vector2(INF,INF)
	npc.current_schedule={};npc.apply_schedule(game.world.clock.minute,false);guard_origins.erase(id)

func update_guards()->void:
	for id in game.world.npcs:
		var npc:ForestNPC=game.world.npcs[id]
		if not FactionCatalog.guard(npc.definition):continue
		var hostile:bool=state().reputation(game.rpg,npc.definition.realm)<=-60 and not npc.companion_mode
		var distance:=npc.position.distance_to(game.player.position)
		if not hostile or game.player.swimming or distance>900:
			if guard_origins.has(id):clear_guard(id)
			continue
		if float(guard_cooldowns.get(id,0))>0 or npc.sleeping:continue
		if not guard_origins.has(id):
			if distance>400:continue
			guard_origins[id]=npc.position;game.hud.toast(npc.definition.name+": você é procurado. Afaste-se ou será multado!",5)
		if npc.position.distance_to(guard_origins[id])>900:clear_guard(id);guard_cooldowns[id]=10;continue
		npc.enforcement_target=npc.nearest_walkable(game.player.position);npc.waiting=0;npc.state="pursuit";npc.plan_route();npc.refresh_presence()
		if distance<32:
			var fine:=mini(10,game.rpg.gold);game.rpg.gold-=fine;game.rpg.npc_account(id).gold+=fine
			var away:Vector2=guard_origins[id].direction_to(game.player.position)
			if away==Vector2.ZERO:away=Vector2.DOWN
			game.player.position=game.world.safe_position(npc.position+away*250);game.player.restore_surface()
			state().log_event(day(),"A patrulha de "+FactionCatalog.faction(npc.definition.realm).name+" o retirou da área e cobrou %d moedas."%fine)
			clear_guard(id);guard_cooldowns[id]=20;game.rpg.changed.emit();game.save_journey();game.hud.toast("A patrulha o retirou da área · multa de %d moedas. Procure reparação no posto."%fine,6)
			if game.hybrid!=null:game.hybrid.snap_camera()

func can_speak(profile:Dictionary)->bool:
	return state().reputation(game.rpg,profile.realm)>-60 or game.rpg.relationships.record(profile.id).affinity>=30
func trade_allowed(town:String)->bool:
	var access:=state().trade_access(game.rpg,town)
	if access.ok:return true
	game._open_dialog("COMÉRCIO E REPUTAÇÃO","Entrada negada",access.message,[{"label":"Facções e reparação","callback":show_overview},{"label":"Continuar explorando","callback":game.close_dialog}],"trade_denied")
	game.hud.toast(access.message);return false
func reaction(profile:Dictionary)->String:
	var realm:String=profile.realm;var score:=state().reputation(game.rpg,realm)
	var line:String="%s · %s (%+d). "%[FactionCatalog.faction(realm).name,FactionCatalog.standing(score),score]
	if score<=-60:return line+"A patrulha está à sua procura. Moradores que ainda não confiam em você recusam conversa."
	if score<=-30:return line+"A praça da capital e o comércio estão fechados para você."
	if score<0:return line+"Os comerciantes exigem preços 25% maiores por desconfiança."
	if score>=70:return line+"Você é recebido como herói e paga 20% menos no comércio."
	if score>=30:return line+"Os moradores reconhecem sua ajuda. Desconto de 10% no comércio."
	return line+"Você é recebido como viajante."

func update_uniform()->void:
	if game==null or game.player==null or game.player.sprite==null:return
	var sprite:=game.player.sprite
	if applied_uniform==state().uniform and sprite.material==uniform_material:return
	if sprite.material!=uniform_material:
		previous_clothing=Color.WHITE
		if sprite.material is ShaderMaterial:
			var value:Variant=sprite.material.get_shader_parameter("clothing_tint")
			if value is Color:previous_clothing=value
			sprite.material=sprite.material.duplicate()
	uniform_material=sprite.material;applied_uniform=state().uniform
	if sprite.material is ShaderMaterial:sprite.material.set_shader_parameter("clothing_tint",previous_clothing if applied_uniform.is_empty() else Color(FactionCatalog.guild(applied_uniform).color))

func after(result:Dictionary,refresh:Callable)->void:
	update_uniform();refresh_flags();game.save_journey();refresh.call();game.hud.toast(result.message)
func show_overview()->void:
	var body:String="Sua bandeira: "+RelationshipCatalog.FACTIONS[game.rpg.relationships.faction]+"\n\n";var actions:Array[Dictionary]=[]
	for realm in FactionCatalog.data.factions:
		var score:=state().reputation(game.rpg,realm);body+="%s · %s (%+d)\n%s\n\n"%[FactionCatalog.faction(realm).name,FactionCatalog.standing(score),score,FactionCatalog.faction(realm).ideology]
	for id in FactionCatalog.data.guilds:
		var member:=state().guild_record(id);actions.append({"label":FactionCatalog.guild(id).name+" · "+(FactionCatalog.rank_name(member.marks) if member.member else "Não filiado"),"name":"guild_"+id,"callback":show_guild.bind(id)})
	actions.append({"label":"Territórios e postos","name":"politics_territories","callback":show_territories})
	actions.append({"label":"As cartas das duas Coroas","name":"politics_story","callback":show_story})
	actions.append({"label":"Reparação e acontecimentos","name":"politics_history","callback":show_history})
	actions.append({"label":"Minha bandeira e classe","callback":game.social.show_identity})
	actions.append({"label":"Voltar à aventura","callback":game.close_dialog})
	game._open_dialog("FACÇÕES E GUILDAS","Seu nome entre os reinos",body,actions,"politics")

func show_guild(id:String)->void:
	var guild:=FactionCatalog.guild(id);var member:=state().guild_record(id);var rank:=FactionCatalog.rank(member.marks)
	var body:String=guild.ideology+"\n\nQG: "+guild.hq+"\nMestre: "+KingdomData.person(guild.master).get("name",guild.master)+"\nRank: "+(FactionCatalog.rank_name(member.marks)+" · %d méritos"%member.marks if member.member else "Não filiado")+"\nUniforme: "+guild.uniform+"\n\n";var actions:Array[Dictionary]=[]
	if not state().guild_access(game.rpg,id,false).ok:body+=state().guild_access(game.rpg,id,false).message+"\n"
	if not near_hq(id):body+="Vá ao QG (bandeira no mapa) ou encontre o mestre para filiação, loja e entregas.\n"
	var available:bool=near_hq(id) and state().guild_access(game.rpg,id,false).ok
	if not member.member:actions.append({"label":"Filiar-se · 20 moedas + uniforme","name":"guild_join","disabled":not available,"callback":guild_action.bind(id,"join","")})
	else:
		if not member.job.is_empty():
			var task:=state().mission(id,member.job.id);body+="CONTRATO: "+task.name+"\n"+task.request+"\nEntrega: "+ConstructionCatalog.cost_text(task.cost)+"\n"
			if task.has("boars"):body+="Javalis: %d/%d\n"%[maxi(0,game.rpg.relationships.boars_killed-int(member.job.boars)),task.boars]
			if task.has("visit"):body+="Visita após aceitar: "+("concluída" if member.job.visited else "pendente")+"\n"
			actions.append({"label":"Entregar contrato","name":"guild_complete","disabled":not available,"callback":guild_action.bind(id,"complete","")})
			actions.append({"label":"Abandonar contrato","name":"guild_abandon","callback":guild_action.bind(id,"abandon","")})
		else:
			for task in guild.missions:actions.append({"label":task.name+" · "+FactionCatalog.data.ranks[int(task.rank)].name+" · +%d méritos · %d moedas\n%s"%[task.marks,task.gold,task.request],"name":"mission_"+task.id,"disabled":not available or rank<int(task.rank),"callback":guild_action.bind(id,"accept",task.id)})
		for item in guild.shop:actions.append({"label":"Loja · "+item.name+" · "+FactionCatalog.data.ranks[int(item.rank)].name+" · %d moedas"%item.price,"name":"guild_buy_"+item.id,"disabled":not available or rank<int(item.rank),"callback":guild_action.bind(id,"buy",item.id)})
		actions.append({"label":"Guardar uniforme" if state().uniform==id else "Vestir "+guild.uniform,"name":"guild_uniform","disabled":not state().guild_access(game.rpg,id).ok,"callback":guild_action.bind(id,"uniform","")})
	actions.append({"label":"Voltar às facções","callback":show_overview});actions.append({"label":"Continuar explorando","callback":game.close_dialog})
	game._open_dialog("GUILDA · RANK %d/4"%(rank+1),guild.name,body,actions,"guild")

func guild_action(id:String,action:String,key:String)->void:
	if action in ["join","accept","complete","buy"] and not near_hq(id):game.hud.toast("Encontre o mestre ou visite o QG da guilda.");return
	var result:Dictionary
	match action:
		"join":result=state().join(game.rpg,id,day())
		"accept":result=state().accept(game.rpg,id,key,day())
		"complete":result=state().complete(game.rpg,id,day())
		"abandon":result=state().abandon(game.rpg,id)
		"buy":result=state().purchase(game.rpg,id,key,day())
		"uniform":result=state().equip(game.rpg,"" if state().uniform==id else id)
		_:return
	after(result,show_guild.bind(id))

func show_territories()->void:
	var body:="Cada posto muda de administração quando a influência chega a +60 (Aurélia) ou -60 (Valverde). Um apoio por posto a cada dia; sem manutenção, a influência perde dois pontos por dia em direção ao centro. O controle é mantido até a outra facção construir maioria.\n\n";var actions:Array[Dictionary]=[]
	if not MapDocument.base_enabled():body+="Os postos das Coroas pertencem ao continente original."
	else:
		for id in FactionCatalog.data.territories:
			var owner:=state().control(id);body+="%s · %s · influência %+d\n"%[FactionCatalog.territory(id).name,FactionCatalog.faction(owner).name,state().territories[id].influence]
			actions.append({"label":"Posto de "+FactionCatalog.territory(id).name,"name":"territory_"+id,"callback":show_post.bind(id)})
	actions.append({"label":"Abrir mapa político","callback":game.show_map});actions.append({"label":"Voltar às facções","callback":show_overview})
	game._open_dialog("FRONTEIRAS VIVAS","Territórios em disputa",body,actions,"territories")

func show_post(id:String)->void:
	var owner:=state().control(id);var body:String="Administração: "+FactionCatalog.faction(owner).name+"\nInfluência: %+d\n\n"%state().territories[id].influence+"A administração define a bandeira, os preços e as restrições do comércio local. Escolha a quem destinar recursos. A ajuda favorece uma Coroa e desagrada a outra.\n";var actions:Array[Dictionary]=[]
	if not near_post("territory",id):body+="\nVisite a bandeira ao sul do povoado para entregar apoio."
	for realm in FactionCatalog.data.factions:
		for kind in FactionCatalog.data.support:
			var action:Dictionary=FactionCatalog.data.support[kind]
			actions.append({"label":"%s · %s\n%s · reputação %+d / rival %+d"%[FactionCatalog.faction(realm).name,action.name,ConstructionCatalog.cost_text(action.cost),action.reputation,action.rival],"name":"support_"+realm+"_"+kind,"disabled":not near_post("territory",id),"callback":support_action.bind(id,realm,kind)})
	actions.append({"label":"Reparação e diplomacia","callback":show_history});actions.append({"label":"As cartas das duas Coroas","callback":show_story});actions.append({"label":"Voltar aos territórios","callback":show_territories});actions.append({"label":"Continuar explorando","callback":game.close_dialog})
	game._open_dialog("POSTO DE FRONTEIRA",FactionCatalog.territory(id).name,body,actions,"territory_post")
func support_action(id:String,realm:String,kind:String)->void:
	if not near_post("territory",id):game.hud.toast("Aproxime-se da bandeira do posto.");return
	after(state().support(game.rpg,id,realm,kind,day()),show_post.bind(id))

func show_history()->void:
	var body:="Reparação entrega 15 moedas e duas provisões aos moradores: até +15 reputação, uma vez por reino a cada dia. Visite qualquer QG ou posto; a ajuda pode ser oferecida mesmo durante hostilidade.\n\n";var actions:Array[Dictionary]=[]
	for realm in FactionCatalog.data.factions:actions.append({"label":"Reparar com "+FactionCatalog.faction(realm).name,"name":"repair_"+realm,"disabled":not at_service(),"callback":repair_action.bind(realm)})
	for i in range(state().history.size()-1,maxi(-1,state().history.size()-9),-1):body+="Dia %d · %s\n"%[state().history[i].day,state().history[i].message]
	actions.append({"label":"Voltar às facções","callback":show_overview})
	game._open_dialog("DIPLOMACIA E MEMÓRIA","Seu rastro no continente",body,actions,"politics_history")
func repair_action(realm:String)->void:
	if not at_service():game.hud.toast("Visite um QG ou posto para reparar sua reputação.");return
	after(state().repair_reputation(game.rpg,realm,day()),show_history)

func show_story()->void:
	var body:="Três etapas formam sua carta: compromisso (4 provisões), obra comum (4 tábuas + 4 blocos), e ratificação (2 lingotes de ferro + 6 tábuas). Cada etapa dá 40 XP.\n\n";var actions:Array[Dictionary]=[]
	for realm in FactionCatalog.data.factions:body+=FactionCatalog.faction(realm).name+": "+state().narrative(game.rpg,realm)+"\n\n"
	body+="Sem bandeira, o Pacto dos Caminhos exige confiança nos dois reinos e favorece ambos. Uma aliança com uma Coroa melhora sua reputação em +12 e reduz a rival em -6 por etapa. O pacto dá +6 nas duas.\n\nEtapa %d/3 · %s"%[state().story.step,state().story.ending if not String(state().story.ending).is_empty() else "A história continua"]
	if state().story.step<3:
		for path in ["aurelia","valverde","accord"]:
			var available:=state().story_available(game.rpg,path)
			actions.append({"label":({"aurelia":"Carta das Oficinas","valverde":"Liga dos Conselhos","accord":"Pacto dos Caminhos"}[path])+"\n"+(available.message if not available.ok else "Firmar a próxima etapa no QG, posto ou com um rei"),"name":"story_"+path,"disabled":not available.ok or not at_service(),"callback":story_action.bind(path)})
	actions.append({"label":"Voltar às facções","callback":show_overview});actions.append({"label":"Continuar explorando","callback":game.close_dialog})
	game._open_dialog("AS DUAS COROAS","Uma carta muda os caminhos",body,actions,"faction_story")
func story_action(path:String)->void:
	if not at_service():game.hud.toast("Encontre um rei ou visite um posto ou QG para firmar o compromisso.");return
	after(state().advance_story(game.rpg,path,day()),show_story)
