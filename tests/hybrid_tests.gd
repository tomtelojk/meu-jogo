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
	for i in count:
		await physics_frame
		await process_frame
func capture(name:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/entre-reinos-"+name+".png")
func move_to(point:Vector2)->void:
	game.player.position=point
	game.player.restore_surface()
	game.world.ensure_region(point,true)
	game.hybrid.snap_camera()
	await frames(4)
func click(label:String)->bool:
	for button in game.hud.modal.find_children("*","Button",true,false):
		if button.text.contains(label):button.pressed.emit();return true
	return false
func run()->void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(5)
	verify(game.hybrid!=null and game.hybrid.camera.current,"câmera 3D e visual 2.5D continuam ativos")
	verify(is_equal_approx(root.scaling_3d_scale,0.65),"modo leve continua padrão com interface nítida")
	verify(game.hybrid.landscape.regions.size()==game.world.chunks.size(),"cada região ativa tem terreno, recursos e visuais sincronizados")
	await capture("intro")
	game.start_journey()
	await frames(5)
	await capture("aurelia")
	await move_to(KingdomData.REALMS.aurelia.capital+Vector2(0,-300))
	await capture("castelo")
	await move_to(KingdomData.point("aurelia_shop")+Vector2(0,32))
	verify(game.current_interaction().get("kind")=="shop","E encontra a ferraria sinalizada na cidade")
	game.interact()
	await frames()
	verify(game.hud.modal_kind=="shop","interação abre comércio real")
	verify(click("Comprar ferramentas"),"menu oferece ferramentas para compra")
	await frames()
	verify(click("Machado"),"botão da loja compra um machado")
	await frames()
	verify(game.rpg.tools.has("axe") and game.rpg.gold==75,"compra pela interface altera inventário e carteira")
	verify(game.hud.modal_panel.position.y>=0 and game.hud.modal_panel.size.y<=800,"menu rolável cabe na tela")
	await capture("loja")
	game.close_dialog()
	game.rpg.buy("pickaxe");game.rpg.buy("hammer")
	game.rpg.wood=50;game.rpg.stone=20
	await move_to(Vector2(6000,6000))
	var site:=Vector2.ZERO
	for y in range(-256,257,32):
		for x in range(-256,257,32):
			var candidate:=game.player.position+Vector2(x,y)
			if game.can_build_at(candidate).ok:site=candidate;break
		if site!=Vector2.ZERO:break
	verify(site!=Vector2.ZERO,"campo oferece terreno físico livre para construção")
	if site!=Vector2.ZERO:
		game.start_building()
		var screen:=game.hybrid.camera.unproject_position(Vector3(site.x/64,0,site.y/64))
		Input.warp_mouse(screen)
		await frames()
		verify(game.hybrid.build_ghost!=null and game.hybrid.build_ghost.visible,"B mostra prévia da casa antes de gastar moedas")
		await capture("terreno")
		verify(game.place_house(site).ok,"confirmar terreno cria obra no mundo 3D")
		game.close_dialog()
		await move_to(site+Vector2(0,96))
		for stage in 3:
			game.build_house("home_player")
			game.close_dialog()
			await frames()
			verify(game.hybrid.landscape.house_models.has("home_player"),"obra 3D acompanha etapa %d"%[stage+1])
			await capture("casa-etapa-"+str(stage+1))
		verify(game.rpg.houses.home_player.stage==3,"fundação, paredes e telhado completam uma casa jogável")
	# Simulate a worker's real route and purchases without waiting several
	# minutes of wall time, then render the resulting resident-owned house.
	var builder:ForestNPC=game.world.npcs.pedra_alta_resident_0
	builder.active=true
	for i in 400:
		game.economy.advance_builder(builder,2.0)
		builder.advance_offscreen(2.0)
		if game.rpg.houses.get("home_"+builder.definition.id,{}).get("stage",0)==3:break
	var npc_home:Dictionary=game.rpg.houses.get("home_"+builder.definition.id,{})
	verify(not npc_home.is_empty() and npc_home.stage==3,"morador conclui sua própria obra sem recursos do jogador")
	if not npc_home.is_empty():
		await move_to(Vector2(npc_home.x,npc_home.y+120))
		await capture("casa-npc")
		verify(game.hybrid.landscape.house_models.has("home_"+builder.definition.id),"casa do NPC aparece no mundo 3D")
	# Travel renders a distant region and releases the previous 25 chunks.
	var before:=game.world.chunks.keys()
	game.rpg.gold=100
	game.open_inn("aurelia")
	game.travel_to("valverde")
	await frames(5)
	verify(game.hybrid.landscape.regions.size()<=25,"troca de reino mantém o limite de regiões renderizadas")
	var shared:=0
	for coord in before:
		if game.world.chunks.has(coord):shared+=1
	verify(shared==0,"regiões da antiga localização são liberadas após a caravana")
	await capture("valverde")
	game.open_inn("valverde");game.travel_to("pedra_alta")
	await frames(4)
	await capture("pedra-alta")
	await move_to(KingdomData.REALMS.aurelia.capital+Vector2(1600,864))
	verify(game.world.animals.size()>=3,"fazenda carrega animais do mundo aberto")
	var visual:=false
	for region in game.hybrid.landscape.regions.values():
		for child in region.get_children():
			if child is AnimalVisual:visual=true
	verify(visual,"animais usam modelos 3D animados de verdade")
	await capture("animais")
	var home:Dictionary=game.rpg.houses.home_player
	game.show_map()
	await frames()
	verify(game.hud.modal_kind=="map","M abre mapa com duas capitais, quatro vilarejos e a casa")
	await capture("mapa")
	game.close_dialog()
	var river:=Vector2(WorldData.river_x(4800),4800+150)
	await move_to(river)
	game.player.restore_surface(true)
	await frames()
	verify(game.player.swimming and game.hybrid.swim_ripple.visible,"natação e ondulação funcionam no rio ampliado")
	await capture("rio")
	print("RPG GRAPHICS: %d verificações; %d falhas."%[checks,failures])
	quit(1 if failures else 0)
