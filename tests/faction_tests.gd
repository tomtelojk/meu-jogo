extends SceneTree

var checks:=0
var failures:=0
var graphics:=false
var game:ForestGame
func _initialize()->void:
	graphics="--hybrid" in OS.get_cmdline_user_args();root.size=Vector2i(1280,800)
	var timeout:=Timer.new();timeout.wait_time=160;timeout.one_shot=true;timeout.autostart=true;root.add_child(timeout);timeout.timeout.connect(func():push_error("Facções excederam 160 segundos");quit(1));call_deferred("run")
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
		await frames();return
	await frames(2);game.hud.modal_scroll.ensure_control_visible(node);await frames(3)
	var point:=node.get_global_rect().get_center();Input.warp_mouse(point)
	var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;Input.parse_input_event(motion)
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;event.position=point;event.global_position=point;Input.parse_input_event(event);await frames(1)
	event=event.duplicate();event.pressed=false;Input.parse_input_event(event);await frames(3)
func capture(label:String)->void:
	if graphics:await frames();await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/tmp/factions-"+label+".png")
func supplies()->RPGState:
	var rpg:=RPGState.new();rpg.gold=2000;rpg.wood=300;rpg.stone=300;rpg.food=100;rpg.copper=100;rpg.iron=100
	for item in ConstructionCatalog.PROCESSED:rpg.construction.stock[item]=100
	return rpg
