extends SceneTree

var checks:=0
var failures:=0
var graphics:=false
var game:ForestGame
func _initialize()->void:
	graphics="--hybrid" in OS.get_cmdline_user_args();root.size=Vector2i(1280,800)
	var timer:=Timer.new();timer.wait_time=180;timer.one_shot=true;timer.autostart=true;root.add_child(timer);timer.timeout.connect(func():push_error("Grid excedeu 180 segundos");quit(1));call_deferred("run")
func verify(ok:bool,label:String)->void:
	checks+=1
	if ok:print("PASS: "+label)
	else:failures+=1;push_error("FAIL: "+label)
func frames(count:int=3)->void:
	for i in count:await physics_frame;await process_frame
func capture(label:String)->void:
	if graphics:await frames();await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/tmp/grid-"+label+".png")
func supplied()->RPGState:
	var state:=RPGState.new();state.wood=2000;state.stone=2000;state.copper=100;state.tools.hammer=true;state.construction.stock.plank=200;return state
func entry(kind:String,x:int,y:int,turn:int=0)->Dictionary:return {"kind":kind,"x":x,"y":y,"turn":turn,"open":false}
func covers(model:ConstructionVisual,point:Vector2)->bool:
	var vertices:=model.visual_mesh.mesh.get_faces();var transform:Transform3D=model.transform*model.visual_mesh.transform
	var origin:=Vector3(point.x,3,point.y)
	for i in range(0,vertices.size(),3):
		if Geometry3D.ray_intersects_triangle(origin,Vector3.DOWN,transform*vertices[i],transform*vertices[i+1],transform*vertices[i+2])!=null:return true
	return false
