extends SceneTree

var checks:=0
var failures:=0
var game:ForestGame

func _initialize()->void:call_deferred("run")
func verify(ok:bool,label:String)->void:
	checks+=1
	if ok:print("PASS: "+label)
	else:failures+=1;push_error("FAIL: "+label)
func frames(count:int=3)->void:
	for i in count:await physics_frame;await process_frame
func capture(name:String)->void:
	if game.hybrid==null:return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/entre-reinos-casas-"+name+".png")
func clockwise(mesh:Mesh)->bool:
	var arrays:=mesh.surface_get_arrays(0)
	var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	for i in range(0,indices.size(),3):
		var a:=indices[i];var b:=indices[i+1];var c:=indices[i+2]
		if (vertices[b]-vertices[a]).cross(vertices[c]-vertices[a]).dot(normals[a])>=0:return false
	return not indices.is_empty()
func run()->void:
	var silhouettes:Dictionary={};var sizes:Dictionary={}
	for id in HouseKit.IDS:
		var kit:=HouseKit.definition(id)
		verify(kit is HouseData and kit.id==id,"HouseData carregado: "+id)
		verify(ResourceLoader.exists("res://game/data/houses/"+id+".tres"),"Resource independente para "+id)
		for turn in 4:
			var size:=HouseKit.size_for(id,42,turn)
			var data:={"id":"test_"+id,"name":id,"kind":"timber","realm":"aurelia","tile":Vector2(10,10),"size":size,"house_style":id,"house_seed":42,"house_turn":turn}
			var plan:=HouseKit.generate(data)
			verify(is_equal_approx(size.x/64,roundf(size.x/64)) and is_equal_approx(size.y/64,roundf(size.y/64)),id+" dimensões inteiras no giro "+str(turn))
			var doors:=0;var kinds:Dictionary={}
			for piece in plan.pieces:
				kinds[piece.kind]=true
				if piece.kind=="door":doors+=1
			verify(doors==1 and kinds.has_all(["foundation","wall","window","door","roof","chimney","steps"]),id+" kit completo com uma porta no giro "+str(turn))
			if kit.porch:verify(kinds.has("porch"),id+" varanda compõe o kit")
			verify(JSON.stringify(plan.pieces)==JSON.stringify(HouseKit.generate(data).pieces),id+" geração reproduzível sem sortear ao recarregar")
			verify(not plan.footprint.has_point(HouseKit.approach(data)),id+" ponto de entrada fora da colisão no giro "+str(turn))
			var model:=BuildingVisual.new();model.setup(data)
			verify(model.get_child_count()==1 and model.visual_mesh.mesh.get_surface_count()==1,id+" módulos unidos em uma superfície")
			verify(clockwise(model.visual_mesh.mesh),id+" faces externas têm winding correto no giro "+str(turn))
			verify(model.position.is_equal_approx(WorldGrid.point3(plan.footprint.position)) and model.visual_mesh.position==Vector3.ZERO,id+" pivô no canto permanece estável ao girar")
			verify(model.get_meta("house_style")==id and model.get_meta("height")>kit.wall_height,id+" estilo e volume presentes na malha")
			silhouettes[id]=str(model.visual_mesh.get_aabb().size)+str(model.visual_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size())
			model.free()
		for seed_value in 12:sizes[str(HouseKit.size_for(id,seed_value))]=true
	var unique_silhouettes:Dictionary={}
	for silhouette in silhouettes.values():unique_silhouettes[silhouette]=true
	verify(unique_silhouettes.size()==5 and sizes.size()>8,"cinco silhuetas e variações reais de tamanho")
	seed(123);var expected:=randf();seed(123);HouseKit.generate({"kind":"timber","size":Vector2(192,128),"tile":Vector2.ZERO});verify(is_equal_approx(expected,randf()),"geração de casas não altera o RNG de animais e NPCs")
	for data in KingdomData.buildings():
		if not data.kind in HouseKit.KINDS:continue
		var plan:=HouseKit.generate(data)
		verify(plan.footprint==KingdomData.building_rect(data),"terreno preservado: "+data.id)
	var saved_map:=MapDocument.current.duplicate(true);MapDocument.activate(MapDocument.blank())
	var rpg:=RPGState.new();var options:={"house_style":"rich","house_seed":123,"house_turn":1}
	verify(rpg.claim(Vector2(6000,6000),"player",options).ok,"terreno aceita kit persistente")
	var rect:=rpg.home_rect(rpg.houses.home_player)
	var saved:Dictionary=JSON.parse_string(JSON.stringify(rpg.save_data()));var restored:=RPGState.new();restored.restore(saved)
	verify(restored.home_rect(restored.houses.home_player)==rect and restored.houses.home_player.house_turn==1,"save conserva estilo, semente, tamanho e giro")
	verify(not HouseKit.clean_options({"house_style":"rich","house_seed":"script"}).has("house_style"),"opções inválidas rejeitadas")
	MapDocument.activate(saved_map)
	var obj:=MapDocument.clean_object({"id":"obj_test_house","kind":"timber","x":8000,"y":6500,"house_style":"rich","house_seed":42,"house_turn":3})
	var document:=MapDocument.blank();document.objects=[obj]
	var checked:=MapDocument.validate(JSON.parse_string(JSON.stringify(document)))
	verify(checked.ok and checked.document.objects[0].house_turn==3,"mapa exporta e importa os kits e a orientação")
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames(5);game.start_journey();await frames()
	verify(game.housing!=null and game.housing.portal_root.get_child_count()>100,"cidades ganham portas funcionais")
	var home_data:Dictionary={}
	for data in KingdomData.buildings():
		if data.kind=="timber":home_data=data;break
	var approach:=HouseKit.approach(home_data)
	game.player.position=game.world.safe_position(approach);game.player.restore_surface()
	if game.hybrid!=null:game.hybrid.snap_camera()
	await frames()
	verify(game.current_interaction().get("kind")=="house_door","E detecta a porta da fachada")
	var outside:=game.player.position;var coins:=game.rpg.gold;var population:=game.world.population_data()
	verify(game.housing.enter(home_data.id),"porta transfere o jogador para interior mobiliado")
	await frames()
	verify(game.player.indoors and game.housing.room.furniture.size()>=4,"interior tem móveis e piso caminhável")
	verify(game.hud.location.text.contains("Interior"),"HUD mostra o interior e mantém o marcador no continente")
	if game.hybrid!=null:
		var fog:=game.housing.room.environment.fog_density
		game.world.clock.advance(5)
		verify(is_equal_approx(game.housing.room.environment.fog_density,fog) and not game.housing.room.environment.fog_enabled,"relógio não injeta neblina exterior no cômodo")
	verify(game.player.get_parent()==game.housing.room and game.world.process_mode==Node.PROCESS_MODE_DISABLED,"interior isola física e navegação do continente")
	verify(not game.player.swimming and game.player.collision_mask==WorldData.SOLID_LAYER,"água exterior não afeta o interior")
	var start:=game.player.position
	Input.action_press("move_left");await frames(8);Input.action_release("move_left")
	verify(game.player.position.x<start.x-5,"movimento real funciona dentro de casa")
	game.player.position=Vector2(45,game.housing.room.dimensions.y/2)
	var collision:=game.player.move_and_collide(Vector2(-100,0))
	verify(collision!=null and game.player.position.x>8,"paredes internas bloqueiam o personagem")
	for id in population:
		verify(game.world.npcs[id].position.distance_to(Vector2(population[id].x,population[id].y))<1,"NPC exterior não anda dentro do interior: "+id)
	game.player.position=game.housing.room.spawn_point
	var journey:=game.journey_data()
	verify(Vector2(journey.x,journey.y).distance_to(outside)<1 and journey.interior.house==home_data.id,"save guarda retorno exterior e sala atual separadamente")
	verify(game.rpg.gold==coins,"transição mantém a mesma carteira")
	if game.hybrid!=null:
		verify(game.hybrid.camera==game.housing.room.camera and game.hybrid.camera.current,"câmera HD-2D muda para o interior")
		verify(game.housing.room.actor!=null and game.housing.room.actor.texture!=null,"sprite original do jogador continua animado no 3D")
		await frames(20);await capture("interior")
	verify(game.housing.interaction().kind=="house_exit","porta de saída é alcançável")
	game.interact();await frames()
	verify(not game.housing.inside() and not game.player.indoors and game.player.position.distance_to(outside)<1,"E sai e restaura posição e física exteriores")
	verify(game.world.population_active and game.player.get_parent()==game.world.entities,"rotinas exteriores retomam depois da transição")
	verify(game.apply_journey(journey),"jornada salva dentro de casa carrega")
	game.housing.resume();await frames()
	verify(game.housing.inside() and game.housing.active_id==home_data.id,"carregamento retoma a mesma casa")
	game.housing.leave(false)
	game.housing.restore_location({"house":"missing_house","x":0,"y":0});game.housing.resume()
	verify(not game.housing.inside() and game.player.position.distance_to(outside)<1,"casa ausente no mapa preserva retorno seguro")
	game.player.position=KingdomData.point("aurelia_shop")+Vector2(0,32);game.player.restore_surface();await frames()
	game.open_shop("aurelia")
	var shop_id:=game.housing.service_building("aurelia","shop")
	verify(not shop_id.is_empty() and game.hud.modal_kind=="shop","loja mantém comércio na porta e oferece interior")
	verify(game.housing.enter(shop_id),"loja tem transição funcional")
	await frames()
	var counter:Dictionary={}
	for entry in game.housing.room.interactions:
		if entry.kind=="house_counter":counter=entry
	game.player.position=counter.at;game.interact();await frames()
	verify(game.hud.modal_kind=="shop","balcão interno abre comércio real")
	game.buy_item("aurelia","axe")
	verify(game.rpg.tools.has("axe") and game.rpg.gold<coins,"comprar no interior usa inventário persistente")
	game.close_dialog();game.housing.leave(false)
	game.housing.show_catalog();await frames()
	verify(game.hud.modal_kind=="house_kits","B oferece escolha dos cinco kits completos")
	game.housing.select_style("rich");await frames()
	verify(game.building_preview and game.housing.plan_enabled and game.housing.chosen_style=="rich","escolher kit abre a prévia antes de gastar")
	var event:=InputEventKey.new();event.physical_keycode=KEY_T;event.pressed=true;game._input(event)
	verify(game.housing.chosen_turn==1,"T gira a casa em quartos de volta")
	var previous_seed:=game.housing.chosen_seed;event.physical_keycode=KEY_V;game._input(event)
	verify(game.housing.chosen_seed==previous_seed+1,"V escolhe uma variação persistente")
	if game.hybrid!=null:verify(game.hybrid.house_ghost!=null and game.hybrid.house_ghost.visible,"prévia desenha o kit completo")
	game.cancel_building();game.housing.plan_enabled=false
	game.show_map_editor();await frames()
	var editor:=game.map_editor;editor.draft=MapDocument.blank();editor.tool="timber";editor.house_seed=123;editor.house_turn=1
	editor.begin_stroke();verify(editor.paint_at(Vector2(8000,6400)),"ateliê coloca uma casa do kit com tamanho próprio");editor.end_stroke()
	var placed:Dictionary=editor.draft.objects[0]
	var placed_rect:=KingdomData.building_rect(MapDocument.object_building(placed))
	verify(placed.house_style=="common" and placed.house_turn==1 and placed_rect.position.snapped(Vector2.ONE*64)==placed_rect.position,"casa do ateliê guarda semente e pivô no grid")
	editor.undo();verify(editor.draft.objects.is_empty(),"desfazer remove a casa inteira")
	editor.redo();verify(editor.draft.objects[0].house_seed==123,"refazer restaura a variação original")
	editor.selection=placed.id;editor.change_house_option("house_turn",2)
	verify(editor.draft.objects[0].house_turn==2 and MapDocument.validate(editor.draft).ok,"girar pelo inspetor preserva um mapa válido")
	editor.close()
	if game.hybrid!=null:
		verify(game.hybrid.house_smoke.multimesh.instance_count==HouseSmoke.MAX_CHIMNEYS*HouseSmoke.PUFFS,"fumaça tem orçamento fixo de partículas")
		await showcase()
	game.free();await frames()
	print("CASAS: %d verificações; %d falhas."%[checks,failures]);quit(1 if failures else 0)

