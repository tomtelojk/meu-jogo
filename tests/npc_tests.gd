class_name NPCTests
extends RefCounted

static func run(runner, game: ForestGame) -> void:
	game.reset_journey()
	var world := game.world
	var clock := world.clock
	runner.verify(world.npcs.size() == 8 and KingdomData.REALMS.size() == 2, "oito NPCs vivem em dois reinos")
	var signatures: Dictionary = {}
	for profile in KingdomData.PEOPLE:
		signatures[JSON.stringify(profile.routine)] = true
		runner.verify(profile.routine.size() >= 5 and KingdomData.REALMS.has(profile.realm), "rotina diária e reino definidos: " + profile.name)
	runner.verify(signatures.size() == 8, "cada NPC possui uma rotina diferente")
	var helper: ForestNPC = world.npcs.bento
	var start_cell: Vector2i = helper._nearest_cell(WorldData.SPAWN)
	for key in KingdomData.PLACES:
		var point := KingdomData.point(key)
		var goal_cell := helper._nearest_cell(point)
		var path := world.navigator.get_point_path(start_cell, goal_cell)
		runner.verify(not path.is_empty() and WorldData.can_stand(point, world.data), "destino da rotina é acessível: " + String(key))
	clock.set_time(10.0)
	clock.active = false
	var merchant: ForestNPC = world.npcs.lia
	var guard: ForestNPC = world.npcs.tomas
	var merchant_start := merchant.position
	var guard_start := guard.position
	await runner.frames(180)
	runner.verify(merchant.position.distance_to(merchant_start) > 40 and merchant.current_schedule.activity.contains("mercadorias"), "comerciante se desloca entre os mercados")
	runner.verify(guard.position.distance_to(guard_start) > 20 and guard.current_schedule.get("loop", false), "guarda percorre sua patrulha própria")
	runner.verify(WorldData.can_stand(merchant.position, world.data, 8) and WorldData.can_stand(guard.position, world.data, 8), "NPCs se movem sem entrar no rio ou em obstáculos")
	runner.verify(KingdomData.schedule(KingdomData.person("bento"), 15 * 60).points[0] == "forge" and KingdomData.schedule(KingdomData.person("bento"), 19 * 60).points[0] == "west_tavern", "ferreiro alterna trabalho e convivência ao anoitecer")
	clock.set_time(23.0)
	for npc in world.npcs.values():
		npc.apply_schedule(clock.minute, true)
	await runner.frames(4)
	var resting := 0
	for npc in world.npcs.values():
		if npc.sleeping and not npc.visible and not npc.interaction_area.monitorable:
			resting += 1
	runner.verify(resting == 8, "à noite, moradores descansam em suas casas e não iniciam diálogos")
	runner.verify(world.daylight.color.r < 0.6, "a luz acompanha o ciclo noturno")
	clock.set_time(6.0)
	for npc in world.npcs.values():
		npc.apply_schedule(clock.minute, true)
	var awake := 0
	for npc in world.npcs.values():
		if not npc.sleeping:
			awake += 1
	runner.verify(awake == 5, "moradores acordam em horários diferentes")
	clock.set_time(23.99, 3)
	clock.advance(2.0)
	runner.verify(clock.day == 4 and clock.minute < 3 and clock.phase() == "Noite", "relógio atravessa a meia-noite e avança o dia")
	clock.set_time(10.0, 4)
	for npc in world.npcs.values():
		npc.apply_schedule(clock.minute, true)
	game.collected.outono = true
	world.apply_progress(game.collected, false)
	game.player.position = world.npcs.bento.position + Vector2(0, 45)
	world.set_population_active(true)
	await runner.frames(4)
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.physical_keycode = KEY_E
	event.pressed = true
	Input.parse_input_event(event)
	await runner.frames(2)
	var release: InputEventKey = event.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	await runner.settle_ui()
	runner.verify(game.mode == "dialog" and game.hud.modal_kind == "npc" and game.met_npcs.has("bento"), "E inicia conversa com o NPC próximo e registra o encontro")
	runner.verify(game.hud.modal_panel.position.y >= 0 and game.hud.modal_panel.size.y <= 800, "opções de conversa cabem na interface")
	var stopped_minute := clock.minute
	var stopped_guard := guard.position
	await runner.frames(15)
	runner.verify(clock.minute == stopped_minute and guard.position == stopped_guard, "conversas pausam o relógio e as rotinas")
	game.open_npc("bento", "routine")
	var labels := game.hud.modal.find_children("*", "Label", true, false)
	var mentions_routine := false
	for label in labels:
		if label.text.contains("07:00") and label.text.contains("forja"):
			mentions_routine = true
	runner.verify(mentions_routine, "NPC descreve sua atividade atual e seus horários no diálogo")
	for profile in KingdomData.PEOPLE:
		game.open_npc(profile.id, "realm")
		runner.verify(game.hud.modal_kind == "npc" and game.met_npcs.has(profile.id), "diálogo próprio sobre os reinos: " + profile.name)
	game.complete = false
	game.open_npc("aurel", "peace")
	runner.verify(game.royal_seals.has("aurelia") and not game.peace_achieved(), "primeiro rei oferece sua palavra sem concluir a aliança")
	game.open_npc("caio", "peace")
	runner.verify(game.royal_seals.size() == 2 and not game.peace_achieved(), "duas palavras ainda exigem a restauração do bosque")
	for item in WorldData.SEEDS:
		game.collected[item.id] = true
	game.complete = true
	game.open_npc("caio", "peace")
	runner.verify(game.peace_achieved() and game.hud.quest_note.text.contains("unidos"), "os dois reis e o bosque restaurado concluem o acordo")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(game.journey_data()))
	var saved_minute := clock.minute
	game.royal_seals.clear()
	game.met_npcs.clear()
	clock.set_time(18.0)
	runner.verify(game.apply_journey(saved) and game.peace_achieved() and game.met_npcs.size() == 8 and is_equal_approx(clock.minute, saved_minute), "salvamento preserva horários, encontros e acordo dos reinos")
	var fixture := Image.create(500, 800, false, Image.FORMAT_RGBA8)
	fixture.fill(Color(0.4, 0.6, 0.3))
	var path := "/tmp/entre-folhas-npc-test.png"
	fixture.save_png(path)
	game.npc_sprite_target = "bento"
	runner.verify(game.import_npc_sprite(path) and world.npcs.bento.custom_sprite, "prancha original pode ser aplicada individualmente ao NPC")
	var atlas: AtlasTexture = world.npcs.bento.sprite.sprite_frames.get_frame_texture("run_left", 0)
	runner.verify(atlas.region == Rect2(100, 700, 100, 100), "sprite de NPC usa a linha de corrida na direção correta, sem espelhamento")
	DirAccess.remove_absolute(path)
	game.close_dialog()
	game._open_dialog("TESTE", "Acampamento", "Descansar", [])
	var previous_day := clock.day
	game.rest_until_morning()
	runner.verify(clock.day == previous_day + 1 and is_equal_approx(clock.minute, 420.0) and game.mode == "playing", "descansar no acampamento avança até a manhã seguinte")
	game.reset_journey()
	runner.verify(game.met_npcs.is_empty() and game.royal_seals.is_empty() and clock.day == 1 and is_equal_approx(clock.minute, 510.0), "nova jornada reinicia encontros, acordo e relógio")
