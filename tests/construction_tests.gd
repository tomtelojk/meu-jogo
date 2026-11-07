extends SceneTree

var checks:=0
var failures:=0
var game:ForestGame
var graphics:=false

func _initialize()->void:
	graphics="--hybrid" in OS.get_cmdline_user_args();root.size=Vector2i(1280,800)
	var timeout:=Timer.new();timeout.wait_time=170;timeout.one_shot=true;timeout.autostart=true;root.add_child(timeout)
	timeout.timeout.connect(func():push_error("Construção excedeu 170 segundos");quit(1));call_deferred("run")

func verify(ok:bool,label:String)->void:
	checks+=1
	if ok:print("PASS: "+label)
	else:failures+=1;push_error("FAIL: "+label)

func frames(count:int=3)->void:
	for i in count:await physics_frame;await process_frame

func key(code:Key)->void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=true;Input.parse_input_event(event);await frames(1)
	event=event.duplicate();event.pressed=false;Input.parse_input_event(event);await frames(2)

func click(point:Vector2)->void:
	Input.warp_mouse(point)
	var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;Input.parse_input_event(motion)
	var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;Input.parse_input_event(event);await frames(1)
	event=event.duplicate();event.pressed=false;Input.parse_input_event(event);await frames(2)

func button(name:String)->void:
	var node:Button=game.hud.modal.find_child(name,true,false)
	verify(node!=null,"interface oferece "+name)
	if node==null:return
	if not graphics:node.pressed.emit();await frames(3);return
	game.hud.modal_scroll.ensure_control_visible(node);await frames(2);await click(node.get_global_rect().get_center())

func capture(name:String)->void:
	if not graphics:return
	await frames(3);await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/tmp/construction-"+name+".png")

func supplied()->RPGState:
	var state:=RPGState.new();state.wood=500;state.stone=500;state.copper=100;state.iron=100;state.tools.hammer=true;state.construction.stock.plank=30
	return state

