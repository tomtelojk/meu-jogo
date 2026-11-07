class_name RelationshipSystem
extends Node

var game:ForestGame
var elapsed:=0.0
var last_goal:=Vector2(INF,INF)
var portrait_shader:Shader

func setup(source:ForestGame)->void:
	game=source;name="Relationships";bind_world()

func bind_world()->void:
	last_goal=Vector2(INF,INF);sync_population()

func state()->RelationshipState:return game.rpg.relationships
func day()->int:return game.world.clock.day
func near(id:String)->bool:return game.world.npcs.has(id) and not game.world.npcs[id].sleeping and game.world.npcs[id].position.distance_to(game.player.position)<=150 and (game.politics==null or game.politics.can_speak(game.world.npcs[id].definition))

func sync_population()->void:
	for id in game.world.npcs:
		var npc:ForestNPC=game.world.npcs[id]
		var following:bool=state().companion==id
		if following==npc.companion_mode:continue
		npc.companion_mode=following;npc.follow_target=npc.nearest_walkable(game.player.position+Vector2(64,64)) if following else Vector2(INF,INF);npc.economic_target=Vector2(INF,INF);npc.task_target=Vector2(INF,INF)
		npc.current_schedule={};npc.apply_schedule(game.world.clock.minute,false)
		if following:npc.sleeping=false;npc.wants_rest=false;npc.show();npc.refresh_presence()
	last_goal=Vector2(INF,INF)
	game.world.apply_assignments()

func _process(delta:float)->void:
	if game==null or game.mode!="playing" or game.building_preview:return
	elapsed+=delta
	if elapsed<0.45:return
	elapsed=0
	var id:=state().companion
	if id.is_empty():return
	if not game.world.npcs.has(id):state().companion="";return
	var person:=state().record(id);var npc:ForestNPC=game.world.npcs[id]
	if person.affinity<30 or person.debt>0 or person.bond=="rival":state().companion="";sync_population();game.save_journey();return
	if not npc.companion_mode:sync_population()
	if npc.hunger>0.8:
		var account:=game.rpg.npc_account(id)
		if account.food>0:account.food-=1;npc.hunger=0.1
		elif account.gold>=5:account.gold-=5;npc.hunger=0.1
		else:
			state().companion="";sync_population();game.hud.toast(npc.definition.name+" precisa se alimentar e voltou à própria rotina.");game.save_journey();return
	var target:Vector2=npc.nearest_walkable(game.player.position+Vector2(64,64))
	if game.player.swimming:target=npc.nearest_walkable(npc.position)
	if npc.position.distance_to(game.player.position)<80 and not game.player.swimming:target=npc.nearest_walkable(npc.position)
	if target!=last_goal or npc.state=="blocked":
		last_goal=target;npc.follow_target=target
		if npc.state!="flee":npc.task_target=Vector2(INF,INF);npc.waiting=0;npc.state="following";npc.plan_route()
	game.rpg.npc_account(id).job="Esperando na margem" if game.player.swimming else "Viajando em sua companhia"

func travel_with_player(memory:String="Vocês viajaram juntos de caravana.")->void:
	var npc:ForestNPC=game.world.npcs.get(state().companion)
	if npc==null:return
	npc.position=npc.nearest_walkable(game.player.position+Vector2(64,64));npc.follow_target=npc.position;npc.plan_route();last_goal=Vector2(INF,INF)
	state().remember(npc.definition.id,"travelled",day(),memory)

func after_action(result:Dictionary,id:String,refresh:bool=true)->void:
	sync_population();game.save_journey()
	if refresh:show_menu(id)
	if not String(result.get("message","")).is_empty():game.hud.toast(result.message,5)

