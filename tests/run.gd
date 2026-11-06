extends SceneTree

var checks:=0
var failures:=0
var game:ForestGame

func _initialize()->void:
	var timeout:=Timer.new()
	timeout.wait_time=120
	timeout.one_shot=true
	timeout.autostart=true
	root.add_child(timeout)
	timeout.timeout.connect(func():push_error("Teste excedeu 120 segundos");quit(1))
	call_deferred("run")

func verify(ok:bool,label:String)->void:
	checks+=1
	if ok:print("PASS: "+label)
	else:failures+=1;push_error("FAIL: "+label)

func frames(count:int=3)->void:
	for i in count:
		await physics_frame
		await process_frame

func move_to(point:Vector2,swim:bool=false)->void:
	game.player.position=point
	game.player.restore_surface(swim)
	game.world.ensure_region(point,true)
	await frames()

func run()->void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.start_journey()
	await frames()
	var state:=game.rpg
	verify(WorldData.SIZE==Vector2(16000,12800) and WorldData.COLS*WorldData.ROWS==50000,"mapa tem 25 vezes a área original")
	verify(KingdomData.SETTLEMENTS.size()==6 and KingdomData.REALMS.size()==2,"duas capitais e quatro vilarejos têm posições próprias")
	verify(KingdomData.BUILDINGS.size()>=120 and game.world.npcs.size()==44,"reinos ampliados têm mais de 120 construções e 44 NPCs")
	verify(game.world.chunks.size()<=25 and game.world.resources.size()<500,"mundo carrega apenas as regiões próximas")
	verify(game.hud.quest_title.text.contains("Nível") and not game.hud.quest_title.text.contains("semente"),"interface e objetivo principal são de RPG")
	var overlap:=false
	for i in KingdomData.BUILDINGS.size():
		for j in range(i+1,KingdomData.BUILDINGS.size()):
			if KingdomData.building_rect(KingdomData.BUILDINGS[i]).intersects(KingdomData.building_rect(KingdomData.BUILDINGS[j])):
				push_error("Prédios sobrepostos: %s / %s"%[KingdomData.BUILDINGS[i].name,KingdomData.BUILDINGS[j].name])
				overlap=true
	verify(not overlap,"paredes das cidades não se sobrepõem")
	for town in KingdomData.SETTLEMENTS:
		var at:Vector2=town.position+Vector2(0,384)
		verify(WorldData.can_stand(at,game.world.data),"entrada de "+town.name+" está livre")
		var start:Vector2i=game.world.npcs.bento._nearest_cell(WorldData.SPAWN)
		var end:Vector2i=game.world.npcs.bento._nearest_cell(at)
		verify(not game.world.navigator.get_id_path(start,end).is_empty(),"há rota terrestre até "+town.name)
	# Source artwork and directional pivots continue to be verified.
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/tomate/sources.json"))
	var intact:=true
	for entry in manifest.files:intact=intact and FileAccess.get_sha256("res://"+entry.path)==entry.sha256
	verify(intact,"os dez PNGs recebidos mantêm os bytes originais")
	preload("res://tests/bundled_npc_tests.gd").run(self,game.world)
	var first_gold:=state.gold
	verify(not state.harvest("test_wood","wood").ok and not state.depleted.has("test_wood"),"sem machado não se recolhe madeira nem se esgota o recurso")
	verify(state.buy("axe").ok and state.gold==first_gold-25,"comprar machado desconta moedas")
	var gold:=state.gold
	verify(not state.buy("axe").ok and state.gold==gold,"ferramenta duplicada não cobra novamente")
	verify(state.buy("pickaxe").ok and state.buy("hammer").ok,"picareta e martelo podem ser comprados")
	state.gold=0
	verify(not state.buy("sword").ok and not state.tools.has("sword"),"loja impede compra sem moedas")
	state.gold=100
	await move_to(KingdomData.point("aurelia_wood")+Vector2(0,140))
	var target:Dictionary={}
	for entry in game.world.resources.values():
		if entry.resource.kind!="wood":continue
		var isolated:=true
		for npc in game.world.npcs.values():
			if npc.position.distance_to(entry.resource.position)<120:isolated=false;break
		if isolated:target=entry;break
	verify(not target.is_empty(),"arvoredo fornece madeira de verdade no cenário")
	if not target.is_empty():
		await move_to(target.resource.position+Vector2(0,35))
		var interaction:=game.current_interaction()
		verify(interaction.get("kind")=="resource","sensor encontra um recurso próximo")
		var before:=state.wood
		game.interact()
		await frames()
		verify(state.wood==before+5 and state.depleted.has(interaction.id),"E usa a ferramenta, entrega madeira e remove o recurso")
		var after:=state.wood
		verify(not state.harvest(interaction.id,"wood").ok and state.wood==after,"recurso esgotado não duplica material")
	# Gather real deterministic nodes to exercise the complete construction cost.
	for entry in game.world.resources.values():
		if entry.resource.kind=="wood" and state.wood<75:state.harvest(entry.resource.id,"wood")
		elif entry.resource.kind=="stone" and state.stone<45:state.harvest(entry.resource.id,"stone")
	verify(state.wood>=50 and state.stone>=20,"madeira e pedra do mundo suprem uma casa completa")
	gold=state.gold
	verify(state.sell("wood",10).ok and state.gold==gold+20,"venda converte madeira em moeda")
	verify(not state.sell("stone",999).ok,"venda não permite inventário negativo")
	var paid:=state.deliver("aurelia",game.world.clock.day)
	verify(paid.ok,"encomenda consome os recursos e paga moedas e XP")
	gold=state.gold
	verify(not state.deliver("aurelia",game.world.clock.day).ok and state.gold==gold,"encomenda não pode ser repetida no mesmo dia")
	# Supply the remaining house materials explicitly after the trade checks.
	state.wood=50;state.stone=20
	await move_to(Vector2(6000,6000))
	var site:=Vector2.ZERO
	for y in range(-256,257,32):
		for x in range(-256,257,32):
			var p:=game.player.position+Vector2(x,y)
			if game.can_build_at(p).ok:site=p;break
		if site!=Vector2.ZERO:break
	verify(site!=Vector2.ZERO,"há terreno livre fora de ruas, rios, recursos e prédios")
	verify(not game.can_build_at(KingdomData.REALMS.aurelia.capital).ok,"construção não bloqueia ruas ou locais distantes")
	if site!=Vector2.ZERO:
		var claimed:=game.place_house(site)
		verify(claimed.ok and state.houses.has("home_player"),"reservar terreno cria uma obra interativa")
		game.close_dialog()
		await move_to(site+Vector2(0,48))
		state.tools.erase("hammer")
		verify(not state.build("home_player").ok and state.houses.home_player.stage==0,"construir exige martelo")
		state.tools.hammer=true
		var before:=state.wood
		game.build_house("home_player")
		await frames()
		verify(state.houses.home_player.stage==1 and state.wood==before-15,"fundação consome o primeiro lote e cria colisão")
		game.close_dialog()
		var wall:=state.home_rect(state.houses.home_player)
		game.player.position=Vector2(site.x,site.y+24)
		var hit:=game.player.move_and_collide(Vector2(0,-200))
		verify(hit!=null and not WorldData.circle_hits_rect(game.player.position,9.8,wall),"obra tem parede física desde a fundação")
		game.build_house("home_player");game.close_dialog()
		game.build_house("home_player");game.close_dialog()
		verify(state.houses.home_player.stage==3 and state.wood==0 and state.stone==0,"paredes e telhado completam a casa sem criar recursos")
		var remaining:=state.wood
		verify(not state.build("home_player").ok and state.wood==remaining,"casa concluída não cobra etapa extra")
		await move_to(WorldData.SPAWN)
		game.build_house("home_player")
		verify(game.mode=="playing","construir à distância não abre acesso remoto ao lar")
	state.gold=100
	var previous_regions:=game.world.chunks.keys()
	game.open_inn("aurelia")
	verify(game.travel_to("porto_claro"),"caravana chega ao povoado escolhido")
	await frames()
	verify(game.world.chunks.size()<=25 and game.player.position.distance_to(KingdomData.SETTLEMENTS[4].position)<500,"viagem descarrega regiões antigas e mantém o limite de memória")
	verify(state.discovered.has("porto_claro") and state.gold==95,"viagem paga custo e registra exploração")
	var a:=WorldData.generate_chunk(Vector2i(24,18),game.world.data)
	var b:=WorldData.generate_chunk(Vector2i(24,18),game.world.data)
	verify(JSON.stringify(a)==JSON.stringify(b),"região é determinística e não muda ao retornar")
	var saved:=JSON.parse_string(JSON.stringify(game.journey_data())) as Dictionary
	state.gold=1;state.tools.clear();state.houses.clear()
	verify(game.apply_journey(saved) and state.gold==95 and state.tools.has("axe") and state.houses.home_player.stage==3,"salvamento restaura inventário, dinheiro, ferramentas e casa")
	var snapshot:=game.journey_data()
	state.houses.home_player.stage=1
	verify(snapshot.rpg.houses.home_player.stage==3,"snapshot de salvamento não muda quando a casa avança depois")
	game.apply_journey(snapshot)
	verify(not game.apply_journey({"version":2.5,"seeds":[]}),"versão fracionária de save é rejeitada")
	game.save_path="/tmp/entre-reinos-test-save.json";game.persistence=true;game.save_journey()
	state.gold=0
	game._load_journey()
	verify(state.gold==95,"salvamento em disco restaura a economia")
	game.persistence=false;DirAccess.remove_absolute(game.save_path)
	verify(game.apply_journey({"version":1,"seeds":["flores"],"x":800,"y":960}) and game.player.position==WorldData.SPAWN,"save antigo migra para a entrada da capital preservando a tradição opcional")
	# A remote worker uses the same wallet, tools and material costs as the player.
	var builder:ForestNPC=game.world.npcs.pedra_alta_resident_0
	builder.active=true
	game.world.clock.set_time(8.5)
	var elapsed:=0.0
	for i in 350:
		if not builder.wants_rest:
			game.economy.advance_builder(builder,2.0)
		builder.advance_offscreen(2.0)
		game.world.clock.advance(4.0)
		elapsed+=2.0
		if state.houses.get("home_"+builder.definition.id,{}).get("stage",0)==3:break
	var account:=state.npc_account(builder.definition.id)
	verify(account.tools.has("axe") and account.tools.has("pickaxe") and account.tools.has("hammer") and account.gold<100,"NPC compra as três ferramentas com suas próprias moedas")
	verify(state.houses.get("home_"+builder.definition.id,{}).get("stage",0)==3,"NPC viaja, coleta material e constrói sua própria casa")
	verify(builder.home_override.is_finite(),"rotina do morador passa a usar a casa construída")
	# Swimming and combat remain part of the new open world.
	var water:=Vector2(WorldData.river_x(7000),7000)
	await move_to(water,true)
	verify(game.player.swimming,"rio continua permitindo natação")
	var start:=game.player.position
	game.show_pause()
	await frames(10)
	verify(game.player.position==start,"pausa impede correnteza e animais de mover o jogador")
	game.close_dialog()
	await move_to(WorldData.SPAWN)
	state.health=40
	verify(state.eat().ok and state.health==70,"provisão recupera vida e é consumida")
	state.gold=100;state.buy("sword")
	var boar:=WorldAnimal.new()
	boar.setup({"id":"test_boar","species":"boar","position":game.player.position+Vector2(20,0)},game)
	game.world.entities.add_child(boar);game.world.animals.test_boar=boar
	var meat:=state.meat
	for i in 4:game.action_delay=0;game.attack()
	verify(not boar.alive and state.meat>meat,"combate com espada derrota animal e entrega saque e XP")
	var xp:=state.xp
	game.action_delay=0;game.attack()
	verify(state.xp==xp,"animal derrotado não duplica experiência")
	state.health=1
	game.take_damage(9)
	verify(state.health==60 and game.player.position.is_finite(),"personagem socorrido retorna com equipamento e vida")
	print("RPG: %d verificações; %d falhas."%[checks,failures])
	quit(1 if failures else 0)
