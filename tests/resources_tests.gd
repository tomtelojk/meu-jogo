extends SceneTree
var checks:=0
var failures:=0
var game:ForestGame
var graphics:=false
func _initialize()->void:
	var timer:=Timer.new();timer.wait_time=150;timer.one_shot=true;timer.autostart=true;root.add_child(timer);timer.timeout.connect(func():push_error("Resource test timeout");quit(1))
	graphics="--hybrid" in OS.get_cmdline_user_args();call_deferred("run")
func verify(ok:bool,label:String)->void:
	checks+=1
	if ok:print("PASS: "+label)
	else:failures+=1;push_error("FAIL: "+label)
func frames(count:int=3)->void:
	for i in count:await physics_frame;await process_frame
func capture(label:String)->void:
	if graphics:await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/tmp/reinos-coleta-"+label+".png")
func run()->void:
	var state:=RPGState.new()
	var tree:={"id":"test_tree","kind":"wood","position":Vector2(1200,1200)}
	verify(not state.strike_resource(tree,1).ok and state.resources.states.is_empty(),"sem ferramenta não altera vida nem cria drops")
	state.buy("axe");state.buy("pickaxe")
	verify(not state.strike_resource(tree,0).ok and state.resources.states.is_empty(),"sem energia o golpe é recusado sem alterar o recurso")
	var hit:=state.strike_resource(tree,1)
	verify(hit.ok and hit.hp==24 and not hit.finished and state.wood==0 and hit.cost>0,"primeiro golpe desconta vida e energia, sem material instantâneo")
	var snapshot:=state.save_data();var loaded:=RPGState.new();loaded.restore(JSON.parse_string(JSON.stringify(snapshot)))
	verify(loaded.resources.states.test_tree.hp==24,"vida parcial persiste depois de salvar e carregar")
	loaded.strike_resource(tree,1);hit=loaded.strike_resource(tree,1)
	verify(hit.finished and loaded.depleted.has(tree.id) and loaded.resources.states.test_tree.stage=="stump" and loaded.resources.states.test_tree.regrow==4,"árvore esgotada deixa toco com regeneração no terceiro dia seguinte")
	verify(loaded.wood==0 and loaded.resources.drops.size()>=3,"drops são objetos no chão antes de virarem inventário")
	var count:=loaded.resources.drops.size();var xp:=loaded.xp
	verify(not loaded.strike_resource(tree,1).ok and loaded.resources.drops.size()==count and loaded.xp==xp,"golpear árvore caída não duplica loot nem XP")
	loaded.resources.states.test_tree.hp=3
	verify(snapshot.resources.states.test_tree.hp==24,"snapshot não compartilha dicionários mutáveis com a partida")
	var hard:={"id":"test_hard","kind":"stone","type":"hard_stone","position":Vector2(1300,1300)}
	verify(not state.strike_resource(hard,1).ok,"picareta de madeira não quebra rocha dura")
	state.gold=500;state.wood=10;state.stone=20;state.iron=12
	verify(state.upgrade_tool("pickaxe").ok and state.resources.tier("pickaxe",state.tools)==2 and state.gold==460 and state.wood==5 and state.stone==10,"melhoria de pedra cobra moedas e materiais exatos")
	verify(state.strike_resource(hard,1).ok,"picareta de pedra consegue danificar rocha dura")
	var basalt:=hard.duplicate();basalt.id="test_basalt";basalt.type="basalt"
	verify(not state.strike_resource(basalt,1).ok,"basalto exige o tier de ferro")
	verify(state.upgrade_tool("pickaxe").ok and state.iron==6 and state.gold==370,"melhoria de ferro usa minério e moedas")
	verify(state.strike_resource(basalt,1).ok and not state.upgrade_tool("pickaxe").ok,"ferro rompe basalto e não permite cobrar um quarto tier")
	var ore:=hard.duplicate();ore.id="test_ore";ore.type="iron_ore"
	for i in 5:state.strike_resource(ore,1)
	var has_iron:=false
	for drop in state.resources.drops.values():has_iron=has_iron or drop.item=="iron"
	verify(has_iron,"tabela de minério gera ferro utilizável")
	var first:=ResourceProgress.new();var skilled:=ResourceProgress.new();skilled.skills.woodcutting=600
	var a:=first.strike(tree,{"axe":true},1);var b:=skilled.strike(tree,{"axe":true},1)
	verify(b.damage>a.damage and b.cost<a.cost,"nível de lenhador melhora dano e eficiência de energia")
	var restored:=RPGState.new();restored.restore(state.save_data())
	verify(restored.resources.tier("pickaxe",restored.tools)==3 and restored.resources.drops==state.resources.drops,"tiers, habilidades e drops pendentes sobrevivem ao save")
	var invalid:=ResourceProgress.new();invalid.restore({"states":{"bad":{"type":"wood","hp":"inválido","regrow":3,"x":1,"y":1}},"drops":{"bad":{"item":"gold","amount":500,"x":1,"y":1}},"tiers":{"axe":999},"skills":{"woodcutting":"bad"}})
	verify(invalid.states.is_empty() and invalid.drops.is_empty() and invalid.tiers.axe==3,"save inválido é filtrado e valores de tier são limitados")
	var doc:=MapDocument.blank();doc.objects.append({"id":"obj_ore","kind":"iron_ore","x":8000,"y":6400})
	verify(MapDocument.validate(doc).ok,"editor aceita depósitos de minério no mapa compartilhável")
	var map:=MapDocument.original()
	if graphics:
		map=MapDocument.blank();map.spawn=[8000,6500]
		map.objects=[{"id":"obj_test_tree","kind":"tree","x":8000,"y":6464,"size":145},{"id":"obj_copper","kind":"copper_ore","x":8220,"y":6500},{"id":"obj_iron","kind":"iron_ore","x":8300,"y":6400},{"id":"obj_basalt","kind":"basalt","x":7780,"y":6490},{"id":"obj_house","kind":"timber","x":7800,"y":6210}]
	MapDocument.activate(map);game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.start_journey();game.world.set_population_active(false);game.economy.set_process(false);game.player.set_physics_process(false)
	game.rpg.buy("axe");game.select_hotbar(1)
	if not graphics:game.player.position=KingdomData.point("aurelia_wood")+Vector2(0,160)
	game.world.ensure_region(game.player.position,true)
	game.audio.enabled=true;game.audio.impact(true)
	var wood_sound:AudioStreamWAV=game.audio.effect.stream
	game.audio.impact(false)
	verify(wood_sound.data.size()>0 and game.audio.effect.stream!=wood_sound,"impactos de madeira e pedra usam sons sintetizados distintos")
	var target:Dictionary={}
	var stand:=Vector2.ZERO
	for entry in game.world.resources.values():
		if entry.resource.kind!="wood" or not (entry.resource.id=="obj_test_tree" if graphics else entry.resource.id.begins_with("wood_aurelia_")):continue
		for i in 16:
			var candidate:Vector2=entry.resource.position+Vector2.from_angle(i*TAU/16)*36
			if not WorldData.can_stand(candidate,game.world.data,10):continue
			var closest:=true
			for other in game.world.resources.values():
				if other.resource.kind=="wood" and other.resource.position.distance_to(candidate)<35.9:closest=false;break
			if closest:target=entry;stand=candidate;break
		if not target.is_empty():break
	verify(not target.is_empty(),"teste usa uma árvore real do mundo carregado")
	if target.is_empty():quit(1);return
	var id:String=target.resource.id;var at:Vector2=target.resource.position
	game.player.position=stand;game.player.stamina=1
	if graphics:game.hybrid.camera.size=8;game.hybrid.snap_camera()
	await frames()
	if graphics:
		Input.warp_mouse(Vector2(950,500))
		var motion:=InputEventMouseMotion.new();motion.position=Vector2(950,500);motion.global_position=motion.position;Input.parse_input_event(motion)
		var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=Vector2(950,500);click.global_position=click.position;Input.parse_input_event(click)
		await frames(1);click=click.duplicate();click.pressed=false;Input.parse_input_event(click)
	else:game.use_equipped()
	verify(game.rpg.resources.states.has(id) and game.player.stamina<1 and target.resource.active,"clique com ferramenta equipada consome energia e mantém colisão enquanto a árvore vive")
	if not game.rpg.resources.states.has(id):quit(1);return
	var hp:int=game.rpg.resources.states[id].hp
	verify(not game.gathering.strike(id).ok and game.rpg.resources.states[id].hp==hp,"intervalo entre golpes impede spam no mesmo quadro")
	await capture("golpe")
	for i in 3:
		if game.rpg.depleted.has(id):break
		game.action_delay=0;game.gathering.strike(id)
	var amount:=0
	for drop in game.rpg.resources.drops.values():amount+=drop.amount
	verify(not target.resource.active and game.rpg.wood==0 and amount>=5,"queda libera colisão e cria os drops físicos antes da coleta")
	if graphics:
		verify(not game.hybrid.resource_fx.falls.is_empty() and not game.hybrid.resource_fx.fragments.is_empty(),"cena 3D exibe queda, fragmentos e números de dano")
	if graphics:await create_timer(0.5).timeout
	else:await frames(3)
	await capture("queda")
	var saved:=game.journey_data();var clone:=RPGState.new();clone.restore(saved.rpg)
	verify(clone.resources.drops.size()>0 and saved.stamina<1,"salvar durante a queda preserva loot pendente e energia")
	await frames(150)
	if graphics:game.player.position+=Vector2(80,45);game.hybrid.snap_camera();await frames()
	await capture("toco")
	verify(game.rpg.wood==amount and game.rpg.resources.drops.is_empty(),"imã recolhe todos os drops próximos exatamente uma vez")
	await frames(10)
	verify(game.rpg.wood==amount,"permanecer no local não concede material duplicado")
	var coord:=Vector2i((at/WorldData.CHUNK).floor());game.world._unload_chunk(coord);game.world._load_chunk(coord);game.world._reindex_active();await frames()
	verify(not game.world.resources.has(id) and game.rpg.depleted.has(id),"trocar de região conserva o toco e impede novo saque")
	game.player.position=at+Vector2(150,150);game.world.clock.set_time(9,3);game.gathering.regenerate();await frames()
	verify(game.rpg.depleted.has(id),"árvore não reaparece antes dos três dias completos")
	game.world.clock.set_time(8,4);game.gathering.regenerate()
	verify(game.rpg.depleted.has(id),"retorno respeita também o horário da coleta, sem adiantar pela virada do dia")
	game.player.position=at+Vector2(0,36);game.world.clock.set_time(9,4);game.gathering.regenerate()
	verify(game.rpg.depleted.has(id),"regeneração espera enquanto o jogador ocupa o local")
	game.player.position=at+Vector2(150,150);game.gathering.regenerate();await frames(6)
	verify(not game.rpg.depleted.has(id) and game.world.resources.has(id) and game.world.resources[id].resource.active,"após três dias a árvore retorna com colisão e navegação atualizadas")
	if graphics:
		verify(game.hybrid.landscape.resource_instances.has(id),"regeneração também recria a instância visual 3D")
	print("RESOURCES: %d verificações; %d falhas."%[checks,failures]);quit(1 if failures else 0)