func show_menu(id:String)->void:
	if not game.world.npcs.has(id):return
	reset_cinematic()
	var npc:ForestNPC=game.world.npcs[id]
	if near(id):state().visit(id,day())
	var person:=state().record(id)
	var body:="Afinidade: %+d / 100 · %s\n%s\n\n%s"%[person.affinity,state().bond_label(id),npc.activity(),state().reaction(id,day())]
	body+="\n\nSua classe: "+RelationshipCatalog.CLASSES[state().player_class]+" · "+RelationshipCatalog.FACTIONS[state().faction]
	var actions:Array[Dictionary]=[]
	if near(id):
		actions.append({"label":"Conversar com escolhas","name":"social_dialogue","callback":show_dialogue.bind(id,"start","")})
		actions.append({"label":"Dar um presente","name":"social_gifts","callback":show_gifts.bind(id)})
		actions.append({"label":"Missão pessoal","name":"social_quest","callback":show_quest.bind(id)})
		actions.append({"label":"Amizade, romance e companhia","name":"social_bonds","callback":show_bonds.bind(id)})
		if not state().pending.is_empty() and state().pending.npc==id:actions.append({"label":"Retomar encontro","name":"resume_event","callback":start_scene.bind(id,state().pending.event)})
		for event_id in ["friend","trust","rival"]:
			if state().event_available(game.rpg,id,event_id,day()).ok:actions.append({"label":"Encontro · "+RelationshipCatalog.event(event_id).name,"name":"event_"+event_id,"callback":start_scene.bind(id,event_id)})
	else:body+="\n\nAproxime-se para conversar e compartilhar presentes."
	actions.append({"label":"Lembranças e preferências","name":"social_memories","callback":show_memories.bind(id)})
	actions.append({"label":"Voltar à conversa","callback":game.open_npc.bind(id,"greeting")})
	actions.append({"label":"Continuar explorando","callback":game.close_dialog})
	game._open_dialog("LAÇOS ENTRE OS REINOS",npc.definition.name,body,actions,"relationships")
	var bar:=ProgressBar.new();bar.min_value=-100;bar.max_value=100;bar.value=person.affinity;bar.show_percentage=false;bar.custom_minimum_size.y=10
	bar.add_theme_stylebox_override("background",game.hud._style(Color("101822"),0));bar.add_theme_stylebox_override("fill",game.hud._style(Color("c77d72") if person.affinity<0 else Color("87aa82"),0))
	game.hud.modal_content.add_child(bar);game.hud.modal_content.move_child(bar,2);game.hud.call_deferred("_layout_modal")

func format_text(value:String,id:String)->String:
	var npc:ForestNPC=game.world.npcs[id];var profile:=RelationshipCatalog.profile(npc.definition)
	return value.format({"npc":npc.definition.name,"role":npc.definition.role,"realm":KingdomData.REALMS[npc.definition.realm].name,"story":profile.story,"activity":npc.activity().to_lower(),"reaction":state().reaction(id,day())})

func show_dialogue(id:String,node:String="start",reply:String="")->void:
	if not near(id):game.hud.toast("Aproxime-se do morador.");return
	var dialogue:=RelationshipCatalog.dialogue(node)
	if dialogue.is_empty():return
	var body:=format_text(dialogue.text,id)
	if not reply.is_empty():body=reply+"\n\n"+body
	var actions:Array[Dictionary]=[]
	for entry in dialogue.choices:
		var available:=state().conditions(game.rpg,id,entry.get("conditions",{}))
		if not state().conditions(game.rpg,id,dialogue.get("conditions",{})).ok:available=state().conditions(game.rpg,id,dialogue.conditions)
		var label:String=entry.label+("\n"+available.message if not available.ok else "")
		actions.append({"label":label,"name":"choice_"+entry.id,"disabled":not available.ok,"reason":available.message,"callback":choose.bind(id,node,entry.id)})
	if node!="start":actions.append({"label":"Outro assunto","callback":show_dialogue.bind(id,"start","")})
	actions.append({"label":"Relação e presentes","callback":show_menu.bind(id)})
	game._open_dialog("CONVERSA · AFINIDADE %+d"%state().record(id).affinity,game.world.npcs[id].definition.name,body,actions,"relationship_dialogue")

func choose(id:String,node:String,key:String)->void:
	if not near(id):return
	var result:=state().choice(game.rpg,id,node,key,day())
	sync_population();game.save_journey()
	if not result.ok:game.hud.toast(result.message);return
	match result.get("action",""):
		"tastes":show_memories(id);return
		"quest":show_quest(id);return
	show_dialogue(id,result.get("next","") if not String(result.get("next","")).is_empty() else "start",result.message)