func run()->void:
	MapDocument.activate(MapDocument.original());ConstructionCatalog.load_data()
	verify(WorldGrid.CELL_SIZE==1 and ConstructionCatalog.GRID==WorldGrid.CELL and HybridWorld.UNIT==WorldGrid.UNITS_PER_METRE,"uma constante de 1 m define o grid e sua conversão 2D/3D")
	verify(WorldGrid.cell_at(Vector2(63.999,63.999))==Vector2i.ZERO and ConstructionCatalog.snap("wood_floor",Vector2(63.999,63.999)).x==1,"tolerância do cursor não amplia a ocupação física das células")
	var report:=ConstructionAudit.assets()
	verify(report.ok and report.modules.size()==12 and report.outside_standard.is_empty(),"auditoria mede os 12 meshes e todos obedecem ao catálogo")
	verify(report.environment_prefabs.filter(func(row:Dictionary):return row.fractional_size).size()==8,"relatório lista os oito prefabs de cenário com dimensões fracionárias")
	for kind in ConstructionCatalog.pieces:
		for turn in 4:
			var data:=entry(kind,100,100,turn);var model:=ConstructionVisual.new();model.setup_piece(data)
			verify(model.position==Vector3(100,0,100) and model.scale==Vector3.ONE and absf(model.rotation.y+turn*PI/2)<0.0001,"pivô e giro padronizados: %s / %d°"%[kind,turn*90])
			if not ConstructionCatalog.is_edge(kind):
				var bounds:AABB=(model.transform*model.visual_mesh.transform)*model.visual_mesh.get_aabb();var rect:=ConstructionCatalog.footprint(data)
				verify(bounds.position.x>=rect.position.x/64-0.001 and bounds.end.x<=rect.end.x/64+0.001 and bounds.position.z>=rect.position.y/64-0.001 and bounds.end.z<=rect.end.y/64+0.001,"mesh permanece dentro da área girada: %s / %d°"%[kind,turn*90])
			model.free()
	for turn in 4:
		var snapped:=ConstructionCatalog.snap("bed",Vector2(8055.9,6471.2),turn);var rect:=ConstructionCatalog.footprint(snapped)
		verify(rect.position==Vector2(8000,6464) and fmod(rect.end.x,64)==0 and fmod(rect.end.y,64)==0,"snap de móvel mantém limites em células inteiras após giro %d"%turn)
	var horizontal:=ConstructionCatalog.snap("wood_wall",Vector2(8055,6407),0);var vertical:=ConstructionCatalog.snap("stone_wall",Vector2(8007,6455),1)
	verify(horizontal.x==125 and horizontal.y==100 and vertical.x==125 and vertical.y==100,"paredes horizontais e verticais compartilham o vértice mais próximo")
	var state:=supplied();var construction:ConstructionState=state.construction
	var first:=construction.place(state,"wood_wall",Vector2i(100,100));var before:=state.stone
	verify(first.ok and not construction.place(state,"stone_wall",Vector2i(101,100),2).ok and state.stone==before,"borda duplicada é recusada mesmo com pivô oposto e giro de 180°")
	verify(construction.place(state,"stone_wall",Vector2i(100,100),1).ok,"paredes perpendiculares compartilham um canto sem ocupar a mesma borda")
	verify(construction.place(state,"wood_floor",Vector2i(100,100)).ok and construction.place(state,"roof",Vector2i(100,100)).ok,"piso e cobertura preenchem a célula até suas paredes")
	for count in [2,3,4]:
		var pieces:Dictionary={"east":entry("wood_wall",10,10),"south":entry("stone_wall",10,10,1)}
		if count>=3:pieces.west=entry("wood_wall",10,10,2)
		if count==4:pieces.north=entry("door",10,10,3)
		var joints:=ConstructionCatalog.network(pieces);var parts:Array[Rect2]=[];var models:Array[ConstructionVisual]=[];var owned:=0
		for data in pieces.values():
			parts.append_array(ConstructionCatalog.collision_parts(data,joints));owned+=ConstructionCatalog.wall_parts(data,joints).posts.size()
			var model:=ConstructionVisual.new();model.setup_piece(data,joints);models.append(model)
		var overlap:=false
		for i in parts.size():
			for j in range(i+1,parts.size()):
				if parts[i].intersection(parts[j]).get_area()>0.001:overlap=true
		verify(owned==1 and not overlap,"junção com %d segmentos tem um único poste e colisores sem sobreposição"%count)
		var watertight:=true
		for x in [-0.10,-0.05,0.025,0.075,0.10]:
			for y in [-0.10,-0.05,0.025,0.075,0.10]:
				var hits:=0
				for model in models:
					if covers(model,Vector2(10+x,10+y)):hits+=1
				if hits!=1:watertight=false
		verify(watertight,"raios nos triângulos reais confirmam canto sem frestas nem faces sobrepostas: %d segmentos"%count)
		for model in models:model.free()
	var raw:={"piece_off":{"kind":"wood_floor","x":10.25,"y":10,"turn":0},"piece_turn":{"kind":"table","x":12,"y":10,"turn":0.5},"piece_bad":{"kind":"unknown","x":10,"y":10},"piece_a":entry("wood_wall",20,20),"piece_b":entry("stone_wall",21,20,2),"piece_nan":{"kind":"bed","x":NAN,"y":10}}
	var audited:=ConstructionAudit.scan(raw);var codes:Array=audited.issues.map(func(row:Dictionary):return row.code)
	verify(not audited.ok and "off_grid" in codes and "rotation" in codes and "unknown_model" in codes and "duplicate_edge" in codes and "invalid_coordinate" in codes,"validador aponta posição, giro, modelo, duplicação e coordenada inválidos")
	var old:={"pieces":{"piece_1":{"kind":"bed","x":103,"y":100,"turn":1,"hp":60,"resident":"bento"},"piece_2":{"kind":"workbench","x":110,"y":100,"turn":0,"hp":120,"worker":"bento"},"piece_3":{"kind":"wood_wall","x":100,"y":100,"turn":2,"hp":90}},"queues":{"piece_2":[{"recipe":"plank","count":2,"remaining":5}]},"stock":{"plank":11},"serial":3,"player_bed":""}
	var restored:=ConstructionState.new();restored.restore(old)
	verify(restored.migrated and restored.pieces.size()==3 and restored.pieces.piece_1.resident=="bento" and restored.pieces.piece_1.hp==60 and ConstructionCatalog.footprint(restored.pieces.piece_1).position==Vector2(103,100)*64,"migração conserva IDs, vida e moradia e converte móvel girado para pivô de canto")
	verify(restored.stock.plank==11 and restored.queues.piece_2[0].remaining==5 and restored.pieces.piece_2.worker=="bento","migração conserva inventário, trabalhadores e produção parcial")
	var saved:=restored.save_data();var again:=ConstructionState.new();again.restore(JSON.parse_string(JSON.stringify(saved)))
	verify(not again.migrated and again.save_data()==saved and ConstructionAudit.scan(again.pieces).ok,"save novo não é migrado duas vezes e permanece alinhado")
	verify(not ConstructionAudit.saved(old).ok and ConstructionAudit.saved(saved).ok,"ferramenta offline distingue save antigo do padrão atual")
	var file:="user://grid-test-report.json";ConstructionAudit.write_report(file,audited)
	verify(JSON.parse_string(FileAccess.get_file_as_string(file)).issues.size()==audited.issues.size(),"relatório JSON preserva todas as peças apontadas")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	await integration()
	print("GRID: %d verificações; %d falhas."%[checks,failures]);quit(0 if failures==0 else 1)

