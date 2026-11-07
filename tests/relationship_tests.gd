extends SceneTree

var checks:=0
var failures:=0
var graphics:=false
var game:ForestGame

func _initialize()->void:
	graphics="--hybrid" in OS.get_cmdline_user_args();root.size=Vector2i(1280,800)
	var timer:=Timer.new();timer.wait_time=180;timer.one_shot=true;timer.autostart=true;root.add_child(timer);timer.timeout.connect(func():push_error("Relações excederam 180 segundos");quit(1));call_deferred("run")
func verify(ok:bool,label:String)->void:
	checks+=1
	if ok:print("PASS: "+label)
	else:failures+=1;push_error("FAIL: "+label)
func frames(count:int=3)->void:
	for i in count:await physics_frame;await process_frame
func key(code:Key)->void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=true;Input.parse_input_event(event);await frames(1)
	event=event.duplicate();event.pressed=false;Input.parse_input_event(event);await frames(2)
func button(name:String)->void:
	var node:Button=game.hud.modal.find_child(name,true,false)
	verify(node!=null,"interface oferece "+name)
	if node==null:return
	if not graphics:
		if not node.disabled:node.pressed.emit()
		await frames(3);return
	await frames(2);game.hud.modal_scroll.ensure_control_visible(node);await frames(3)
	var point:=node.get_global_rect().get_center();Input.warp_mouse(point)
	var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;Input.parse_input_event(motion)
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;event.position=point;event.global_position=point;Input.parse_input_event(event);await frames(1)
	event=event.duplicate();event.pressed=false;Input.parse_input_event(event);await frames(3)
func capture(label:String)->void:
	if not graphics:return
	await frames(3);await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/tmp/relationships-"+label+".png")
func supplied()->RPGState:
	var state:=RPGState.new();state.gold=500;state.wood=300;state.stone=300;state.food=20;state.meat=20;state.iron=30;state.copper=30;state.tools["hammer"]=true
	for item in ConstructionCatalog.PROCESSED:state.construction.stock[item]=20
	state.construction.stock.wedding_ring=0
	return state