func run()->void:
	MapDocument.activate(MapDocument.original());ConstructionCatalog.load_data()
	verify(ConstructionCatalog.pieces.size()==12 and ConstructionCatalog.recipes.size()==11,"catálogo e receitas vêm do JSON incluído no projeto")
	var categories:Dictionary={}
	for entry in ConstructionCatalog.pieces.values():categories[entry.category]=true
	verify(categories.size()==4,"catálogo cobre paredes, chão, móveis e estações")
	var state:=supplied();var build:ConstructionState=state.construction
	state.tools.clear();var before:=state.wood
	verify(not build.place(state,"wood_wall",Vector2i(100,100)).ok and state.wood==before,"peça sem martelo não cobra material")
	state.tools.hammer=true
	verify(not build.place(state,"invalid",Vector2i(100,100)).ok and not build.place(state,"bed",Vector2i(-1,5)).ok,"peças desconhecidas e posições fora do mundo são rejeitadas")
	var wall:=build.place(state,"wood_wall",Vector2i(100,100))
	verify(wall.ok and state.wood==before-5 and build.pieces[wall.id].hp==120,"parede consome custo exato e nasce com vida completa")
	before=state.wood
	verify(not build.place(state,"stone_wall",Vector2i(100,100)).ok and state.wood==before,"sobreposição na mesma camada é rejeitada sem cobrar")
	verify(build.place(state,"wood_floor",Vector2i(100,100)).ok and build.place(state,"roof",Vector2i(100,100)).ok,"chão e cobertura compartilham célula com a parede")
	var bed:=build.place(state,"bed",Vector2i(103,100),1)
	verify(bed.ok and ConstructionCatalog.footprint(build.pieces[bed.id]).size==Vector2(128,64),"rotação gira a área ocupada por móveis com duas células")
	verify(not build.place(state,"table",Vector2i(104,100)).ok,"segunda célula de uma cama também impede sobreposição")
	var damage:=build.damage(state,wall.id,60)
	verify(damage.ok and not damage.destroyed and build.pieces[wall.id].hp==60,"dano preserva a estrutura enquanto há vida")
	before=state.wood
	verify(build.repair_cost(wall.id)=={"wood":2} and build.repair(state,wall.id).ok and state.wood==before-2,"reparo cobra material proporcional ao dano")
	before=state.wood
	verify(not build.repair(state,wall.id).ok and state.wood==before,"reparo em vida cheia não cobra novamente")
	verify(build.assign(state,bed.id,"bento","resident").ok and build.assigned("bento","resident")==bed.id,"cama recebe um morador conhecido")
	var bed2:=build.place(state,"bed",Vector2i(107,100))
	verify(build.assign(state,bed2.id,"bento","resident").ok and build.pieces[bed.id].resident.is_empty(),"reatribuir residência libera a cama anterior")
	verify(not build.assign(state,wall.id,"bento","resident").ok and not build.assign(state,bed.id,"missing","resident").ok,"designações exigem estrutura apropriada e NPC existente")
	var workbench:=build.place(state,"workbench",Vector2i(110,100))
	verify(build.assign(state,workbench.id,"bento","worker").ok and build.assigned("bento","resident")==bed2.id,"o mesmo NPC pode ter casa e trabalho próprios")
	verify(not build.enqueue(state,workbench.id,"iron_ingot").ok,"receita de fundição não funciona numa bancada de madeira")
	before=state.wood;var planks:=build.amount(state,"plank")
	verify(build.enqueue(state,workbench.id,"plank",3).ok and state.wood==before-6,"fila reserva todos os ingredientes uma única vez")
	build.advance(state,3)
	verify(build.queues[workbench.id][0].remaining==5 and build.amount(state,"plank")==planks,"produção parcial guarda tempo restante sem antecipar saída")
	var saved:Dictionary=JSON.parse_string(JSON.stringify(state.save_data()))
	var clone:=RPGState.new();clone.restore(saved)
	verify(clone.construction.queues[workbench.id][0].remaining==5 and clone.wood==state.wood and clone.construction.pieces==build.pieces,"JSON restaura filas pagas, móveis, orientação, vida e designações")
	clone.construction.advance(clone,5)
	verify(clone.construction.amount(clone,"plank")==planks+2 and clone.construction.queues[workbench.id][0].count==2,"primeira unidade conclui após o tempo restante do save")
	before=clone.wood
	verify(clone.construction.cancel_job(clone,workbench.id,0).ok and clone.wood==before+4,"cancelamento devolve só ingredientes de unidades não concluídas")
	clone.construction.advance(clone,1000)
	verify(clone.construction.amount(clone,"plank")==planks+2,"fila cancelada não entrega produto novamente")
	build.queues[workbench.id][0].remaining=1
	verify(saved.construction.queues[workbench.id][0].remaining==5,"snapshot não compartilha estado mutável com a produção")
	var isolated:=supplied();var workshop:String=isolated.construction.place(isolated,"workbench",Vector2i(100,110)).id
	var forge:String=isolated.construction.place(isolated,"forge",Vector2i(103,110)).id
	var stock_before:=isolated.construction.amount(isolated,"plank")
	isolated.construction.enqueue(isolated,workshop,"plank");isolated.construction.enqueue(isolated,forge,"iron_ingot")
	isolated.construction.advance(isolated,6.5,{workshop:true})
	verify(isolated.construction.amount(isolated,"plank")==stock_before+2 and isolated.construction.queues[forge][0].remaining==13.5,"trabalhador acelera sua estação; filas de outras bancadas correm em paralelo")
	isolated.construction.damage(isolated,forge,220);var remaining:float=isolated.construction.queues[forge][0].remaining
	isolated.construction.advance(isolated,60)
	verify(isolated.construction.queues[forge][0].remaining==remaining,"estação com até 25% de vida pausa a fila")
	verify(not isolated.construction.enqueue(isolated,forge,"copper_ingot").ok,"estação danificada não aceita novos pedidos")
	isolated.construction.repair(isolated,forge);isolated.construction.advance(isolated,remaining)
	verify(isolated.construction.amount(isolated,"iron_ingot")==1 and not isolated.construction.queues.has(forge),"reparar libera a fundição e entrega exatamente um lingote")
	isolated.construction.stock.iron_ingot=10
	verify(isolated.construction.enqueue(isolated,forge,"iron_pickaxe").ok and not isolated.construction.enqueue(isolated,forge,"iron_pickaxe").ok,"mesma ferramenta não cobra duas encomendas simultâneas")
	isolated.construction.advance(isolated,45)
	verify(isolated.tools.has("pickaxe") and isolated.resources.tier("pickaxe",isolated.tools)==3,"forja fabrica ferramentas de ferro utilizáveis na coleta")
	isolated.construction.enqueue(isolated,workshop,"plank",3);before=isolated.wood
	verify(isolated.construction.damage(isolated,workshop,1000).destroyed and isolated.wood==before+6 and not isolated.construction.queues.has(workshop),"destruir estação libera a fila e devolve ingredientes não processados")
	before=isolated.wood
	verify(not isolated.construction.remove(isolated,workshop).ok and isolated.wood==before,"estrutura já removida não duplica reembolso")
	var broken:=ConstructionState.new()
	broken.restore({"pieces":{"piece_1":{"kind":"wood_wall","x":NAN,"y":100,"hp":120},"piece_2":{"kind":"nope","x":100,"y":100,"hp":2},"piece_3":{"kind":"workbench","x":110,"y":100,"turn":0,"hp":999,"worker":"missing"}},"queues":{"piece_3":[{"recipe":"iron_ingot","count":1,"remaining":3},{"recipe":"plank","count":1,"remaining":INF}]},"stock":{"plank":-5,"gold":1000},"player_bed":"piece_3"})
	verify(broken.pieces.size()==1 and broken.pieces.piece_3.hp==140 and broken.pieces.piece_3.worker.is_empty(),"save inválido filtra peças, números não finitos, vida e designações")
	verify(broken.queues.is_empty() and broken.stock.plank==0 and not broken.stock.has("gold") and broken.player_bed.is_empty(),"save inválido não injeta filas, moedas ou cama em estação")
	var legacy:=RPGState.new();legacy.restore({"gold":45,"tools":["hammer"],"houses":{"home_player":{"owner":"player","x":7000,"y":6000,"stage":3}}})
	verify(legacy.houses.home_player.stage==3 and legacy.tools.has("hammer") and legacy.construction.pieces.is_empty(),"saves anteriores preservam casa pronta e equipamento")
	legacy.wood=50;legacy.stone=20;legacy.damage_house("home_player",80)
	verify(legacy.houses.home_player.hp==320 and legacy.repair_house("home_player").ok and legacy.houses.home_player.hp==400 and legacy.wood==45 and legacy.stone==18,"casas antigas recebem vida e reparo com custos proporcionais")
	await integration()
	print("CONSTRUCTION: %d verificações; %d falhas."%[checks,failures]);quit(1 if failures else 0)