func integration()->void:
	var document:=MapDocument.blank();document.id="grid_fixture";document.spawn=[8160,6784];document.objects=[{"id":"obj_worker","kind":"npc","x":8160,"y":6752,"name":"Bento","appearance":"bento"}]
	MapDocument.activate(MapDocument.validate(document).document);game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.start_journey();game.player.set_physics_process(false);game.economy.set_process(false);game.world.set_population_active(false)
	game.rpg.wood=2000;game.rpg.stone=2000;game.rpg.construction.stock.plank=200;game.rpg.tools.hammer=true;game.world.clock.active=false;game.weather_mode="clear"
	for y in range(100,104):
		for x in range(125,129):game.rpg.construction.place(game.rpg,"wood_floor",Vector2i(x,y))
	for x in range(125,129):
		game.rpg.construction.place(game.rpg,"wood_wall",Vector2i(x,100))
		game.rpg.construction.place(game.rpg,"stone_wall",Vector2i(x,104),0)
	for y in range(100,104):
		game.rpg.construction.place(game.rpg,"wood_wall",Vector2i(125,y),1)
		game.rpg.construction.place(game.rpg,"stone_wall",Vector2i(129,y),1)
	var removed:=""
	for id in game.rpg.construction.pieces:
		var data:Dictionary=game.rpg.construction.pieces[id]
		if data.kind=="stone_wall" and data.x==127 and data.y==104:removed=id
	game.rpg.construction.remove(game.rpg,removed,false)
	var door:=game.rpg.construction.place(game.rpg,"door",Vector2i(127,104))
	await frames(5)
	var outside:=Vector2(8160,6720);var inside:=Vector2(8160,6592);var npc:ForestNPC=game.world.npcs.obj_worker
	var start:=npc._nearest_cell(outside);var end:=npc._nearest_cell(inside)
	verify(game.world.navigator.cell_size==Vector2.ONE*WorldGrid.CELL/2,"navegação amostra meios de célula para representar bordas e vãos")
	verify(game.world.navigator.get_point_path(start,end).is_empty(),"quarto fechado não oferece rota através das bordas")
	game.player.position=outside;var transform:=game.player.transform
	verify(game.player.test_move(transform,inside-outside),"parede da porta bloqueia o corpo do jogador")
	game.construction.toggle_door(door.id);game.close_dialog();game.world.set_population_active(false);await frames(4)
	verify(not game.world.navigator.get_point_path(start,end).is_empty() and not game.player.test_move(transform,inside-outside),"porta aberta libera física e rota no centro do vão")
	npc.position=outside;npc.active=true;npc.sleeping=false;npc.wants_rest=false;npc.set_economic_goal(inside,"Testando a travessia")
	for i in 130:await frames(1)
	verify(npc.position.distance_to(inside)<16 and WorldData.can_stand(npc.position,game.world.data,9),"NPC atravessa a porta com física real e chega ao interior")
	npc.active=false;game.world.set_population_active(false);game.player.position=Vector2(8160,6784)
	game.construction.begin_piece("wood_wall");await frames(3)
	if graphics:
		var mouse:Vector2=game.hybrid.camera.unproject_position(WorldGrid.point3(Vector2(8007,6370)));Input.warp_mouse(mouse)
		var motion:=InputEventMouseMotion.new();motion.position=mouse;motion.global_position=mouse;Input.parse_input_event(motion);await frames(4)
		verify(game.hybrid.build_grid.visible and game.hybrid.piece_ghost.visible and fmod(game.hybrid.piece_ghost.position.x,1)==0 and fmod(game.hybrid.piece_ghost.position.z,1)==0,"prévia e linhas-guia usam vértices idênticos no mundo 3D")
		game.hybrid.snap_camera();await frames(3);game.set_process(false)
		await RenderingServer.frame_post_draw;var on:=root.get_texture().get_image();game.hybrid.build_grid.hide();await frames(2)
		await RenderingServer.frame_post_draw;var off:=root.get_texture().get_image();var sampled:=0;var visible:=0
		var grid_center:=Vector2i(roundi(game.hybrid.build_grid.position.x),roundi(game.hybrid.build_grid.position.z))
		for x in range(grid_center.x-6,grid_center.x+7):
			for z in range(grid_center.y-6,grid_center.y+7):
				var pixel:=Vector2i(game.hybrid.camera.unproject_position(Vector3(x,WorldGrid.FLOOR_HEIGHT+0.006,z+0.35)))
				if pixel.x<305 or pixel.x>1000 or pixel.y<170 or pixel.y>590 or pixel.x>450 and pixel.x<750:continue
				sampled+=1;var delta:=0.0
				for dy in range(-2,3):
					for dx in range(-2,3):
						var a:=on.get_pixelv(pixel+Vector2i(dx,dy));var b:=off.get_pixelv(pixel+Vector2i(dx,dy));delta=maxf(delta,absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b))
				if delta>0.12:visible+=1
		print("GRID PIXELS: ",visible,"/",sampled," pontos visíveis")
		verify(sampled>=8 and visible>sampled/2,"linhas-guia produzem pixels visíveis sobre a grama nas posições previstas")
		game.hybrid.build_grid.show();game.set_process(true);game.hud.toast_panel.hide();await capture("guias")
	else:verify(is_instance_valid(game.construction.grid_guide) and game.construction.grid_guide.visible,"modo 2D também mostra linhas-guia e pivô")
	game.cancel_building();await frames()
	verify((not game.hybrid.build_grid.visible if graphics else not game.construction.grid_guide.visible),"sair da construção esconde as guias")
	game.construction.show_catalog();game.construction.show_audit();verify(game.hud.modal_kind=="construction_audit" and game.construction.audit_report().existing.ok,"B oferece auditoria do assentamento existente")
	game.construction.export_audit();var path:String="user://reports/"+MapDocument.current.id+"-grid.json"
	verify(FileAccess.file_exists(path) and JSON.parse_string(FileAccess.get_file_as_string(path)).existing.checked==game.rpg.construction.pieces.size(),"relatório exportado percorre todas as peças, inclusive as sem modelo carregado")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path));game.close_dialog()
	if graphics:
		var model:ConstructionVisual=game.hybrid.landscape.piece_models[door.id];model.position.x+=0.05
		verify(not game.construction.audit_report().existing.ok and game.construction.audit_report().existing.issues.any(func(row:Dictionary):return row.id==door.id and row.code=="model_pivot"),"validador detecta deslocamento real do modelo carregado")
		model.position.x-=0.05;game.hud.toast_panel.hide();game.construction.show_audit();await capture("validacao");game.close_dialog();game.hybrid.snap_camera();game.hud.toast_panel.hide();await capture("cantos")
	var data:Dictionary=game.rpg.construction.pieces[door.id];data.x+=0.25
	verify(game.construction.audit_report().existing.issues.any(func(row:Dictionary):return row.id==door.id and row.code=="off_grid"),"validador identifica o ID da peça desalinhada nos dados")
	data.x-=0.25;var body:Node2D=game.world.pieces[door.id];body.position.x+=1
	verify(game.construction.audit_report().existing.issues.any(func(row:Dictionary):return row.id==door.id and row.code=="collision_pivot"),"validador também encontra colisor deslocado")
	body.position.x-=1
	game.queue_free();await frames()