func run()->void:
	MapDocument.activate(MapDocument.original());RelationshipCatalog.load_data()
	var profiles:Dictionary={};var lunch:Dictionary={};var evening:Dictionary={}
	for npc in KingdomData.people():
		var profile:=RelationshipCatalog.profile(npc);profiles[JSON.stringify([profile.loves,profile.likes,profile.hates])]=true
		verify(profile.age>=18 and profile.loves.size()==2,"perfil adulto e preferências de "+npc.name)
		for entry in npc.routine:
			if entry.get("meal",false):lunch[npc.id]=true
			if entry.activity.to_lower().contains("taverna") or entry.activity.to_lower().contains("estalagem"):evening[npc.id]=true
	verify(profiles.size()>=10 and lunch.size()==44 and evening.size()==44,"preferências variam e todos os moradores têm almoço e encontro na taverna")
	var state:=supplied();var social:RelationshipState=state.relationships
	verify(social.record("bento").affinity==0 and social.record("iris").affinity==0,"cada NPC começa com afinidade independente")
	social.change("bento",150);social.change("iris",-150)
	verify(social.record("bento").affinity==100 and social.record("iris").affinity==-100,"afinidade é limitada de -100 a 100")
	social.record("bento").affinity=0
	var before:=state.construction.amount(state,"iron_ingot");var loved:=social.gift(state,"bento","iron_ingot",1)
	verify(loved.ok and loved.taste=="love" and loved.affinity==12 and state.construction.amount(state,"iron_ingot")==before-1,"presente amado consome uma unidade e concede +12")
	verify(state.npc_account("bento").goods.iron_ingot==1 and social.record("bento").tastes.iron_ingot=="love","NPC recebe o item e sua preferência fica descoberta")
	var hated:=social.gift(state,"bento","meat",1)
	verify(hated.ok and hated.affinity==-10 and social.record("bento").memories.has("gift_hate"),"presente odiado reduz afinidade e deixa memória")
	before=state.wood
	verify(not social.gift(state,"bento","wood",1).ok and state.wood==before,"terceiro presente no mesmo dia não cobra nem altera afinidade")
	verify(social.gift(state,"bento","stone_block",2).taste=="like","preferência de gostar possui reação própria")
	verify(social.gift(state,"bento","stone",2).taste=="neutral","item neutro tem resposta e bônus distintos")
	verify(not social.gift(state,"missing","food",2).ok and not social.gift(state,"bento","gold",3).ok,"presentes exigem NPC e material permitidos")
	state.wood=0;before=social.record("bento").affinity
	verify(not social.gift(state,"bento","wood",3).ok and social.record("bento").affinity==before,"presente ausente não gera amizade")
	verify(not social.choice(state,"bento","craft_reply","share_craft",3).ok,"condição de classe também protege uma resposta chamada diretamente")
	verify(social.set_identity(state,"class","artisan",3).ok and state.gold==500,"primeira escolha de classe é gratuita")
	var xp:=state.xp
	verify(social.choice(state,"bento","craft_reply","share_craft",3).ok and state.xp==xp+8,"escolha de classe concede consequências concretas")
	verify(not social.choice(state,"bento","craft_reply","share_craft",4).ok and state.xp==xp+8,"reabrir conversa especial não repete XP")
	verify(social.set_identity(state,"class","guardian",4).ok and state.gold==475,"reaprender classe cobra as moedas anunciadas")
	verify(social.set_identity(state,"faction","aurelia",4).ok and not social.set_identity(state,"faction","valverde",4).ok,"bandeira pode mudar apenas uma vez por dia")
	verify(social.conditions(state,"bento",{"faction":"aurelia","npc_realm":"aurelia"}).ok and not social.conditions(state,"iris",{"same_faction":true}).ok,"escolhas distinguem a bandeira do jogador e o reino do NPC")
	var standing:int=social.reputation.aurelia
	verify(social.choice(state,"bento","loyal_reply","shared_banner",4).ok and social.reputation.aurelia==standing+1 and not social.choice(state,"iris","loyal_reply","shared_banner",4).ok,"fala de facção muda reputação e é recusada fora da aliança")
	before=social.record("bento").affinity
	verify(social.choice(state,"bento","day","listen",4).ok and social.record("bento").affinity==before+3,"resposta acolhedora muda a afinidade")
	verify(not social.choice(state,"bento","day","listen",4).ok and social.record("bento").affinity==before+3,"conversa diária não pode ser repetida para farmar afinidade")
	verify(social.choice(state,"bento","day","listen",5).ok,"conversa positiva volta a contar no dia seguinte")
	var account:=state.npc_account("bento");var coins:=state.gold;var npc_coins:int=account.gold
	verify(social.steal(state,"bento",5).ok and state.gold==coins+6 and account.gold==npc_coins-6,"roubo transfere moedas de uma carteira real")
	verify(social.record("bento").debt==6 and social.reaction("bento",5).contains("roubo") and not social.conditions(state,"bento",{"no_debt":true}).ok,"NPC lembra do roubo e bloqueia confiança até reparação")
	verify(not social.steal(state,"bento",5).ok and state.gold==coins+6,"roubo repetido no mesmo dia não duplica moedas")
	verify(social.repay(state,"bento",6).ok and state.gold==coins and account.gold==npc_coins,"devolução restaura exatamente as carteiras")
	verify(social.record("bento").memories.has("stole") and social.record("bento").memories.has("repaid") and social.reaction("bento",6).contains("reconstruída"),"reparação não apaga a história anterior")
	social.record("bento").affinity=-10
	verify(social.apologize(state,"bento",6).ok and not social.apologize(state,"bento",6).ok,"desculpas têm efeito limitado a uma vez por dia")
	state.wood=100;social.record("bento").affinity=25
	verify(social.accept_quest(state,"bento",7).ok and social.record("bento").quest.status=="active","missão pessoal registra um compromisso")
	coins=state.gold;xp=state.xp;var wood:=state.wood
	verify(social.complete_quest(state,"bento",7).ok and state.wood==wood-8 and state.gold==coins+25 and state.xp==xp+25,"missão entrega recursos e recompensa corretos")
	verify(not social.complete_quest(state,"bento",7).ok and state.gold==coins+25,"missão concluída não repete recompensa")
	verify(social.record("bento").memories.has("helped") and social.reaction("bento",7).contains("roubo"),"memória de ajuda coexiste com a memória do roubo reparado")
	social.record("tomas").affinity=25;social.accept_quest(state,"tomas",7)
	verify(not social.complete_quest(state,"tomas",7).ok,"missão do guarda exige um javali afastado após ser aceita")
	social.boars_killed+=1
	verify(social.complete_quest(state,"tomas",7).ok,"progresso de combate permite concluir a missão do guarda")
	social.record("iris").affinity=25;social.accept_quest(state,"iris",7);social.abandon_quest(state,"iris",7)
	verify(social.record("iris").memories.has("broke_promise") and not social.accept_quest(state,"iris",7).ok and social.accept_quest(state,"iris",8).ok,"desistência deixa memória, penalidade e espera até outro dia")
	social.record("bento").affinity=30
	verify(social.begin_event(state,"bento","friend",8).ok and social.pending.step==0,"nível de amizade desbloqueia encontro pessoal")
	social.pending.step=1
	var saved:Dictionary=JSON.parse_string(JSON.stringify(state.save_data()));var clone:=RPGState.new();clone.restore(saved)
	verify(clone.relationships.pending.step==1 and clone.relationships.people.bento.memories.has("stole"),"save preserva página do encontro e lembranças")
	verify(clone.relationships.finish_event(clone,8).ok and clone.relationships.people.bento.events.has("friend"),"encontro retomado conclui o evento uma vez")
	before=clone.relationships.people.bento.affinity
	verify(not clone.relationships.begin_event(clone,"bento","friend",8).ok and clone.relationships.people.bento.affinity==before,"encontro repetido não concede afinidade novamente")
	var love:=supplied();var bonds:RelationshipState=love.relationships;var person:=bonds.record("lia")
	person.affinity=90;person.events.friend=true;person.events.trust=true;person.quest.status="complete"
	bonds.visit("lia",1);bonds.visit("lia",2)
	verify(not bonds.start_dating(love,"lia",2).ok,"romance exige convivência em três dias distintos")
	bonds.visit("lia",3)
	verify(bonds.start_dating(love,"lia",3).ok and bonds.partner=="lia" and person.bond=="dating","romance consensual registra um parceiro")
	var other:=bonds.record("iris");other.affinity=90;other.events.trust=true;other.quest.status="complete";other.days=[1,2,3]
	verify(not bonds.start_dating(love,"iris",3).ok,"novo romance respeita o relacionamento atual")
	verify(not bonds.event_available(love,"lia","wedding",4).ok,"casamento exige três dias de namoro")
	love.construction.stock.wedding_ring=1
	verify(not bonds.event_available(love,"lia","wedding",6).ok,"aliança não substitui a necessidade de um lar")
	love.houses.home_player={"owner":"player","x":7000,"y":6000,"stage":3,"hp":400}
	verify(bonds.begin_event(love,"lia","wedding",6).ok and love.construction.stock.wedding_ring==1,"cerimônia começa sem cobrar antes da conclusão")
	verify(bonds.finish_event(love,6).ok and person.bond=="married" and love.construction.stock.wedding_ring==0,"casamento consome uma aliança e persiste o vínculo")
	verify(not bonds.rival(love,"lia",6).ok and person.bond=="married","rivalidade não substitui silenciosamente um relacionamento existente")
	verify(not bonds.finish_event(love,6).ok and love.construction.stock.wedding_ring==0,"finalizar cerimônia novamente não duplica nem cobra item")
	verify(bonds.set_companion(love,"lia").ok and bonds.companion=="lia","amizade próxima e confiança permitem companhia")
	verify(bonds.end_relationship(love,"lia",7).ok and bonds.partner.is_empty() and bonds.companion.is_empty() and person.memories.has("married") and person.memories.has("broke_up"),"encerrar romance libera companhia e preserva a história")
	verify(bonds.rival(love,"lia",8).ok and person.affinity<=-25 and not bonds.start_dating(love,"lia",8).ok,"rivalidade é uma rota distinta que impede romance")
	person.affinity=30
	verify(bonds.befriend(love,"lia",9).ok and person.bond=="friend","reconciliação permite reconhecer amizade novamente")
	var child:=KingdomData.person("lia").duplicate(true);child.age=16
	verify(not RelationshipCatalog.profile(child).romance,"romance é oferecido somente por perfis adultos")
	var snapshot:=love.save_data();person.affinity=-100
	verify(snapshot.relationships.people.lia.affinity==30,"snapshot de relações não compartilha dicionários mutáveis")
	var malformed:=RelationshipState.new();malformed.restore({"people":{"missing":{"affinity":90},"bento":{"affinity":NAN,"bond":"married","days":[1,1,"x"],"memories":{"stole":{"count":INF,"day":1}},"events":{"fake":true},"quest":{"status":"bad"}}},"partner":"missing","companion":"bento","class":"bad","faction":"bad","pending":{"npc":"missing","event":"wedding","step":999}})
	verify(malformed.people.size()==1 and malformed.people.bento.affinity==0 and malformed.people.bento.bond=="friend" and malformed.people.bento.days==[1],"restore filtra NPCs, números inválidos, vínculos conflitantes e dias duplicados")
	verify(malformed.people.bento.memories.is_empty() and malformed.pending.is_empty() and malformed.companion.is_empty() and malformed.player_class=="wanderer" and malformed.faction=="free","save malformado não injeta parceiro, companhia ou eventos")
	var legacy:=RPGState.new();legacy.restore({"gold":45,"wood":12,"tools":["axe"]})
	verify(legacy.gold==45 and legacy.wood==12 and legacy.relationships.people.is_empty(),"saves anteriores mantêm inventário e iniciam relações sem perda")
	await integration()
	print("RELATIONSHIPS: %d verificações; %d falhas."%[checks,failures]);quit(1 if failures else 0)