func showcase()->void:
	game.world.set_population_active(false);game.player.active=false;game.hybrid.hide();game.hybrid.set_process(false);game.hybrid.process_mode=Node.PROCESS_MODE_DISABLED;game.hybrid.grade.hide();game.hud.root.hide()
	var gallery:=Node3D.new();root.add_child(gallery)
	var environment:=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color("172329");environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color("f2e3c9");environment.ambient_light_energy=0.8
	game.hybrid.atmosphere.environment=environment
	var stage_camera:=Camera3D.new();stage_camera.projection=Camera3D.PROJECTION_ORTHOGONAL;stage_camera.size=23;gallery.add_child(stage_camera);stage_camera.position=Vector3(20,17,25);stage_camera.look_at(Vector3(16,1,2));stage_camera.make_current()
	var ground:=MeshInstance3D.new();var plane:=BoxMesh.new();plane.size=Vector3(45,0.1,14);ground.mesh=plane;ground.position=Vector3(17,-0.1,2);var mat:=StandardMaterial3D.new();mat.albedo_color=Color("566f48");ground.material_override=mat;gallery.add_child(ground)
	var x:=0.0
	for id in HouseKit.IDS:
		var size:=HouseKit.size_for(id,42)
		var data:={"id":"gallery_"+id,"name":id,"kind":"timber","realm":"aurelia","tile":Vector2((x+size.x/128)*64,5*64)/64,"size":size,"house_style":id,"house_seed":42,"house_turn":0}
		var model:=BuildingVisual.new();model.setup(data);gallery.add_child(model)
		var label:=Label3D.new();label.text=HouseKit.definition(id).title;label.position=Vector3(x+size.x/128,0.05,6);label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.pixel_size=0.012;label.font_size=22;gallery.add_child(label)
		x+=size.x/64+1.3
	game.hybrid._architecture_parameter("day_color",Vector3.ONE);game.hybrid._architecture_parameter("night",0.0)
	await frames(12);await capture("cinco-kits")
	game.hybrid._architecture_parameter("night",1.0);game.hybrid._architecture_parameter("day_color",Vector3(0.32,0.40,0.58))
	await frames(4);await capture("janelas-noite")
	verify(is_equal_approx(BuildingVisual.shared_material.get_shader_parameter("night"),1.0),"janelas recebem iluminação noturna")
	gallery.free()