func show_gifts(id:String)->void:
	if not near(id):return
	var person:=state().record(id);var actions:Array[Dictionary]=[]
	for item in RelationshipCatalog.GIFTS:
		var count:=game.rpg.construction.amount(game.rpg,item)
		var taste:String=RelationshipCatalog.TASTES[person.tastes[item]].name if person.tastes.has(item) else "preferência desconhecida"
		actions.append({"label":RelationshipCatalog.label(item).capitalize()+" ×%d · %s"%[count,taste],"name":"gift_"+item,"disabled":count==0,"callback":give_gift.bind(id,item)})
	actions.append({"label":"Voltar à relação","callback":show_menu.bind(id)})
	var remaining:=2-int(person.gift_count) if person.gift_day==day() else 2
	game._open_dialog("PRESENTES",game.world.npcs[id].definition.name,"Escolha uma unidade do seu inventário. Cada morador tem preferências próprias.\nPresentes restantes hoje: %d/2."%remaining,actions,"relationship_gifts")

func give_gift(id:String,item:String)->void:
	if not near(id):return
	var result:=state().gift(game.rpg,id,item,day());after_action(result,id,false);show_gifts(id)

func show_memories(id:String)->void:
	if not game.world.npcs.has(id):return
	var person:=state().record(id);var lines:=PackedStringArray()
	lines.append("PREFERÊNCIAS DESCOBERTAS")
	for item in person.tastes:lines.append(RelationshipCatalog.label(item).capitalize()+" · "+RelationshipCatalog.TASTES[person.tastes[item]].name)
	if person.tastes.is_empty():lines.append("Converse sobre gostos ou experimente um presente.")
	lines.append("\nLEMBRANÇAS RECENTES")
	for i in range(person.history.size()-1,maxi(-1,person.history.size()-9),-1):
		var entry:Dictionary=person.history[i];lines.append("Dia %d · %s"%[entry.day,entry.detail])
	game._open_dialog("MEMÓRIAS",game.world.npcs[id].definition.name,"\n".join(lines),[{"label":"Voltar à relação","callback":show_menu.bind(id)}],"relationship_memories")

func show_quest(id:String)->void:
	if not near(id):return
	var person:=state().record(id);var quest:Dictionary=RelationshipCatalog.profile(game.world.npcs[id].definition).quest
	var body:String=quest.request+"\n\n"
	if not quest.cost.is_empty():body+="Entrega: "+ConstructionCatalog.cost_text(quest.cost)+"\n"
	if quest.get("boars",0)>0:body+="Javalis afastados após aceitar: %d/%d\n"%[maxi(0,state().boars_killed-int(person.quest.boars)),quest.boars]
	body+="Recompensa: %d moedas · %d XP · +15 afinidade\nSituação: %s"%[quest.gold,quest.xp,{"none":"Não aceita","active":"Em andamento","complete":"Concluída","failed":"Promessa quebrada"}[person.quest.status]]
	var actions:Array[Dictionary]=[]
	if person.quest.status=="active":
		actions.append({"label":"Entregar e concluir","name":"complete_personal_quest","callback":quest_action.bind(id,"complete")})
		actions.append({"label":"Desistir da missão…","name":"abandon_personal_quest","callback":confirm_abandon.bind(id)})
	elif person.quest.status!="complete":
		var available:=state().quest_available(id,day())
		if not available.ok:body+="\n\n"+available.message
		actions.append({"label":"Aceitar missão","name":"accept_personal_quest","disabled":not available.ok,"reason":available.message,"callback":quest_action.bind(id,"accept")})
	actions.append({"label":"Voltar à relação","callback":show_menu.bind(id)})
	game._open_dialog("MISSÃO PESSOAL · "+game.world.npcs[id].definition.name,quest.title,body,actions,"personal_quest")

