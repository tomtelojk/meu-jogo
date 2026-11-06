extends SceneTree

var checks:=0
var failures:=0
var game:ForestGame
var editor:WorldEditor
var graphics:=false

func _initialize()->void:
	root.size=Vector2i(1280,800)
	graphics="--hybrid" in OS.get_cmdline_user_args()
	var watchdog:=Timer.new();watchdog.wait_time=120;watchdog.one_shot=true;watchdog.autostart=true;root.add_child(watchdog)
	watchdog.timeout.connect(func():push_error("Editor test timeout");quit(1))
	call_deferred("run")

func verify(ok:bool,label:String)->void:
	checks+=1
	if ok:print("PASS: "+label)
	else:failures+=1;push_error("FAIL: "+label)

func frames(count:int=3)->void:
	for i in count:await physics_frame;await process_frame

func key(code:Key,control:bool=false)->void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.ctrl_pressed=control;event.pressed=true;Input.parse_input_event(event)
	await frames(1)
	event=event.duplicate();event.pressed=false;Input.parse_input_event(event)
	await frames(2)

func click_world(point:Vector2)->void:
	if not graphics:
		editor.begin_stroke();editor.paint_at(point);editor.end_stroke();await frames();return
	var screen:=editor.canvas.global_position+editor.canvas.to_screen(point)
	Input.warp_mouse(screen)
	var motion:=InputEventMouseMotion.new();motion.position=screen;motion.global_position=screen;Input.parse_input_event(motion)
	var event:=InputEventMouseButton.new();event.position=screen;event.global_position=screen;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;Input.parse_input_event(event)
	await frames(1)
	event=event.duplicate();event.pressed=false;Input.parse_input_event(event)
	await frames(2)

func capture(name:String)->void:
	if not graphics:return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/ateliê-"+name+".png")