func run()->void:
	MapDocument.activate(MapDocument.original());FactionCatalog.load_data()
	verify(FactionCatalog.data.guilds.size()==3 and FactionCatalog.data.territories.size()==4,"três guildas e quatro postos são definidos em JSON")
	verify(FactionCatalog.faction("aurelia").ideology!=FactionCatalog.faction("valverde").ideology,"os reinos têm ideologias e histórias diferentes")
	for data in [[-100,"Hostil"],[-30,"Hostil"],[-29,"Neutro"],[29,"Neutro"],[30,"Aliado"],[69,"Aliado"],[70,"Herói"],[100,"Herói"]]:verify(FactionCatalog.standing(data[0])==data[1],"faixa de reputação em %+d"%data[0])
	var rpg:=supplies();var state:FactionState=rpg.politics
	state.change_reputation(rpg,"aurelia",250,1,"Ajuda",-250)
	verify(rpg.relationships.reputation=={"aurelia":100,"valverde":-100},"reputação compartilhada com relações é limitada e rival responde")
	verify(not state.trade_access(rpg,"valverde").ok and state.trade_access(rpg,"aurelia").ok,"hostilidade recusa comércio sem bloquear reino aliado")
	verify(is_equal_approx(state.trade_factor(rpg,"aurelia"),0.8),"herói recebe desconto de vinte por cento")
	rpg.relationships.reputation.aurelia=-1
	var gold:=rpg.gold;rpg.buy("axe","player",state.trade_factor(rpg,"aurelia"))
	verify(rpg.gold==gold-32,"desconfiança cobra 25 por cento a mais e arredonda o preço mostrado")
	rpg.relationships.reputation.aurelia=30;gold=rpg.gold;rpg.buy("pickaxe","player",state.trade_factor(rpg,"aurelia"))
	verify(rpg.gold==gold-27,"compra de aliado cobra o desconto real")
	rpg.relationships.reputation.aurelia=0;gold=rpg.npc_account("bento").gold;rpg.buy("axe","bento")
	verify(rpg.npc_account("bento").gold==gold-25,"economia dos moradores conserva o preço base")
	gold=rpg.gold;var food:=rpg.food
	verify(state.repair_reputation(rpg,"valverde",2).ok and rpg.gold==gold-15 and rpg.food==food-2 and state.reputation(rpg,"valverde")==-85,"reparação hostil usa moedas e provisões reais")
	verify(not state.repair_reputation(rpg,"valverde",2).ok and rpg.gold==gold-15,"reparação não pode ser repetida no mesmo dia")
	verify(not state.repair_reputation(rpg,"aurelia",2).ok,"reparação neutra não permite farmar reputação positiva")
	rpg=supplies();state=rpg.politics
	for id in FactionCatalog.data.guilds:
		gold=rpg.gold;verify(state.join(rpg,id,1).ok and rpg.gold==gold-20,"filiação com custo próprio em "+id)
		verify(not state.join(rpg,id,1).ok and rpg.gold==gold-20,"filiação duplicada não cobra em "+id)
	verify(not state.accept(rpg,"artisans","forge",1).ok,"contrato veterano fica bloqueado para aprendiz")
	verify(state.accept(rpg,"artisans","planks",1).ok and not state.accept(rpg,"artisans","planks",1).ok,"cada guilda permite somente um contrato ativo")
	gold=rpg.gold;var wood:=rpg.construction.amount(rpg,"plank")
	verify(state.complete(rpg,"artisans",1).ok and rpg.gold==gold+18 and rpg.construction.amount(rpg,"plank")==wood-4,"entrega paga e consome os materiais exatos")
	verify(rpg.npc_account("bento").goods.plank==4 and state.guild_record("artisans").marks==20,"mestre recebe os materiais e méritos ficam no rank")
	verify(not state.complete(rpg,"artisans",1).ok and not state.accept(rpg,"artisans","planks",1).ok,"contrato pago não repete recompensa no dia")
	state.accept(rpg,"artisans","planks",2);state.complete(rpg,"artisans",2)
	verify(FactionCatalog.rank_name(state.guild_record("artisans").marks)=="Membro","méritos promovem automaticamente ao próximo rank")
	verify(state.accept(rpg,"artisans","masonry",2).ok,"promoção abre contrato exclusivo de alvenaria")
	state.complete(rpg,"artisans",2);state.accept(rpg,"artisans","masonry",3);state.complete(rpg,"artisans",3)
	verify(FactionCatalog.rank_name(state.guild_record("artisans").marks)=="Veterano","contratos diferentes levam ao rank veterano")
	state.accept(rpg,"artisans","forge",3);state.complete(rpg,"artisans",3);state.accept(rpg,"artisans","forge",4);state.complete(rpg,"artisans",4)
	verify(FactionCatalog.rank_name(state.guild_record("artisans").marks)=="Mestre","rank mestre tem progressão alcançável")
	gold=rpg.gold;wood=rpg.wood
	verify(state.purchase(rpg,"artisans","timber",4).ok and rpg.gold==gold-12 and rpg.wood==wood+8,"loja própria entrega um lote com custo real")
	verify(not state.purchase(rpg,"artisans","timber",4).ok and rpg.wood==wood+8,"estoque diário da guilda impede repetir o mesmo lote")
	verify(not state.purchase(rpg,"caravans","copper",4).ok,"rank de outra guilda não libera mercadoria avançada")
	verify(state.equip(rpg,"artisans").ok and state.uniform=="artisans","filiação libera uniforme equipável")
	rpg.relationships.reputation.aurelia=-60
	verify(not state.purchase(rpg,"artisans","blocks",5).ok and not state.accept(rpg,"artisans","planks",5).ok and state.guild_record("artisans").marks==180,"hostilidade suspende serviços mas mantém progressão")
	rpg.relationships.reputation.aurelia=0
	state.accept(rpg,"watch","boar",6)
	verify(not state.complete(rpg,"watch",6).ok,"contrato de defesa exige combate posterior à aceitação")
	rpg.relationships.boars_killed+=1;verify(state.complete(rpg,"watch",6).ok,"javali afastado progride o contrato de defesa")
	state.accept(rpg,"watch","boar",7);rpg.relationships.boars_killed+=1;state.complete(rpg,"watch",7)
	state.accept(rpg,"caravans","rations",6);state.complete(rpg,"caravans",6);state.accept(rpg,"caravans","rations",7);state.complete(rpg,"caravans",7)
	state.accept(rpg,"caravans","route",8)
	verify(not state.complete(rpg,"caravans",8).ok,"descoberta antiga não substitui visita após aceitar")
	state.visit(FactionCatalog.town("cedro").position);verify(state.complete(rpg,"caravans",8).ok,"visita real e provisões concluem contrato de caravana")
	state.accept(rpg,"watch","post",8);wood=rpg.wood;state.abandon(rpg,"watch")
	verify(state.guild_record("watch").job.is_empty() and rpg.wood==wood,"abandonar limpa o compromisso sem cobrar recursos")
	rpg=supplies();state=rpg.politics;wood=rpg.wood
	verify(state.control("pedra_alta")=="aurelia","posto começa sob administração original")
	for day in range(1,5):verify(state.support(rpg,"pedra_alta","valverde","fortify",day).ok,"apoio à facção rival no dia %d"%day)
	verify(state.control("pedra_alta")=="valverde" and state.territories.pedra_alta.changes==1 and rpg.wood==wood-32,"influência sustentada muda administração e consome recursos")
	verify(rpg.relationships.reputation=={"aurelia":-16,"valverde":32},"ações territoriais favorecem uma Coroa e irritam outra")
	verify(not state.support(rpg,"pedra_alta","aurelia","relief",4).ok,"trocar de bandeira não contorna o limite diário do posto")
	verify(FactionCatalog.town_faction(rpg,"pedra_alta")=="valverde" and is_equal_approx(state.trade_factor(rpg,"pedra_alta"),0.9),"mercado do território passa a usar a nova reputação")
	state.advance(30);verify(state.control("pedra_alta")=="valverde","influência que esfria não muda o controle sem ação rival")
	rpg.relationships.reputation.valverde=-60
	verify(not state.support(rpg,"cedro","valverde","relief",31).ok,"facção hostil recusa representação até reparação")
	for path in ["aurelia","valverde","accord"]:
		var campaign:=supplies();campaign.relationships.reputation={"aurelia":60,"valverde":60};campaign.relationships.faction="free" if path=="accord" else path
		verify(campaign.politics.advance_story(campaign,path,1).ok and campaign.politics.story.step==1,"primeira etapa da história: "+path)
		verify(not campaign.politics.advance_story(campaign,path,1).ok,"história exige ação no mundo antes da segunda etapa: "+path)
		campaign.politics.contracts_completed=2
		verify(campaign.politics.advance_story(campaign,path,2).ok and campaign.politics.advance_story(campaign,path,3).ok,"aliança chega a um desfecho próprio: "+path)
		gold=campaign.xp;verify(not campaign.politics.advance_story(campaign,path,4).ok and campaign.xp==gold and not String(campaign.politics.story.ending).is_empty(),"desfecho não repete bônus: "+path)
		verify(campaign.politics.narrative(campaign,"aurelia")!=FactionCatalog.faction("aurelia").story,"rei reconhece a história alterada: "+path)
	var saved:Variant=JSON.parse_string(JSON.stringify(rpg.save_data()));var restored:=RPGState.new();restored.restore(saved)
	verify(restored.politics.control("pedra_alta")=="valverde" and restored.relationships.reputation==rpg.relationships.reputation,"JSON preserva controle e reputação compartilhada")
	restored.politics.restore({"guilds":{"artisans":{"member":true,"marks":INF,"job":{"id":"invalid"}}},"uniform":"unknown","territories":{"cedro":{"owner":"invalid","influence":INF}},"story":{"path":"aurelia","step":999},"history":[null,{"message":"Registro seguro","day":"ruim"}],"reparations":[]})
	verify(restored.politics.guild_record("artisans").marks==0 and restored.politics.uniform=="" and restored.politics.control("cedro")=="valverde","save malformado não injeta rank, uniforme ou administração inválida")
	restored.restore({"gold":123,"relationships":{"reputation":{"aurelia":35}}})
	verify(restored.gold==123 and restored.relationships.reputation.aurelia==35 and restored.politics.story.step==0,"save antigo migra sem perder ouro ou reputação")
	await integration()
	print("FACTIONS: %d verificações; %d falhas."%[checks,failures]);quit(0 if failures==0 else 1)