func integration()->void:
	var doc:=MapDocument.blank();doc.id="construction_fixture";doc.spawn=[8000,6400]
	doc.objects=[{"id":"obj_worker","kind":"npc","x":7808,"y":6656,"name":"Bento","appearance":"bento","realm":"aurelia","home_x":7744,"home_y":6656,"work_x":7744,"work_y":6528,"social_x":7808,"social_y":6720},{"id":"obj_lia","kind":"npc","x":7872,"y":6656,"name":"Lia","appearance":"lia"},{"id":"obj_tree","kind":"tree","x":7808,"y":6400},{"id":"obj_boar","kind":"boar","x":8256,"y":6656}]
	doc.terrain["130,103"]="water";doc.terrain["129,103"]="dirt"
	MapDocument.activate(MapDocument.validate(doc).document)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.start_journey();game.world.set_population_active(false);game.economy.set_process(false);game.player.set_physics_process(false)
	game.rpg.tools.hammer=true;game.rpg.wood=500;game.rpg.stone=500;game.rpg.copper=20;game.rpg.iron=30;game.rpg.construction.stock.plank=40
	for npc in game.world.npcs.values():npc.set_physics_process(false)
	await frames(3)
	verify(not game.construction.can_place("workbench",Vector2(7808,6400)).ok,"prévia rejeita recursos vivos")
	verify(not game.construction.can_place("wood_floor",Vector2(8320,6592)).ok and not game.construction.can_place("wood_floor",Vector2(8256,6592)).ok,"prévia rejeita rio e ruas pintadas")
	verify(not game.construction.can_place("wood_wall",game.player.position).ok and not game.construction.can_place("bed",Vector2(9000,6400)).ok,"prévia rejeita ator no local e construção à distância")
	await key(KEY_B)
	verify(game.hud.modal_kind=="construction" and not game.world.clock.active,"B abre catálogo e pausa o tempo do mundo")
	await button("category_stations");await capture("catalogo")
	await button("piece_workbench")
	verify(game.building_preview and game.construction.selected=="workbench" and game.mode=="playing","escolher uma peça abre o modo de posicionamento")
	var point:=Vector2(8128,6400)
	if graphics:
		game.hybrid.snap_camera()
		var screen:=game.hybrid.camera.unproject_position(game.hybrid._point(point));Input.warp_mouse(screen);await frames(4)
		verify(game.hybrid.piece_ghost.visible and game.hybrid.build_grid.visible and game.hybrid.piece_ghost.visual_mesh.material_override.albedo_color.g>0.8,"fantasma válido e grade são desenhados em verde")
		await capture("previa-verde");await click(screen)
	else:game.construction.place(point)
	var bench_id:=""
	for id in game.rpg.construction.pieces:
		if game.rpg.construction.pieces[id].kind=="workbench":bench_id=id
	verify(not bench_id.is_empty() and game.rpg.wood==490,"clique de colocação cria bancada pagando custo exato")
	if bench_id.is_empty():return
	if graphics:
		verify(game.hybrid.piece_ghost.visual_mesh.material_override.albedo_color.r>0.9,"célula ocupada muda fantasma para vermelho")
		await capture("previa-vermelha")
	var count:=game.rpg.construction.pieces.size();game.construction.place(point)
	verify(game.rpg.construction.pieces.size()==count and game.rpg.wood==490,"duplo clique em célula ocupada não cobra de novo")
	await key(KEY_B);await button("category_furniture");await button("piece_bed");await key(KEY_T)
	verify(game.construction.turn==1,"T gira a peça sem alterar a rotação da câmera")
	game.cancel_building();game.construction.selected="bed"
	var bed:=game.construction.place(Vector2(7936,6528))
	verify(bed.ok,"móvel de duas células é construído no mundo")
	game.cancel_building()
	game.rpg.construction.place(game.rpg,"wood_floor",Vector2i(127,100))
	verify(is_equal_approx(game.world.floor_height(Vector2(8128,6400)),0.07),"piso registra sua altura para apoiar personagens e sombras")
	if graphics:
		game.rpg.construction.place(game.rpg,"wood_floor",Vector2i(125,100));game.player.position=Vector2(8000,6400)
		game.hybrid.set_light_graphics(false);await frames(3)
		var shadow:Sprite3D
		for actor in game.hybrid.actors:
			if actor.body==game.player and actor.has("shadow"):shadow=actor.shadow
		verify(shadow!=null and shadow.visible and shadow.position.y>0.07 and game.hybrid._body_height(game.player)>=0.07,"modo HD-2D mantém personagem e sombra acima do piso construído")
		game.hybrid.set_light_graphics(true)
	game.rpg.construction.place(game.rpg,"wood_wall",Vector2i(124,98))
	var door:=game.rpg.construction.place(game.rpg,"door",Vector2i(126,98))
	await frames(3)
	var closed_point:=Vector2(126,98)*64
	verify(not WorldData.can_stand(closed_point,game.world.data,10) and game.world.navigator.is_point_solid(Vector2i(126,98)),"parede da porta atualiza colisão e navegação")
	game.player.position=closed_point+Vector2(0,64)
	var transform:=game.player.transform
	verify(game.player.test_move(transform,Vector2(0,-128)),"corpo físico do jogador encontra a porta fechada")
	game.construction.toggle_door(door.id);game.close_dialog();await frames(3)
	verify(WorldData.can_stand(closed_point,game.world.data,10) and not game.world.navigator.is_point_solid(Vector2i(126,98)) and not game.player.test_move(transform,Vector2(0,-128)),"abrir porta libera física, terreno e rota")
	game.player.position=closed_point;game.construction.toggle_door(door.id)
	verify(game.rpg.construction.pieces[door.id].open,"porta não fecha prendendo o jogador")
	game.player.position=point+Vector2(0,64);await frames(3)
	verify(game.current_interaction().get("id","")==bench_id,"bancada tem prioridade de interação sobre pisos próximos")
	game.interact();await button("station_recipes");await button("recipe_plank");await button("craft_five")
	verify(game.hud.modal_kind=="craft_queue" and game.rpg.construction.queues[bench_id][0].count==5,"receita clicada cria lote na fila de produção")
	var paused_remaining:float=game.rpg.construction.queues[bench_id][0].remaining
	await frames(6)
	verify(game.rpg.construction.queues[bench_id][0].remaining==paused_remaining,"menu de produção pausa o relógio e a fila")
	await capture("fila");game.close_dialog();game.world.set_population_active(false)
	game.world.clock.advance(3);var pending:float=game.rpg.construction.queues[bench_id][0].remaining
	verify(is_equal_approx(pending,5),"fila acompanha avanço do relógio do mundo")
	var snapshot:=game.journey_data();game.rpg.construction.stock.plank=0;game.rpg.construction.pieces.clear()
	verify(game.apply_journey(snapshot) and is_equal_approx(game.rpg.construction.queues[bench_id][0].remaining,pending) and game.rpg.construction.pieces[door.id].open,"carregar partida restaura porta aberta e fila sem adiantar produção")
	game.world.set_population_active(false);game.player.set_physics_process(false)
	for npc in game.world.npcs.values():npc.set_physics_process(false)
	var npc:ForestNPC=game.world.npcs.obj_worker
	game.rpg.construction.assign(game.rpg,bed.id,npc.definition.id,"resident");game.rpg.construction.assign(game.rpg,bench_id,npc.definition.id,"worker")
	game.world.clock.set_time(10);npc.active=true;npc.hunger=0.1
	verify(npc.home_override.is_finite() and npc.work_override.is_finite() and game.construction.advance_worker(npc),"designações atualizam casa, trabalho e objetivo econômico do NPC")
	for i in 120:npc.advance_offscreen(0.2)
	verify(npc.position.distance_to(npc.work_override)<11 and npc.state=="work","NPC percorre a rota e trabalha na bancada designada")
	game.world.clock.set_time(23);npc.active=true
	for i in 180:npc.advance_offscreen(0.2)
	verify(npc.sleeping and npc.position.distance_to(npc.home_override)<11,"NPC volta à cama do jogador e dorme no seu horário")
	game.world.clock.set_time(12.5);npc.active=true
	verify(not npc.wants_rest and not npc.current_schedule.get("work",false) and game.construction.advance_worker(npc) and not npc.economic_target.is_finite() and npc._target()!=npc.work_override,"designação libera o objetivo de trabalho durante pausas e passeio da rotina")
	npc.hunger=0.9;npc.position=npc.home_override;var account:=game.rpg.npc_account(npc.definition.id);var coins:int=account.gold
	verify(game.construction.advance_worker(npc) and npc.hunger<0.2 and account.gold==coins-5,"trabalhador se alimenta na pausa com suas próprias moedas")
	game.player.position=ConstructionCatalog.approach(game.rpg.construction.pieces[bed.id]);game.rpg.construction.assign(game.rpg,bed.id,"","resident")
	game.rpg.health=40;game.construction.rest_bed(bed.id)
	verify(game.rpg.construction.player_bed==bed.id and game.rpg.health==100 and game.world.clock.minute==420,"cama livre salva ponto de retorno e recupera vida até a manhã")
	game.world.set_population_active(false);game.player.position=Vector2(8000,6400);game.take_damage(200)
	verify(game.player.position.distance_to(game.construction.respawn())<1 and game.rpg.health==60,"socorro retorna ao acesso livre da cama escolhida")
	game.player.position=point+Vector2(0,64);game.rpg.construction.damage(game.rpg,bench_id,40);game.construction.show_piece(bench_id)
	await button("repair_piece")
	verify(game.rpg.construction.pieces[bench_id].hp==140,"botão de reparo restaura vida da estação")
	game.close_dialog();game.world.set_population_active(false)
	game.rpg.construction.enqueue(game.rpg,bench_id,"plank",2);game.world.clock.advance(2)
	var path:="user://construction-test-"+str(Time.get_ticks_usec())+".json"
	game.save_path=path;game.persistence=true;game.save_journey();game.persistence=false
	var disk:Variant=JSON.parse_string(FileAccess.get_file_as_string(path));var stock_saved:=game.rpg.construction.stock.duplicate()
	var disk_state:=RPGState.new();disk_state.restore(disk.rpg)
	verify(disk is Dictionary and disk.rpg.construction.pieces.size()==game.rpg.construction.pieces.size() and disk_state.construction.queues[bench_id][0].recipe==game.rpg.construction.queues[bench_id][0].recipe and is_equal_approx(disk_state.construction.queues[bench_id][0].remaining,game.rpg.construction.queues[bench_id][0].remaining),"save real no disco inclui peças e progresso parcial da fila")
	game.rpg.construction.stock.clear();game.apply_journey(disk)
	verify(game.rpg.construction.stock==stock_saved and game.world.pieces.size()==game.rpg.construction.pieces.size(),"carregar disco reconstrói estado e colisores das estruturas")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	game.world.set_population_active(false);game.economy.set_process(false);game.player.set_physics_process(false)
	game.close_dialog();game.world.set_population_active(false)
	var defense:=game.rpg.construction.place(game.rpg,"wood_wall",Vector2i(128,102))
	game.player.position=Vector2(8192,6464)
	var boar:WorldAnimal=game.world.animals.obj_boar;boar.position=Vector2(8192,6568);boar.active=true;boar.attack_delay=0;boar.set_physics_process(false);boar._physics_process(0.1);boar.active=false
	await frames(2)
	verify(game.rpg.construction.pieces[defense.id].hp==108,"javali danifica a parede que bloqueia sua perseguição")
	if graphics:
		verify(game.hybrid.landscape.piece_models.size()==game.rpg.construction.pieces.size(),"cada peça próxima tem modelo 3D com a mesma área física")
		var model:ConstructionVisual=game.hybrid.landscape.piece_models[bench_id]
		verify(model.visual_mesh.mesh.get_surface_count()==1 and model.visual_mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_ON,"peça usa uma malha e projeta sombra no cenário 3D")
		game.hybrid.snap_camera();await capture("assentamento")
		var coord:=Vector2i((point/WorldData.CHUNK).floor());game.player.position=Vector2(10000,9000);game.world.ensure_region(game.player.position,true);await frames(2)
		verify(not game.hybrid.landscape.piece_models.has(bench_id) and game.rpg.construction.pieces.has(bench_id),"região distante libera modelo sem apagar a construção")
		game.player.position=point+Vector2(0,64);game.world.ensure_region(game.player.position,true);game.hybrid.snap_camera();await frames(3)
		verify(game.hybrid.landscape.piece_models.has(bench_id),"retorno à região recria modelo salvo")
	var first_map:=MapDocument.current.duplicate(true);var construction_saved:=game.rpg.construction.save_data()
	game.apply_map(MapDocument.blank())
	verify(game.rpg.construction.pieces.is_empty(),"mapas diferentes têm construções e filas separadas")
	game.apply_map(first_map)
	verify(game.rpg.construction.save_data()==construction_saved,"retornar ao mapa recupera assentamento, moradores e produção")