func integration()->void:
	var document:=MapDocument.blank();document.id="social_fixture";document.spawn=[8000,6400]
	document.objects=[{"id":"obj_partner","kind":"npc","x":8064,"y":6400,"name":"Lia","appearance":"lia","realm":"aurelia"},{"id":"obj_neighbor","kind":"npc","x":7808,"y":6464,"name":"Bento","appearance":"bento","realm":"aurelia"},{"id":"obj_boar","kind":"boar","x":7600,"y":6700}]
	MapDocument.activate(MapDocument.validate(document).document)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.start_journey();game.world.set_population_active(false);game.economy.set_process(false);game.player.set_physics_process(false)
	game.rpg.gold=500;game.rpg.wood=200;game.rpg.stone=200;game.rpg.food=10;game.rpg.copper=20;game.rpg.iron=20;game.rpg.tools["hammer"]=true;game.rpg.tools["sword"]=true
	for item in ConstructionCatalog.PROCESSED:game.rpg.construction.stock[item]=20
	game.rpg.construction.stock.wedding_ring=0
	await frames(4)
	game.open_npc("obj_partner");await button("npc_relationships");await button("social_dialogue")
	verify(game.hud.modal.find_child("choice_artisan",true,false).disabled,"diálogo mostra escolha de classe bloqueada")
	await button("choice_artisan")
	verify(game.rpg.xp==0,"clique numa resposta bloqueada não concede efeitos")
	game.social.show_identity();await button("class_artisan");await button("faction_aurelia")
	verify(game.rpg.relationships.player_class=="artisan" and game.rpg.relationships.faction=="aurelia","interface permite escolher classe e facção")
	game.social.show_dialogue("obj_partner");await button("choice_artisan");await button("choice_share_craft")
	verify(game.rpg.xp==8 and game.rpg.relationships.record("obj_partner").affinity==4,"resposta liberada aplica XP, afinidade e memória")
	game.social.show_gifts("obj_partner");await button("gift_food");await button("gift_copper_ingot")
	game.social.show_dialogue("obj_partner","day");await button("choice_listen")
	var person:=game.rpg.relationships.record("obj_partner")
	verify(person.affinity==25 and person.tastes.copper_ingot=="love","presentes e conversa levam ao primeiro nível de amizade")
	game.social.show_menu("obj_partner");await capture("amizade");await button("event_friend")
	verify(game.hud.modal_kind=="relationship_scene" and not game.world.clock.active and game.rpg.relationships.pending.event=="friend","encontro inicia cena e pausa relógio e rotina")
	if graphics:verify(game.hybrid.cinematic_focus.is_finite() and game.hud.modal_content.find_children("*","TextureRect",true,false).size()==2,"cena usa câmera de encontro e retratos dos personagens")
	await capture("encontro");await button("scene_next")
	var saved:=game.journey_data();await key(KEY_ESCAPE);game.world.set_population_active(false)
	verify(game.mode=="playing" and game.rpg.relationships.pending.step==1,"Esc pausa a cena mantendo a página e o encontro pendente")
	if graphics:verify(not game.hybrid.cinematic_focus.is_finite(),"pausar a cena devolve o foco da câmera ao jogador")
	game.rpg.relationships.pending.step=0;game.apply_journey(saved)
	verify(game.rpg.relationships.pending.step==1,"carregar preserva página de uma cena em andamento")
	game.social.start_scene("obj_partner","friend");await button("scene_skip")
	person=game.rpg.relationships.record("obj_partner")
	verify(person.events.has("friend") and person.affinity==30,"desfecho conclui encontro e guarda a memória")
	game.social.show_quest("obj_partner");await button("accept_personal_quest");var coins:=game.rpg.gold;await button("complete_personal_quest")
	verify(person.quest.status=="complete" and game.rpg.gold==coins+30 and person.affinity==45,"missão pessoal é aceita e entregue pela interface")
	game.world.clock.set_time(10,2);game.social.give_gift("obj_partner","copper_ingot");game.social.give_gift("obj_partner","copper_ingot")
	game.social.show_dialogue("obj_partner","day");await button("choice_listen");game.social.show_menu("obj_partner");await button("event_trust");await button("scene_skip")
	verify(person.events.has("trust") and person.affinity==77,"segundo encontro depende de afinidade e missão cumprida")
	verify(not game.rpg.relationships.start_dating(game.rpg,"obj_partner",2).ok,"romance ainda espera convivência em mais um dia")
	game.world.clock.set_time(10,3);game.social.show_menu("obj_partner");await button("social_bonds");await button("bond_date")
	verify(person.bond=="dating" and game.rpg.relationships.partner=="obj_partner","escolha romântica recebe resposta e registra namoro")
	var first:=game.rpg.construction.place(game.rpg,"bed",Vector2i(124,102));var second:=game.rpg.construction.place(game.rpg,"bed",Vector2i(126,102));game.rpg.construction.player_bed=first.id
	var forge:=game.rpg.construction.place(game.rpg,"forge",Vector2i(128,98))
	verify(game.rpg.construction.enqueue(game.rpg,forge.id,"wedding_ring").ok,"forja aceita a receita de aliança")
	game.world.clock.advance(30)
	verify(game.rpg.construction.amount(game.rpg,"wedding_ring")==1,"fila real fabrica a aliança para o casamento")
	game.world.clock.set_time(10,5);game.social.show_bonds("obj_partner")
	verify(game.hud.modal.find_child("bond_marry",true,false).disabled,"pedido de casamento respeita tempo de namoro")
	game.world.clock.set_time(10,6);game.social.give_gift("obj_partner","copper_ingot");game.social.show_dialogue("obj_partner","day");await button("choice_listen")
	game.social.show_bonds("obj_partner");await button("bond_marry");await capture("casamento");await button("scene_skip")
	verify(person.bond=="married" and game.rpg.construction.amount(game.rpg,"wedding_ring")==0 and game.rpg.construction.pieces[second.id].resident=="obj_partner","cerimônia consome aliança e designa a cama compartilhada")
	game.world.clock.set_time(23,6);var npc:ForestNPC=game.world.npcs.obj_partner;npc.active=true
	for i in 150:npc.advance_offscreen(0.2)
	verify(npc.sleeping and npc.position.distance_to(npc.home_override)<11,"cônjuge retorna ao lar construído no horário de dormir")
	game.world.clock.set_time(10,7);game.player.position=npc.position+Vector2(0,32);game.social.show_bonds("obj_partner");await button("bond_companion")
	verify(npc.companion_mode and not npc.wants_rest and game.rpg.relationships.companion=="obj_partner","companheiro entra no grupo e suspende sua rotina de trabalho")
	game.close_dialog();game.world.set_population_active(false);game.player.position=Vector2(8352,6400)
	var start:=npc.position
	for i in 90:game.social._process(0.46);npc.active=true;npc.advance_offscreen(0.2)
	verify(npc.position.distance_to(start)>100 and npc.position.distance_to(game.player.position)<145 and WorldData.can_stand(npc.position,game.world.data,8),"companheiro percorre rota navegável até o jogador sem atravessar estruturas")
	if graphics:
		game.world.set_population_active(true);game.world.clock.active=false;game.hybrid.snap_camera();game.player.position+=Vector2(200,0);start=npc.position;game.social._process(0.5)
		var animated:=false
		for i in 25:
			await frames(1);animated=animated or npc.sprite.animation.begins_with("walk") or npc.sprite.animation.begins_with("run")
		verify(npc.position.distance_to(start)>5 and animated,"companheiro usa física e animação de caminhada ou corrida")
		await capture("companhia")
	game.world.set_population_active(false)
	game.player.swimming=true;var bank:=npc.position;game.social.last_goal=Vector2(INF,INF);game.social._process(0.5)
	verify(npc.follow_target.distance_to(bank)<65 and not WorldData.is_water(npc.follow_target),"companheiro aguarda em terreno seguro enquanto o jogador nada")
	game.player.swimming=false
	var path:="user://relationships-test-"+str(Time.get_ticks_usec())+".json";game.save_path=path;game.persistence=true;game.save_journey();game.persistence=false
	var disk:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path));game.rpg.relationships.people.clear();game.rpg.relationships.partner="";game.rpg.relationships.companion="";game.apply_journey(disk)
	person=game.rpg.relationships.record("obj_partner");npc=game.world.npcs.obj_partner
	verify(person.bond=="married" and game.rpg.relationships.companion=="obj_partner" and npc.companion_mode and person.memories.has("helped"),"save real restaura casamento, companhia, preferências e memórias")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path));game.world.set_population_active(false);game.player.set_physics_process(false)
	var position_before:=npc.position;game.social.dismiss_companion()
	verify(not npc.companion_mode and npc.position==position_before,"dispensar companheiro retoma a rotina sem teletransporte")
	game.world.clock.set_time(12.5,7);var eater:ForestNPC=game.world.npcs.obj_neighbor;eater.position=eater.nearest_walkable(eater._scheduled_point());eater.hunger=0.8
	var wallet:=game.rpg.npc_account("obj_neighbor");wallet.food=0;var meal_gold:int=wallet.gold
	game.economy.advance_meal(eater);game.economy.advance_meal(eater)
	verify(eater.hunger==0.1 and wallet.gold==meal_gold-5,"almoço previsto na rotina usa moedas do NPC só uma vez por turno")
	var meal_saved:=game.rpg.save_data();game.rpg.restore(meal_saved)
	verify(game.rpg.npc_account("obj_neighbor").meal_stamp==wallet.meal_stamp,"save preserva o horário da refeição para impedir nova cobrança")
	game.world.clock.set_time(10,7)
	game.close_dialog();game.world.set_population_active(false);game.player.position=Vector2(7808,6400);game.social.show_bonds("obj_neighbor")
	await button("bond_steal");await button("confirm_steal")
	var neighbor:=game.rpg.relationships.record("obj_neighbor")
	verify(neighbor.debt==6 and neighbor.memories.has("stole") and game.rpg.relationships.reaction("obj_neighbor",7).contains("roubo"),"roubo pela interface muda a reação e é lembrado pelo NPC")
	await capture("memoria");await button("bond_repay")
	verify(neighbor.debt==0 and neighbor.memories.has("repaid") and neighbor.memories.has("stole"),"devolver moedas repara a dívida sem apagar o roubo")
	var boar:WorldAnimal=game.world.animals.obj_boar;boar.active=false;game.close_dialog();game.world.set_population_active(false);game.player.position=boar.position+Vector2(30,0);boar.health=1;game.action_delay=0;game.attack()
	verify(game.rpg.relationships.boars_killed==1,"combate real alimenta o progresso de missões pessoais")
	var original:=MapDocument.current.duplicate(true);var relation_saved:=game.rpg.relationships.save_data()
	game.apply_map(MapDocument.blank());verify(game.rpg.relationships.people.is_empty(),"relações ficam isoladas entre mapas")
	game.apply_map(original);verify(game.rpg.relationships.save_data()==relation_saved,"voltar ao mapa recupera relações, missões e lembranças")