func integration()->void:
	MapDocument.activate(MapDocument.original());game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.start_journey();await frames(6)
	game.economy.set_process(false);game.world.clock.set_time(10);game.player.set_physics_process(false);game.politics.set_process(false)
	verify(game.politics.posts.size()==7,"QGs e postos têm sete bandeiras no mundo")
	game.rpg.gold=1000;game.rpg.food=30;game.rpg.wood=100;game.rpg.stone=100;game.rpg.construction.stock.plank=30
	game.player.position=game.politics.posts[0].point;game.world.ensure_region(game.player.position,true)
	await key(KEY_J);verify(game.hud.modal.find_child("journal_factions",true,false)!=null,"diário oferece facções ao lado dos relacionamentos")
	await key(KEY_TAB);await key(KEY_ENTER);verify(game.hud.modal_kind=="politics","J, Tab e Enter abrem facções sem depender do mouse")
	await capture("reputacao");await button("guild_artisans");await button("guild_join")
	verify(game.rpg.politics.guild_record("artisans").member and game.rpg.gold==980,"filiação funciona pela interface real")
	var original_color:Variant=game.player.sprite.material.get_shader_parameter("clothing_tint")
	await button("guild_uniform");game.politics.update_uniform()
	verify(game.rpg.politics.uniform=="artisans" and game.player.sprite.material.get_shader_parameter("clothing_tint")==Color(FactionCatalog.guild("artisans").color),"uniforme altera a roupa do sprite sem alterar a reputação")
	await button("mission_planks");await button("guild_complete")
	verify(game.rpg.politics.guild_record("artisans").marks==20 and game.rpg.construction.stock.plank==26,"contrato pela interface desconta tábuas e concede méritos")
	await capture("guilda");await button("guild_uniform");game.politics.update_uniform()
	verify(game.player.sprite.material.get_shader_parameter("clothing_tint")==original_color,"guardar uniforme restaura a roupa original")
	game.close_dialog();game.player.position=FactionCatalog.town("cedro").position;game.politics.guild_action("artisans","buy","timber")
	verify(game.rpg.wood==100,"chamada de loja remota não contorna a distância do QG")
	for post in game.politics.posts:
		if post.kind=="territory" and post.id=="cedro":game.player.position=post.point
	await frames();game.interact();verify(game.hud.modal_kind=="territory_post","E na bandeira abre o posto real")
	await button("support_aurelia_fortify");verify(game.rpg.politics.support_count==1 and game.rpg.wood==92,"apoio de território funciona por botão")
	await capture("territorio");game.close_dialog();game.show_map();await frames()
	var map_views:Array=game.hud.modal.find_children("*","Control",true,false).filter(func(node:Node):return node is ForestMinimap)
	verify(game.hud.modal_kind=="map" and map_views.size()==1 and map_views[0].rpg_state==game.rpg,"mapa político usa o estado real da aventura depois do apoio")
	await capture("mapa");game.close_dialog()
	game.rpg.relationships.reputation.aurelia=-40;gold_check()
	game.rpg.relationships.reputation.aurelia=0;game.close_dialog();game.politics.show_overview();await button("politics_story");await capture("historia");game.close_dialog()
	game.player.position=KingdomData.REALMS.aurelia.capital;game.rpg.relationships.reputation.aurelia=-35;game.politics.last_safe=Vector2(INF,INF);game.politics._physics_process(0.016)
	verify(not Rect2(KingdomData.REALMS.aurelia.capital-Vector2(600,760),Vector2(1200,1080)).has_point(game.player.position),"hostilidade impede entrar na praça da capital a pé")
	game.rpg.relationships.reputation.aurelia=0;game.rpg.relationships.reputation.valverde=-65
	var guard:ForestNPC=game.world.npcs.tomas
	game.player.position=game.world.safe_position(KingdomData.point("guard_post"));guard.position=guard.nearest_walkable(game.player.position+Vector2(160,0));guard.sleeping=false;guard.wants_rest=false;guard.active=true
	game.world.ensure_region(game.player.position,true);game.politics.update_guards()
	verify(guard.enforcement_target.is_finite() and guard.activity().contains("Perseguindo"),"guarda identifica reputação muito hostil e inicia perseguição")
	var initial:=guard.position;var animated:=false
	for i in 25:await frames(1);animated=animated or String(guard.sprite.animation).begins_with("run_")
	verify(guard.position.distance_to(initial)>8 and animated,"perseguição usa navegação, física e animação de corrida")
	game.rpg.relationships.reputation.valverde=0;game.politics.update_guards();verify(not guard.enforcement_target.is_finite(),"guarda retoma rotina quando a hostilidade termina")
	game.rpg.relationships.reputation.valverde=-65;guard.position=game.player.position+Vector2(10,0);game.politics.guard_cooldowns.clear();var gold:=game.rpg.gold;game.politics.update_guards()
	verify(game.rpg.gold==gold-10 and game.politics.guard_cooldowns.get("tomas",0)>0,"captura cobra multa real e dá tempo para sair")
	game.rpg.relationships.reputation.valverde=0
	game.save_path="user://faction-test.journey.json";game.persistence=true;game.save_journey()
	var disk:Variant=JSON.parse_string(FileAccess.get_file_as_string(game.save_path));var marks:int=game.rpg.politics.guild_record("artisans").marks;game.rpg.politics.guild_record("artisans").marks=0
	verify(game.apply_journey(disk) and game.rpg.politics.guild_record("artisans").marks==marks and game.rpg.politics.support_count==1,"save real em disco restaura guilda, méritos e apoio territorial")
	game.persistence=false;DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path))
	var custom:=MapDocument.blank();custom.id="faction_isolation";custom.objects=[{"id":"obj_shop","kind":"forge","x":7520,"y":6208,"name":"Forja do autor","realm":"valverde"}];game.apply_map(custom);await frames(5)
	verify(game.politics.posts.is_empty() and not game.rpg.politics.support(game.rpg,"cedro","aurelia","relief",1).ok,"mapa vazio não recebe postos ou territórios invisíveis")
	game.rpg.gold=100;var food_before:=game.rpg.food;game.buy_item("obj_shop","bread")
	verify(game.hud.modal_kind=="shop" and game.rpg.gold==95 and game.rpg.food==food_before+1,"ferraria criada no editor continua vendendo sem pertencer a um posto")
	game.rpg.wood=15;game.rpg.stone=8;game.deliver_order("obj_shop")
	verify(game.rpg.gold==175 and game.rpg.relationships.reputation.valverde==4,"encomenda de comércio personalizado tem nome e facção válidos")
	game.apply_map(MapDocument.original());await frames(5)
	verify(game.rpg.politics.guild_record("artisans").marks==marks,"retornar ao continente recupera sua progressão política")
	if graphics:
		verify(game.politics.posts[0].has("flag_material"),"bandeiras têm representação no cenário 3D")
		game.rpg.politics.equip(game.rpg,"artisans");game.politics.update_uniform();game.hybrid._process(0.1)
		verify(game.hybrid.actors[0].card.material_override.get_shader_parameter("clothing_tint")==Color(FactionCatalog.guild("artisans").color),"uniforme também chega ao billboard 3D")
	game.queue_free();await frames()
func gold_check()->void:
	var coins:=game.rpg.gold;game.buy_item("aurelia","bread")
	verify(game.hud.modal_kind=="trade_denied" and game.rpg.gold==coins,"callback de compra não burla bloqueio por reputação")