func quest_action(id:String,action:String)->void:
	if not near(id):return
	var result:Dictionary
	match action:
		"accept":result=state().accept_quest(game.rpg,id,day())
		"complete":result=state().complete_quest(game.rpg,id,day())
		_:result=state().abandon_quest(game.rpg,id,day())
	after_action(result,id,false);show_quest(id)

func confirm_abandon(id:String)->void:
	game._open_dialog("SEUS COMPROMISSOS","Abandonar este pedido?","O morador lembrará da promessa quebrada. Afinidade -8. Você poderá conversar novamente sobre a missão a partir de outro dia.",[{"label":"Manter o compromisso","callback":show_quest.bind(id)},{"label":"Desistir","name":"confirm_abandon","callback":quest_action.bind(id,"abandon")}],"abandon_quest")

func show_bonds(id:String)->void:
	if not near(id):return
	var person:=state().record(id);var profile:=RelationshipCatalog.profile(game.world.npcs[id].definition)
	var body:="%s · Afinidade %+d\n\nVocês se encontraram em %d dias diferentes. Amizade próxima e uma missão pessoal cumprida abrem novos caminhos. O NPC mantém seus próprios horários quando não está viajando com você."%[state().bond_label(id),person.affinity,person.days.size()]
	body+="\n\nRomance: afinidade 65, encontro Planos compartilhados e três dias de convivência.\nCasamento: afinidade 90, três dias de namoro, aliança e um lar preparado."
	var actions:Array[Dictionary]=[{"label":"Reconhecer amizade / fazer as pazes","name":"bond_friend","callback":bond_action.bind(id,"friend")},{"label":"Dispensar companheiro" if state().companion==id else "Convidar para viajar","name":"bond_companion","callback":bond_action.bind(id,"companion")}]
	if person.bond in ["dating","married"]:
		if person.bond=="dating":
			var available:=state().event_available(game.rpg,id,"wedding",day())
			actions.append({"label":"Trocar alianças e casar"+("\n"+available.message if not available.ok else ""),"name":"bond_marry","disabled":not available.ok,"reason":available.message,"callback":start_scene.bind(id,"wedding")})
		actions.append({"label":"Encerrar relacionamento…","name":"bond_breakup","callback":confirm_breakup.bind(id)})
	elif profile.romance:actions.append({"label":"Conversar sobre um romance","name":"bond_date","callback":bond_action.bind(id,"date")})
	actions.append({"label":"Pedir desculpas","name":"bond_apology","callback":bond_action.bind(id,"apology")})
	if person.debt>0:actions.append({"label":"Devolver %d moedas"%person.debt,"name":"bond_repay","callback":bond_action.bind(id,"repay")})
	actions.append({"label":"Declarar rivalidade…","name":"bond_rival","callback":confirm_rival.bind(id)})
	actions.append({"label":"Tentar roubar a bolsa…","name":"bond_steal","callback":confirm_steal.bind(id)})
	actions.append({"label":"Voltar à relação","callback":show_menu.bind(id)})
	game._open_dialog("ESCOLHAS E VÍNCULOS",game.world.npcs[id].definition.name,body,actions,"relationship_bonds")

func bond_action(id:String,action:String)->void:
	if not near(id):return
	var result:Dictionary
	match action:
		"friend":result=state().befriend(game.rpg,id,day())
		"date":result=state().start_dating(game.rpg,id,day())
		"companion":result=state().set_companion(game.rpg,id)
		"rival":result=state().rival(game.rpg,id,day())
		"steal":result=state().steal(game.rpg,id,day())
		"repay":result=state().repay(game.rpg,id,day())
		"apology":result=state().apologize(game.rpg,id,day())
		_:result=state().end_relationship(game.rpg,id,day())
	after_action(result,id,false);show_bonds(id)

func confirm_rival(id:String)->void:
	game._open_dialog("RIVALIDADE","Assumir esta disputa?","A afinidade ficará em -25 ou menos. O morador lembrará da rivalidade e recusará romance e companhia enquanto vocês não fizerem as pazes.",[{"label":"Voltar","callback":show_bonds.bind(id)},{"label":"Declarar rivalidade","name":"confirm_rival","callback":bond_action.bind(id,"rival")}],"rivalry")