func run()->void:
	MapDocument.activate(MapDocument.original())
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.start_journey();game.rpg.gold=137
	await frames()
	await capture("aurelia")
	await key(KEY_F2)
	editor=game.map_editor
	verify(editor!=null and editor.visible and game.mode=="editor","F2 abre o ateliê dentro do jogo")
	if editor==null:quit(1);return
	verify(not game.player.active and not game.world.population_active,"editor pausa movimento, relógio e moradores")
	if graphics:verify(editor.canvas.size.x>500 and editor.canvas.size.y>500,"área de edição fica acessível na janela de PC")
	await capture("reinos")
	editor.replace_document(MapDocument.blank())
	editor.draft.name="Vila de São Bento"
	editor.title.text=editor.draft.name
	editor.canvas.center=Vector2(8000,6400);editor.canvas.zoom=0.30
	editor.select_tool("water");editor.brush_size=3
	await click_world(Vector2(8192+32,6400+32))
	verify(editor.draft.terrain.size()==9,"clique na tela pinta um lago de nove células")
	await key(KEY_Z,true)
	verify(editor.draft.terrain.is_empty(),"Ctrl+Z desfaz uma pincelada inteira")
	await key(KEY_Y,true)
	verify(editor.draft.terrain.size()==9,"Ctrl+Y refaz a pincelada")
	editor.brush_size=1
	editor.select_tool("dirt")
	await click_world(Vector2(7872,6400))
	verify(editor.draft.terrain.values().has("dirt"),"estradas usam o mesmo pincel de terreno")
	for item in [{"kind":"cottage","at":Vector2(7872,6144),"style":0},{"kind":"forge","at":Vector2(7520,6208),"style":2},{"kind":"tower","at":Vector2(8320,6112),"style":4},{"kind":"tavern","at":Vector2(8640,6208),"style":1},{"kind":"tree","at":Vector2(7744,6720),"style":0},{"kind":"cow","at":Vector2(8448,6720),"style":0}]:
		editor.select_tool(item.kind);editor.chosen_style=item.style
		await click_world(item.at)
	verify(editor.draft.objects.size()==6,"paleta coloca casas, comércio, torre, árvore e animal")
	editor.select_tool("npc");editor.appearance="iris"
	await click_world(Vector2(7712,6464))
	var herbalist_id:=editor.selection
	var npc:=editor.selected_object()
	verify(npc.get("appearance")=="iris","novo NPC recebe o sprite escolhido")
	editor.select_tool("anchor_home");await click_world(Vector2(7712,6592))
	editor.select_tool("anchor_work");await click_world(Vector2(7808,6464))
	editor.select_tool("anchor_social");await click_world(Vector2(8000,6656))
	verify(editor.selected_object().work_x==7808 and editor.selected_object().home_y==6592,"usuário marca casa, trabalho e passeio do NPC")
	editor.select_tool("npc");editor.appearance="tomas"
	await click_world(Vector2(8480,6464))
	var guard_id:=editor.selection
	editor.select_tool("select")
	await click_world(Vector2(8576,6592))
	verify(editor.selected_object().x==8576 and editor.selected_object().y==6592,"seleção move o NPC e preserva suas âncoras relativas")
	editor.begin_stroke();editor.delete_selected();editor.end_stroke()
	verify(editor.draft.objects.size()==7,"apagar remove o objeto selecionado")
	editor.undo()
	verify(editor.draft.objects.size()==8,"desfazer recupera o objeto apagado")
	editor.select_tool("bridge")
	await click_world(Vector2(8224,6432))
	verify(editor.draft.objects.size()==9,"ponte pode ser colocada sobre a água desenhada")
	var doc:=editor.draft.duplicate(true)
	verify(MapDocument.validate(doc).ok,"mapa editado passa pela validação do formato")
	var file_path:="/tmp/entre-reinos-editor-roundtrip.json"
	verify(MapDocument.write_file(file_path,doc)==OK,"exportação grava um JSON real no disco")
	var imported:=MapDocument.read_file(file_path)
	verify(imported.ok and imported.document.name==doc.name and imported.document.objects.size()==9,"importação preserva nome acentuado, objetos, terreno e rotinas")
	var invalid:=doc.duplicate(true);invalid.id="../../journey"
	verify(not MapDocument.validate(invalid).ok,"importação rejeita identificador usado como caminho de arquivo")
	invalid=doc.duplicate(true);invalid.terrain["999,0"]="water"
	verify(not MapDocument.validate(invalid).ok,"importação rejeita terreno fora do mundo")
	invalid=doc.duplicate(true);invalid.objects.append(invalid.objects[0].duplicate(true))
	verify(not MapDocument.validate(invalid).ok,"importação rejeita IDs de objetos duplicados")
	invalid=doc.duplicate(true);invalid.objects[0].x=INF
	verify(not MapDocument.validate(invalid).ok,"importação rejeita coordenadas infinitas")
	invalid=doc.duplicate(true);invalid.objects[0].kind="script"
	verify(not MapDocument.validate(invalid).ok,"formato aceita apenas os objetos da paleta")
	await capture("mapa-criado")
	editor.test_map()
	await frames(5)
	verify(game.mode=="playing" and MapDocument.current.id==doc.id,"Testar mapa abre o mesmo documento no RPG")
	verify(game.world.npcs.size()==2 and game.world.animals.size()==1,"mapa vazio contém apenas os moradores e animais colocados")
	verify(KingdomData.buildings().size()==4 and game.world.data.solid_rects.size()==4,"construções manuais criam colisões correspondentes")
	verify(game.world.resources.size()==1,"mapa vazio usa apenas os recursos colocados pelo autor")
	verify(not WorldData.can_stand(Vector2(7872,6096),game.world.data),"parede da casa criada impede passagem")
	verify(WorldData.is_water(Vector2(8224,6496)) and not WorldData.is_water(Vector2(8000,6400)),"lago pintado e terra vizinha têm estados físicos distintos")
	verify(game.world.navigator.is_point_solid(Vector2i(128,99)),"navegação dos NPCs evita o lago pintado")
	verify(not WorldData.is_water(Vector2(8224,6432)) and WorldData.bridge_height(Vector2(8224,6432))==52,"ponte criada tem tabuleiro elevado para atravessar o lago")
	var query:=PhysicsPointQueryParameters2D.new();query.position=Vector2(8224,6432);query.collision_mask=WorldData.WATER_LAYER
	verify(game.world.get_world_2d().direct_space_state.intersect_point(query).is_empty(),"colisão real da água deixa o tabuleiro da ponte livre")
	var pieces:=game.world._subtract_water_rect(Rect2(0,0,1024,1024),Rect2(256,256,512,96))
	var hole_free:=true
	var area:=0.0
	for part in pieces:area+=part.get_area();hole_free=hole_free and not part.has_point(Vector2(512,300))
	verify(hole_free and area==1024*1024-512*96,"ponte inteiramente dentro de um lago não cria colisão invisível no vão")
	verify(MapDocument.water_rects().size()==1,"nove células de água viram uma só região de colisão")
	var worker:ForestNPC=game.world.npcs[herbalist_id]
	verify(KingdomData.point("map_"+herbalist_id+"_work")==Vector2(7808,6464),"rotina procura o ponto de trabalho marcado pelo autor")
	worker.apply_schedule(600,true)
	verify(worker.position.distance_to(Vector2(7808,6464))<65 and not worker.sleeping,"NPC segue sua rotina no mapa criado")
	verify(NPCAppearance.identity(worker.definition)!=NPCAppearance.identity(game.world.npcs[guard_id].definition),"dois NPCs criados usam silhuetas diferentes")
	game.player.position=Vector2(8224,6508);game.player.restore_surface(true)
	await frames()
	verify(game.player.swimming,"jogador pode nadar no lago feito pelo editor")
	if graphics:
		verify(game.hybrid.architecture.get_child_count()==4,"quatro casas e serviços possuem modelos 3D")
		var found_water:=false
		for region in game.hybrid.landscape.regions.values():
			if region.get_node_or_null("PaintedWater")!=null:found_water=true
		verify(found_water,"água do editor recebe superfície e shader no mundo 3D")
		verify(game.hybrid.river_material.shader.resource_path.ends_with("water.gdshader"),"shader de água está ativo")
		game.hybrid.snap_camera()
		await capture("mundo-criado")
	game.player.position=Vector2(7520,6256);game.player.restore_surface()
	await frames(4)
	verify(game.current_interaction().get("kind")=="shop","ferraria colocada pelo usuário tem interação de comércio")
	game.interact()
	verify(game.hud.modal_kind=="shop","E abre a loja da ferraria criada")
	game.close_dialog()
	game.show_pause();game.toggle_shaders()
	verify(not game.shaders_enabled and game.hud.modal_kind=="pause" and game.journey_data().shaders==false,"menu de pausa alterna shaders e registra a preferência no save")
	if graphics:
		verify(not game.hybrid.grade_rect.visible and game.hybrid.river_material.get_shader_parameter("effects")==0.0,"efeitos podem ser desligados para desempenho")
		game.shaders_enabled=true;game.light_graphics=false
		game.hybrid.set_light_graphics(false);game.hybrid.set_shaders(true)
		verify(game.hybrid.grade_rect.visible and is_equal_approx(root.scaling_3d_scale,1.0),"modo nítido inclui correção de cor em resolução integral")
		game.light_graphics=true;game.hybrid.set_light_graphics(true)
		verify(not game.hybrid.grade_rect.visible and is_equal_approx(root.scaling_3d_scale,0.65),"modo leve preserva água e materiais sem o custo da correção em tela cheia")
	game.close_dialog()
	game.shaders_enabled=true
	game.apply_map(MapDocument.original())
	await frames(4)
	verify(game.rpg.gold==137 and game.world.npcs.size()==44,"voltar ao mundo original preserva a aventura anterior")
	if graphics:
		var styles:Dictionary={}
		for model in game.hybrid.architecture.get_children():styles[model.get_meta("style")]=true
		verify(styles.size()==6,"cidades usam seis paletas de arquitetura")
		game.world.set_population_active(false);game.economy.set_process(false)
		game.player.position=Vector2(6600,6400);game.world.ensure_region(game.player.position,true)
		# Clear only the preview strip, using the same resource-removal signal.
		for entry in game.world.resources.values():
			if Rect2(6250,6160,760,500).has_point(entry.resource.position):
				game.rpg.depleted[entry.resource.id]=true;game.world._deplete_resource(entry.resource.id)
		var index:=0
		for id in ["bento","lia","tomas","iris","eron","aurel","caio","mila"]:
			var person:ForestNPC=game.world.npcs[id]
			person.position=Vector2(6320+index*80,6300);person.sleeping=false;person.visible=true;person.face(person.position+Vector2.DOWN)
			index+=1
		game.hybrid.snap_camera();await frames(5)
		await capture("npcs")
	MapDocument.activate(MapDocument.original())
	# Keep the portable example in /tmp for documentation and package review.
	print("EDITOR: %d verificações; %d falhas."%[checks,failures])
	quit(1 if failures else 0)
