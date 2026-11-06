extends SceneTree

var game: ForestGame
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func verify(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS: " + label)
	else:
		failures += 1
		push_error(label)

func frames(count: int = 2) -> void:
	for i in count:
		await physics_frame
		await process_frame

func place(point: Vector2, under_bridge: bool = false) -> void:
	game.player.position = point
	game.player.restore_surface(under_bridge)
	await frames()

func hold(action: String, count: int) -> void:
	Input.action_press(action)
	await frames(count)
	Input.action_release(action)
	await frames()

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.persistence = false
	await frames()
	var player := game.player
	# Sweep the actual circular body through every wall at running speed and
	# beyond, rather than only asserting that a collider node exists.
	for index in KingdomData.BUILDINGS.size():
		var building: Dictionary = KingdomData.BUILDINGS[index]
		var rect := KingdomData.building_rect(building)
		var center := rect.get_center()
		var sides := [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
		var blocked := true
		for direction in sides:
			var start: Vector2 = center + direction * (rect.size / 2.0 + Vector2.ONE * 20)
			player.position = start
			player.restore_surface()
			var hit := player.move_and_collide(-direction * (rect.size + Vector2.ONE * 80))
			blocked = blocked and hit != null and not WorldData.circle_hits_rect(player.position,9.9,rect)
		verify(blocked, "quatro paredes impedem atravessar em alta velocidade: " + building.name)
	var house := KingdomData.building_rect(KingdomData.BUILDINGS[11])
	verify(WorldData.can_stand(house.end + Vector2(8,8),game.world.data), "canto arredondado permite passar fora da parede, sem obstáculo invisível")
	verify(not WorldData.can_stand(house.get_center(),game.world.data,10,true), "natação nunca libera atravessar casas")
	game.start_journey()
	game.world.set_population_active(false)
	await place(Vector2(house.get_center().x,house.end.y+10.2))
	var start := player.position
	Input.action_press("move_up")
	await hold("move_left",20)
	Input.action_release("move_up")
	verify(player.position.x < start.x-20 and player.position.y>=house.end.y+9.8, "personagem desliza pela parede sem grudar ou atravessar")
	var bridge := WorldData.BRIDGE_RECT
	verify(absf(bridge.get_center().x-WorldData.river_x(bridge.get_center().y))<0.01, "ponte e rampas ficam centralizadas entre as duas margens")
	await place(bridge.get_center())
	await hold("move_up",40)
	verify(player.on_bridge and not player.swimming and player.position.y>=bridge.position.y+9.8, "corrimão norte impede cair da ponte")
	await place(bridge.get_center())
	await hold("move_down",40)
	verify(player.on_bridge and not player.swimming and player.position.y<=bridge.end.y-9.8, "corrimão sul impede cair da ponte")
	await place(Vector2(bridge.position.x-20,bridge.get_center().y))
	Input.action_press("run")
	Input.action_press("move_right")
	await frames(55)
	verify(player.on_bridge and player.surface_height()>45 and not player.swimming, "rampa sobe para o tablado sem ativar natação")
	await frames(80)
	Input.action_release("run")
	Input.action_release("move_right")
	verify(player.position.x>bridge.end.x+10 and not player.on_bridge and not player.swimming, "saída pela rampa retorna ao chão")
	var y := bridge.position.y-45
	await place(Vector2(WorldData.river_x(y),y),true)
	Input.action_press("move_down")
	await frames(65)
	verify(player.swimming and not player.on_bridge and bridge.has_point(player.position), "nadador passa sob a ponte sem subir no tablado")
	await frames(70)
	Input.action_release("move_down")
	verify(player.position.y>bridge.end.y+10 and player.swimming, "nadador atravessa sob ambos os corrimãos sem bloqueio invisível")
	for direction in ["move_left","move_right"]:
		await place(Vector2(WorldData.river_x(1000),1000),true)
		await hold(direction,105)
		verify(not player.swimming and not WorldData.in_river(player.position), "nadador sai para a margem: " + direction)
	await place(Vector2(WorldData.river_x(1000)-105,1000))
	await hold("move_right",50)
	verify(player.swimming, "entrada pela margem começa a nadar automaticamente")
	var position := player.position
	game.show_pause()
	await frames(15)
	verify(player.position.is_equal_approx(position), "pausa impede também a deriva da correnteza")
	game.close_dialog()
	player.stamina = 0.0
	position = player.position
	await hold("move_right",30)
	verify(player.position.x>position.x+15, "natação normal funciona sem fôlego para evitar prender o jogador")
	await place(Vector2(WorldData.river_x(1280),1280),true)
	var saved := game.journey_data()
	game.reset_journey()
	verify(game.apply_journey(saved) and player.swimming and not player.on_bridge, "salvamento sob a ponte restaura natação, sem teletransporte para cima")
	await place(bridge.get_center())
	saved = game.journey_data()
	game.reset_journey()
	verify(game.apply_journey(saved) and player.on_bridge and not player.swimming, "salvamento no tablado restaura a posição sobre a ponte")
	var npc: ForestNPC = game.world.npcs.tomas
	npc.active = false
	npc.position = Vector2(WorldData.river_x(1000)-115,1000)
	var hit := npc.move_and_collide(Vector2(140,0))
	verify(hit != null and hit.get_collider().name=="StreamCollision", "NPCs continuam respeitando a água e suas rotas pela ponte")
	print("SWIMMING/PHYSICS: %d verificações; %d falhas." % [checks,failures])
	quit(1 if failures else 0)