func confirm_steal(id:String)->void:
	game._open_dialog("CONSEQUÊNCIAS","Tentar levar as moedas?","Você pode levar 6 moedas, mas o morador perceberá o roubo. Afinidade -25, reputação -4 e uma dívida que bloqueia a confiança. Ele lembrará mesmo depois da devolução.",[{"label":"Deixar a bolsa","callback":show_bonds.bind(id)},{"label":"Roubar 6 moedas","name":"confirm_steal","callback":bond_action.bind(id,"steal")}],"theft")

func confirm_breakup(id:String)->void:
	game._open_dialog("SEU RELACIONAMENTO","Seguir caminhos separados?","O vínculo romântico será encerrado. Memórias e amizade não são apagadas. Um companheiro de viagem será dispensado, e a cama reservada automaticamente será liberada.",[{"label":"Continuar juntos","callback":show_bonds.bind(id)},{"label":"Encerrar relacionamento","name":"confirm_breakup","callback":bond_action.bind(id,"breakup")}],"breakup")

func show_journal(page:int=0)->void:
	var ids:Array=state().people.keys();ids.sort_custom(func(a:String,b:String):return state().record(a).affinity>state().record(b).affinity)
	var actions:Array[Dictionary]=[];var body:String="Classe: "+RelationshipCatalog.CLASSES[state().player_class]+"\nFacção: "+RelationshipCatalog.FACTIONS[state().faction]+"\nReputação · Aurélia %+d · Valverde %+d\n\n"%[state().reputation.aurelia,state().reputation.valverde]
	for id in ids:
		if state().record(id).quest.status=="active":body+="Missão: "+KingdomData.person(id).name+" · "+RelationshipCatalog.profile(KingdomData.person(id)).quest.title+"\n"
	if ids.is_empty():body+="Converse com os moradores para começar sua história com eles."
	for i in range(page*6,mini(ids.size(),page*6+6)):
		var id:String=ids[i];actions.append({"label":KingdomData.person(id).name+" · %+d · %s"%[state().record(id).affinity,state().bond_label(id)],"callback":show_menu.bind(id)})
	if page>0:actions.append({"label":"Página anterior","callback":show_journal.bind(page-1)})
	if (page+1)*6<ids.size():actions.append({"label":"Próxima página","callback":show_journal.bind(page+1)})
	if not state().companion.is_empty():actions.append({"label":"Dispensar companheiro de viagem","name":"dismiss_companion","callback":dismiss_companion})
	actions.append({"label":"Minha classe e facção","name":"social_identity","callback":show_identity})
	actions.append({"label":"Continuar explorando","callback":game.close_dialog})
	game._open_dialog("DIÁRIO DE RELAÇÕES","Pessoas e compromissos",body,actions,"relationship_journal")

func dismiss_companion()->void:
	state().companion="";sync_population();game.save_journey();show_journal()

func show_identity()->void:
	var actions:Array[Dictionary]=[]
	for id in RelationshipCatalog.CLASSES:actions.append({"label":"Classe · "+RelationshipCatalog.CLASSES[id],"name":"class_"+id,"callback":identity_action.bind("class",id)})
	for id in RelationshipCatalog.FACTIONS:actions.append({"label":"Bandeira · "+RelationshipCatalog.FACTIONS[id],"name":"faction_"+id,"callback":identity_action.bind("faction",id)})
	actions.append({"label":"Voltar ao diário","callback":show_journal.bind(0)})
	game._open_dialog("SEU CAMINHO","Classe e facção","Atual: "+RelationshipCatalog.CLASSES[state().player_class]+" · "+RelationshipCatalog.FACTIONS[state().faction]+"\n\nA classe abre maneiras próprias de conversar. A primeira escolha é livre; reaprender custa 25 moedas. Você pode mudar de bandeira uma vez por dia. As reputações e as lembranças continuam guardadas.",actions,"relationship_identity")

func identity_action(kind:String,value:String)->void:
	var result:=state().set_identity(game.rpg,kind,value,day());game.save_journey();show_identity();game.hud.toast(result.message)

