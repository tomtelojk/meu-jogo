extends SceneTree

var checks:=0
var failures:=0
var game:ForestGame
var graphics:=false
func _initialize()->void:
	var watchdog:=Timer.new();watchdog.wait_time=100;watchdog.one_shot=true;watchdog.autostart=true;root.add_child(watchdog);watchdog.timeout.connect(func():push_error("World life timeout");quit(1))
	root.size=Vector2i(1280,800);graphics="--hybrid" in OS.get_cmdline_user_args();call_deferred("run")
func verify(ok:bool,label:String)->void:
	checks+=1
	if ok:print("PASS: "+label)
	else:failures+=1;push_error("FAIL: "+label)
func frames(count:int=3)->void:
	for i in count:await physics_frame;await process_frame
func capture(label:String)->void:
	if not graphics:return
	await frames(4);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/reinos-"+label+".png")
func press_slot(index:int)->void:
	var key:=InputEventKey.new();key.physical_keycode=KEY_1+index;key.keycode=KEY_1+index;key.pressed=true;Input.parse_input_event(key)
	await frames(2);key=key.duplicate();key.pressed=false;Input.parse_input_event(key);await frames(1)
func run()->void:
	MapDocument.activate(MapDocument.original())
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await frames(4);await capture("inicio-pixel")
	verify(game.hud.serif is FontFile and game.hud.intro_title.text=="ENTRE REINOS","menu usa fonte bitmap própria e título simples")
	game.start_journey();game.world.clock.active=false;game.economy.set_process(false)
	await frames(3)
	verify(KingdomData.BUILDINGS.size()>=120 and game.world.npcs.size()==44,"continente mantém duas capitais populosas e quatro vilarejos")
	var xs:Dictionary={};var ys:Dictionary={}
	for building in KingdomData.BUILDINGS:
		xs[roundi(building.tile.x*64)]=true;ys[roundi(building.tile.y*64)]=true
	var aligned:=true;var curved:=false
	for building in KingdomData.BUILDINGS:
		var corner:=KingdomData.building_rect(building).position
		aligned=aligned and corner.snapped(Vector2.ONE*WorldGrid.CELL).is_equal_approx(corner)
	for path in KingdomData.NATURAL.roads:
		for i in range(2,path.size()):
			if absf((path[i]-path[i-1]).cross(path[i-1]-path[i-2]))>0.1:curved=true
	verify(aligned and curved and xs.size()>KingdomData.BUILDINGS.size()*0.4 and ys.size()>KingdomData.BUILDINGS.size()*0.4,"lotes variados seguem vias curvas e preservam o grid de 1 metro")
	var rebuilt:=SettlementLayout.generate(KingdomData.SETTLEMENTS,KingdomData.PLACES)
	verify(rebuilt.buildings==KingdomData.BUILDINGS,"bairros irregulares são reproduzíveis com a mesma semente")
	var grove:=NaturalLandscape.grove(KingdomData.point("aurelia_wood"),"wood")
	var heights:Dictionary={}
	for p in grove:heights[roundi(p.y)]=true
	verify(grove.size()==20 and heights.size()>15,"recursos de trabalho formam clareiras sem fileiras artificiais")
	verify(NaturalLandscape.field(Vector2(1000,1000))==NaturalLandscape.field(Vector2(1000,1000)) and NaturalLandscape.weights(Vector2(1000,1000))!=NaturalLandscape.weights(Vector2(12000,11500)),"biomas usam campos contínuos e determinísticos")
	var routines:Dictionary={}
	for profile in KingdomData.PEOPLE:routines[JSON.stringify(profile.routine)]=true
	verify(routines.size()>35,"moradores têm horários, locais e atividades distintos")
	var guard:ForestNPC=game.world.npcs.tomas
	game.world.ensure_region(KingdomData.point("guard_post"),true)
	guard.apply_schedule(10*60,true);guard.active=true
	var start:=guard.position
	var visited:Dictionary={}
	var patrol_stops:Dictionary={}
	for i in 320:
		guard.advance_offscreen(0.25);guard.update_brain(0.25,[],[])
		visited[Vector2i(guard.position/64)]=true
		patrol_stops[guard.stop_index]=true
	verify(visited.size()>6 and guard.current_schedule.loop and patrol_stops.size()>1,"guarda percorre uma patrulha real entre ponte e posto")
	game.player.position=KingdomData.point("guard_post");game.world.ensure_region(game.player.position,true)
	game.world.set_population_active(false);guard.active=true
	guard.apply_schedule(10*60,true);guard.waiting=0;guard._next_task();start=guard.position
	await frames(100)
	verify(guard.position.distance_to(start)>40 and WorldData.can_stand(guard.position,game.world.data,9),"patrulha também anda com a física real sem entrar em água ou paredes")
	var worker:ForestNPC=game.world.npcs.aurelia_resident_0
	worker.apply_schedule(10*60,true);worker.active=true
	start=worker.position
	visited.clear()
	for i in 180:
		worker.advance_offscreen(0.25);worker.update_brain(0.25,[],[]);visited[Vector2i(worker.position/64)]=true
	verify(worker.work_cycles>1 and visited.size()>2,"lenhador alterna pontos e pausas de trabalho durante o turno")
	worker.apply_schedule(23*60,true)
	verify(worker.wants_rest and worker.sleeping and not worker.visible,"morador retorna para descansar à noite")
	worker.apply_schedule(10*60,true)
	verify(not worker.sleeping and worker.visible,"morador retoma o trabalho pela manhã")
	var boar:=WorldAnimal.new();boar.setup({"id":"test_threat","species":"boar","position":worker.position+Vector2(64,0)},game);game.world.entities.add_child(boar);boar.active=false
	worker.update_brain(0.25,[],[boar])
	verify(worker.state=="flee" and worker.task_target.is_finite() and worker.task_target.x<worker.position.x,"civil procura abrigo ao perceber um javali")
	boar.queue_free()
	var account:=game.rpg.npc_account(worker.definition.id)
	account.tools.axe=true;account.wood=20;account.gold=40
	worker.hunger=0.2;worker.position=KingdomData.point("aurelia_shop");worker.apply_schedule(17.75*60)
	game.economy.advance_worker(worker,1)
	verify(account.wood==10 and account.gold==60,"lenhador vende a produção na visita ao comércio")
	worker.position=KingdomData.point("aurelia_inn");worker.hunger=0.9
	game.economy.advance_worker(worker,1)
	verify(account.gold==55 and worker.hunger<0.2,"morador paga por uma refeição quando fica com fome")
	var grid:=AStarGrid2D.new();grid.region=Rect2i(0,0,8,8);grid.cell_size=Vector2(64,64);grid.update()
	for y in 8:
		for x in 8:grid.set_point_solid(Vector2i(x,y),true)
	KingdomData.PLACES.test_recovery=Vector2(256,256)
	var profile:Dictionary=KingdomData.person("bento").duplicate(true);profile.id="test_recovery";profile.routine=[{"hour":0,"activity":"Teste","points":["test_recovery"]}]
	var trapped:=ForestNPC.new();trapped.setup(profile,game.player.default_frames,grid,600);game.world.entities.add_child(trapped);trapped.active=true
	verify(trapped.state=="blocked" and trapped.route.is_empty() and trapped.position.distance_to(Vector2.ZERO)<10,"rota impossível espera no local em vez de teleportar para outra região")
	for y in range(1,7):
		for x in range(1,7):grid.set_point_solid(Vector2i(x,y),false)
	trapped.position=Vector2(128,128);trapped.update_brain(6,[],[])
	verify(trapped.state!="blocked" and not trapped.route.is_empty(),"IA tenta novamente e recupera a rota quando o obstáculo some")
	trapped.queue_free();KingdomData.PLACES.erase("test_recovery")
	game.rpg.food=2;game.rpg.health=70
	await press_slot(4)
	verify(game.rpg.food==1 and game.rpg.health==100,"atalho de provisão usa o inventário real e recupera vida")
	await press_slot(7)
	verify(game.lantern_enabled and game.hud.hotbar.lantern,"atalho da lanterna altera o estado do equipamento")
	game.rpg.buy("axe");game.select_hotbar(1)
	verify(game.equipped_slot==1 and game.hud.hotbar.slot==1 and game.hud.hotbar.available(1),"hotbar seleciona e mostra ferramentas adquiridas")
	var save:=game.journey_data()
	verify(save.equipped_slot==1 and save.lantern and save.npcs.aurelia_resident_0.has("mind"),"save inclui equipamento, lanterna e necessidades dos NPCs")
	if graphics:
		game.player.position=WorldData.SPAWN;game.world.ensure_region(game.player.position,true);game.player.restore_surface();game.hybrid.snap_camera();game.world.clock.set_time(8.5)
		await capture("hud-dia")
		verify(game.hybrid.atmosphere.environment.fog_enabled and game.hybrid.atmosphere.environment.fog_depth_end>game.hybrid.atmosphere.environment.fog_depth_begin,"neblina de profundidade está ativa na cena 3D")
		var sun:=game.hybrid.sunlight.light_energy
		game.world.clock.set_time(21);await frames()
		verify(game.hybrid.sunlight.light_energy<sun and game.hybrid.lantern.visible,"ciclo noturno reduz o sol e mantém a lanterna acesa")
		var lamps:=0
		for lamp in game.hybrid.street_lamps:
			if lamp.visible:lamps+=1
		verify(lamps>0 and game.hybrid.lantern.omni_range>3,"postes e lanterna usam luzes locais de verdade")
		await capture("noite-neblina")
		game.hybrid.set_shaders(false)
		verify(not game.hybrid.atmosphere.environment.fog_enabled,"neblina pode ser desligada na opção de efeitos")
		game.hybrid.set_shaders(true);game.world.clock.set_time(7)
		game.player.position=KingdomData.REALMS.valverde.capital+Vector2(0,384);game.world.ensure_region(game.player.position,true);game.hybrid.snap_camera()
		await capture("valverde-amanhecer")
	var old:=MapDocument.original();old.erase("generation");old.id="mapa_legado"
	verify(MapDocument.validate(old).document.generation==1,"mapas editados de versões anteriores preservam o desenho da base antiga")
	print("WORLD LIFE: %d verificações; %d falhas."%[checks,failures]);quit(1 if failures else 0)
