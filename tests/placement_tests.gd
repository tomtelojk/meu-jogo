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
func capture(label:String)->void:
	if game.hybrid==null:return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/placement-"+label+".png")
func context(manager:RoadManager)->Dictionary:
	return {"roads":manager,"base":"vazio","generation":3,"terrain":{},"buildings":[],"resources":[],"rules":PlacementRules.defaults()}
func fixture()->Dictionary:
	var doc:=MapDocument.blank();doc.id="placement_fixture";doc.spawn=[8000,6800]
	for x in range(119,132):doc.terrain["%d,99"%x]="dirt"
	doc.objects=[MapDocument.clean_object({"id":"obj_bad","kind":"cottage","name":"Casa na estrada","x":8000,"y":6400,"house_style":"poor","house_seed":42,"house_turn":0}),MapDocument.clean_object({"id":"obj_good","kind":"cottage","name":"Casa livre","x":9100,"y":7000,"house_style":"poor","house_seed":43,"house_turn":0})]
	return doc
func run()->void:
	var manager:=RoadManager.new();manager.register_path("horizontal",PackedVector2Array([Vector2(1000,1950),Vector2(5000,1950)]))
	verify(manager.roads[0].curve is Curve3D and manager.roads[0].curve.get_point_count()==2,"estrada registrada como Curve3D com largura única")
	var source_curve:=Curve3D.new();source_curve.add_point(Vector3(80,0,80));source_curve.add_point(Vector3(90,0,80))
	var live:=RoadManager.new();live.register_curve("editable",source_curve,1.5)
	verify(not live.overlap(Rect2(5300,5100,100,100)).is_empty(),"Curve3D externa controla a área registrada")
	source_curve.set_point_position(0,Vector3(80,0,90));source_curve.set_point_position(1,Vector3(90,0,90))
	verify(live.overlap(Rect2(5300,5100,100,100)).is_empty() and not live.overlap(Rect2(5300,5730,100,100)).is_empty(),"editar Curve3D atualiza o índice de validação")
	var rect:=Rect2(1800,1800,1000,1000)
	var old_misses:=true
	for y in [0.0,0.5,1.0]:
		for x in [0.0,0.5,1.0]:old_misses=old_misses and absf((rect.position+rect.size*Vector2(x,y)).y-1950)>=70
	verify(old_misses and not PlacementValidator.validate(rect,context(manager)).ok,"estrada entre as nove amostras antigas é detectada pela área inteira")
	verify(not manager.overlap(Rect2(5080,1940,20,20),32).is_empty(),"extremidade arredondada da estrada tem margem")
	verify(manager.overlap(Rect2(2000,2034,128,128),32).is_empty(),"terreno além da borda e da margem é aceito")
	verify(not manager.overlap(Rect2(2000,2033.5,128,128),32).is_empty(),"contato exato com a margem é rejeitado")
	manager.register_path("diagonal",PackedVector2Array([Vector2(1400,3000),Vector2(1800,3400),Vector2(2200,3000)]),90,12)
	verify(not manager.overlap(Rect2(1740,3390,80,30),16).is_empty(),"curvas largas e junções diagonais respeitam seu contorno")
	var painted:Dictionary={}
	for y in range(28,34):
		for x in range(30,40):painted["%d,%d"%[x,y]]="grass"
	manager.set_terrain(painted)
	verify(manager.overlap(Rect2(2100,1930,128,40)).is_empty(),"grama pintada remove apenas a parte coberta da estrada")
	verify(not manager.overlap(Rect2(1900,1930,128,40)).is_empty(),"parte não coberta da mesma curva continua protegida")
	painted["35,35"]="stone";manager.set_terrain(painted)
	verify(not manager.overlap(Rect2(2240,2240,64,64)).is_empty(),"estrada pintada em grid também é registrada")
	var empty:=RoadManager.new();var ctx:=context(empty);ctx.terrain={"35,35":"water"}
	verify(not PlacementValidator.validate(Rect2(2000,2000,700,700),ctx).ok,"ilha de água dentro de terreno grande não escapa entre cantos")
	verify(PlacementValidator.validate(Rect2(2200,2200,192,128),ctx,{"bridge":true}).ok,"ponte é a exceção explícita para água e estrada")
	ctx.buildings=[{"id":"house","rect":Rect2(2200,2200,128,128)}]
	verify(not PlacementValidator.validate(Rect2(2200,2200,192,128),ctx,{"bridge":true}).ok,"ponte ainda respeita outras construções")
	ctx=context(empty);ctx.resources=[{"id":"boulder","position":Vector2(2310,2200),"radius":14.0,"size":55.0,"kind":"stone"}]
	verify(not PlacementValidator.validate(Rect2(2200,2100,80,200),ctx).ok,"rocha bloqueia pela área visível, além do colisor pequeno")
	ctx.resources[0].active=false
	verify(PlacementValidator.validate(Rect2(2200,2100,80,200),ctx).ok,"rocha retirada deixa o terreno livre")
	ctx=context(empty);ctx.buildings=[{"id":"other","rect":Rect2(3000,3000,128,128),"decoration":true}]
	verify(not PlacementValidator.validate(Rect2(3208,3000,128,128),ctx,{"decoration":true}).ok and PlacementValidator.validate(Rect2(3210,3000,128,128),ctx,{"decoration":true}).ok,"margem entre casas inclui os dois beirais")
	var original:=MapDocument.original();var audit:=PlacementAudit.scan(original)
	verify(audit.ok and audit.checked>=120 and audit.road_curves>70,"nova geração tem vilas grandes sem conflitos com estradas, água, rochas ou casas")
	verify(KingdomData.NATURAL_V2.buildings.size()==126 and KingdomData.NATURAL_V2.roads.size()==184,"desenho antigo foi preservado como dados, com os mesmos IDs")
	var directions:=[Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT]
	for building in KingdomData.buildings_for_document(original):
		verify(PlacementValidator.validate(KingdomData.building_rect(building),PlacementValidator.map_context(original,[],RoadManager.current()),{"ignore_id":building.id,"decoration":true}).ok,"lote validado por área: "+building.id)
		if building.kind in ["cottage","timber","stone_house"]:
			var near:=RoadManager.current().nearest(KingdomData.building_rect(building).get_center())
			var forward:Vector2=directions[int(building.house_turn)]
			verify(forward.dot((near.point-KingdomData.building_rect(building).get_center()).normalized())>=0.65,"casa voltada para a rua: "+building.id)
	var doc:=fixture();var before:=PlacementAudit.scan(doc)
	verify(not before.ok and before.issues[0].code=="road","auditoria identifica casa existente sobre a estrada")
	var repaired:=PlacementAudit.repair(doc)
	verify(repaired.ok and repaired.moved.size()==1 and repaired.document.objects[1]==doc.objects[1],"realocação corrige apenas a casa inválida")
	verify(doc.objects[0].x==8000 and doc.objects[0].y==6400 and repaired.document.objects[0].id=="obj_bad","realocação mantém ID e preserva o documento original")
	var journey:={"version":2,"map_id":doc.id,"world_generation":3,"x":8000,"y":6800,"seeds":[],"rpg":{"gold":777,"wood":91,"stone":44,"tools":["hammer"],"houses":{"home_player":{"owner":"player","x":7904,"y":6380,"stage":3,"hp":123,"note":"preserve"}},"construction":{"grid_version":2,"stock":{"plank":12},"pieces":{},"queues":{}},"relationships":{"custom":"memory"},"future":{"field":42}}}
	var repaired_save:=PlacementAudit.repair(doc,journey)
	verify(repaired_save.ok and repaired_save.save.rpg.houses.home_player.hp==123 and repaired_save.save.rpg.houses.home_player.note=="preserve","realocação de casa pessoal conserva vida e campos extras")
	verify(repaired_save.save.rpg.gold==777 and repaired_save.save.rpg.construction==journey.rpg.construction and repaired_save.save.rpg.relationships==journey.rpg.relationships and repaired_save.save.rpg.future==journey.rpg.future,"inventário, filas, vínculos e dados futuros não são reescritos")
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames(4);game.start_journey()
	await capture("vila")
	var road:Dictionary=RoadManager.current().roads[0]
	game.player.position=road.points[1];game.player.restore_surface()
	var gold:=game.rpg.gold
	verify(not game.can_build_at(game.player.position).ok and not game.rpg.claim(game.player.position).ok and game.rpg.gold==gold,"prévia e reserva recusam estrada sem cobrar moedas")
	verify(not game.construction.can_place("wood_floor",game.player.position).ok,"piso avulso passa pela mesma proteção de estradas")
	game.show_map_editor();await frames();var editor:=game.map_editor
	editor.replace_document(doc);editor.show_placement_audit();await frames()
	await capture("editor-conflitos")
	verify(not editor.placement_report.ok,"ateliê mostra os lotes existentes em conflito")
	await editor.repair_placement();verify(editor.placement_report.ok,"botão do ateliê realoca e verifica novamente")
	editor.undo();verify(not PlacementAudit.scan(editor.draft).ok,"desfazer restaura a disposição anterior")
	editor.redo();verify(PlacementAudit.scan(editor.draft).ok,"refazer recupera as posições corrigidas")
	editor.draft=MapDocument.blank();editor.tool="stone_house";editor.house_seed=42;editor.house_turn=0;editor.invalidate_placement()
	var target:=Vector2(8000,6400);var footprint:=KingdomData.building_rect(editor.preview_building(target))
	var hidden:=WorldGrid.cell_at(footprint.position+Vector2(64,64));editor.draft.terrain[MapDocument.cell_key(hidden)]="water";editor.invalidate_placement()
	verify(not editor.valid_at(target),"editor detecta água interna entre amostras de um kit grande")
	editor.draft.terrain[MapDocument.cell_key(hidden)]="dirt";editor.invalidate_placement()
	verify(not editor.valid_at(target),"editor detecta estrada interna entre amostras de um kit grande")
	editor.close();game.apply_map(doc);await frames()
	game.player.position=Vector2(8000,6550);game.player.restore_surface()
	if game.hybrid!=null:game.hybrid.snap_camera()
	game.placement.show_audit();verify(game.hud.modal_kind=="placement_audit" and not game.placement.last_report.ok,"auditoria também está disponível no jogo pronto")
	await frames();await capture("relatorio")
	await game.placement.repair();await frames()
	verify(PlacementAudit.scan(MapDocument.current,game.journey_data()).ok,"realocação no jogo reconstrói mapa, física e portas com dados válidos")
	game.close_dialog();await frames();await capture("corrigido")
	game.placement.undo();await frames()
	verify(not PlacementAudit.scan(MapDocument.current).ok,"desfazer no jogo restaura o mapa anterior")
	if game.hybrid!=null:
		verify(game.hybrid.get_node_or_null("RoadManagerPaths")!=null,"rede de estradas também existe como Path3D na cena")
		var editable:=Curve3D.new();editable.add_point(Vector3(118,0,112));editable.add_point(Vector3(132,0,112))
		RoadManager.current().register_curve("live_road",editable,1.5)
		verify(game.hybrid.get_node("RoadManagerPaths/live_road").curve==editable,"Path3D mantém a Curve3D original como fonte")
		editable.set_point_position(1,Vector3(132,0,114));await frames()
		verify(not RoadManager.current().overlap(Rect2(8390,7240,80,100)).is_empty(),"edição da curva atualiza simultaneamente estrada e validação")
	game.free();await frames();MapDocument.activate(MapDocument.original())
	print("PLACEMENT: %d verificações; %d falhas."%[checks,failures]);quit(1 if failures else 0)