func start_scene(id:String,event_id:String)->void:
	if not near(id):game.hud.toast("Encontre o morador para viver esse momento.");return
	var result:=state().begin_event(game.rpg,id,event_id,day())
	if not result.ok:game.hud.toast(result.message);return
	game.save_journey();show_scene()

func show_scene()->void:
	if state().pending.is_empty():return
	var id:String=state().pending.npc;var event_id:String=state().pending.event;var step:int=state().pending.step
	if not game.world.npcs.has(id):return
	var event:=RelationshipCatalog.event(event_id)
	var actions:Array[Dictionary]=[{"label":"Concluir encontro" if step==event.pages.size()-1 else "Continuar","name":"scene_next","callback":advance_scene},{"label":"Pular para o desfecho","name":"scene_skip","callback":finish_scene},{"label":"Pausar encontro","name":"scene_pause","callback":game.close_dialog}]
	game._open_dialog("ENCONTRO · %d/%d"%[step+1,event.pages.size()],event.name,format_text(event.pages[step],id),actions,"relationship_scene")
	if game.hybrid!=null:game.hybrid.cinematic_focus=(game.player.position+game.world.npcs[id].position)/2
	for top in [true,false]:
		var bar:=ColorRect.new();bar.color=Color("080d16");bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		if top:bar.offset_bottom=40
		else:bar.offset_top=-40
		game.hud.modal.add_child(bar)
	var portraits:=HBoxContainer.new();portraits.alignment=BoxContainer.ALIGNMENT_CENTER;portraits.add_theme_constant_override("separation",40)
	for actor in [game.player,game.world.npcs[id]]:
		var box:=VBoxContainer.new();portraits.add_child(box)
		var picture:=TextureRect.new();picture.custom_minimum_size=Vector2(140,125);picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;picture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		picture.texture=actor.sprite.sprite_frames.get_frame_texture("idle_down",0)
		if portrait_shader==null:
			portrait_shader=Shader.new();portrait_shader.code="shader_type canvas_item; void fragment(){vec4 c=texture(TEXTURE,UV);c.a*=1.0-smoothstep(0.08,0.3,min(c.r,c.b)-c.g);COLOR=c;}"
		var material:=ShaderMaterial.new();material.shader=portrait_shader;picture.material=material;box.add_child(picture)
		var label:=game.hud._text("Você" if actor==game.player else actor.definition.name,12,game.hud.CREAM);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;box.add_child(label)
	game.hud.modal_content.add_child(portraits);game.hud.modal_content.move_child(portraits,2);game.hud.call_deferred("_layout_modal")

func advance_scene()->void:
	if state().pending.is_empty():return
	var definition:=RelationshipCatalog.event(state().pending.event)
	if int(state().pending.step)>=definition.pages.size()-1:finish_scene();return
	state().pending.step+=1;game.save_journey();show_scene()

func finish_scene()->void:
	if state().pending.is_empty():return
	var id:String=state().pending.npc;var wedding:bool=state().pending.event=="wedding"
	var result:=state().finish_event(game.rpg,day())
	if not result.ok:game.hud.toast(result.message);return
	if wedding:share_home(id)
	reset_cinematic();after_action(result,id)

func share_home(id:String)->void:
	var ids:Array=game.rpg.construction.pieces.keys();var player_bed:=game.rpg.construction.player_bed
	if player_bed.is_empty():
		for key in ids:
			var entry:Dictionary=game.rpg.construction.pieces[key]
			if entry.kind=="bed" and entry.resident.is_empty():player_bed=key;break
	if not game.rpg.construction.assigned(id,"resident").is_empty():return
	for key in ids:
		var entry:Dictionary=game.rpg.construction.pieces[key]
		if key!=player_bed and entry.kind=="bed" and entry.resident.is_empty():
			game.rpg.construction.assign(game.rpg,key,id,"resident");state().record(id).auto_bed=key;return

func reset_cinematic()->void:
	if game.hybrid!=null:game.hybrid.cinematic_focus=Vector2(INF,INF)
