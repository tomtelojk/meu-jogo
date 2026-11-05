extends SceneTree

var failures: int = 0
var checks: int = 0
var game: ForestGame
var watchdog: Timer

func _initialize() -> void:
	watchdog = Timer.new()
	watchdog.wait_time = 60.0
	watchdog.one_shot = true
	watchdog.autostart = true
	root.add_child(watchdog)
	watchdog.timeout.connect(_timeout)
	call_deferred("_run")

func _timeout() -> void:
	push_error("O teste excedeu 60 segundos sem concluir.")
	quit(1)

func verify(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)
	else:
		print("PASS: " + label)

func frames(count: int = 3) -> void:
	for i in count:
		await physics_frame
		# physics_frame is emitted before simulation. Let transforms, Area2D
		# overlaps and queued input settle before inspecting the resulting state.
		await process_frame

func settle_ui() -> void:
	for i in 3:
		await process_frame

func _run() -> void:
	root.size = Vector2i(1280, 800)
	var scene: PackedScene = load("res://scenes/main.tscn")
	game = scene.instantiate()
	root.add_child(game)
	game.persistence = false
	await frames()
	verify(game.world.get_node("GrassTiles") is TileMapLayer, "o chão usa TileMapLayer nativo")
	verify(game.player is CharacterBody2D and game.camera is Camera2D, "personagem e câmera usam nós nativos")
	verify(game.world.trees.size() > 300 and game.world.seeds.size() == 5, "cenário e cinco sementes foram criados")
	preload("res://tests/tree_atlas_tests.gd").run(self, game.world)
	preload("res://tests/terrain_tests.gd").run(self, game.world)
	preload("res://tests/bundled_npc_tests.gd").run(self, game.world)
	preload("res://tests/tomate_assets_tests.gd").run(self, game.world)
	_test_reachability()
	game.start_journey()
	await frames()
	await settle_ui()
	verify(game.hud.quest.size.y < 300 and game.hud.stamina.size.y <= 8, "painel de missão e barra de fôlego mantêm tamanho compacto")
	var start := game.player.position
	var walk_tick := Engine.get_physics_frames()
	Input.action_press("move_up")
	await frames(16)
	Input.action_release("move_up")
	var walk_ticks := maxi(1, Engine.get_physics_frames() - walk_tick)
	var walk_distance := start.distance_to(game.player.position)
	await frames()
	verify(walk_distance > 25 and game.player.position.y < start.y, "WASD movimenta o CharacterBody2D pela física")
	game.player.position = start
	var run_tick := Engine.get_physics_frames()
	Input.action_press("move_down")
	Input.action_press("run")
	await frames(16)
	Input.action_release("move_down")
	Input.action_release("run")
	var run_ticks := maxi(1, Engine.get_physics_frames() - run_tick)
	var run_distance := start.distance_to(game.player.position)
	await frames()
	verify(run_distance / run_ticks > walk_distance / walk_ticks * 1.4 and game.player.stamina < 1, "corrida aumenta a velocidade e consome fôlego")
	game.show_pause()
	start = game.player.position
	Input.action_press("move_up")
	await frames(10)
	Input.action_release("move_up")
	verify(game.player.position == start and game.mode == "dialog", "pausa bloqueia o movimento")
	game.close_dialog()
	game.show_map()
	verify(game.hud.modal_kind == "map", "mapa ampliado abre no HUD nativo")
	await settle_ui()
	verify(game.hud.modal_panel.size.y > 500, "mapa ampliado preserva altura e proporção")
	game.show_map()
	verify(game.mode == "playing", "atalho de mapa também fecha o mapa")
	game.player.position = WorldData.MOTHER + Vector2(0, 85)
	await frames()
	Input.action_press("move_up")
	Input.action_press("run")
	await frames(45)
	Input.action_release("move_up")
	Input.action_release("run")
	verify(game.player.position.y >= WorldData.MOTHER.y + 35, "tronco bloqueia o personagem com colisão real")
	game.player.position = Vector2(WorldData.river_x(16 * WorldData.TILE) - 115, 16 * WorldData.TILE)
	await frames()
	Input.action_press("move_right")
	await frames(45)
	Input.action_release("move_right")
	verify(game.player.position.x < WorldData.river_x(game.player.position.y) - 85, "o rio impede a travessia fora da ponte")
	game.player.position = Vector2(35.8 * WorldData.TILE, 20 * WorldData.TILE)
	await frames()
	Input.action_press("move_right")
	Input.action_press("run")
	await frames(112)
	Input.action_release("move_right")
	Input.action_release("run")
	verify(game.player.position.x > WorldData.river_x(game.player.position.y) + 90, "a ponte permite atravessar o rio pela física")
	for seed_data in WorldData.SEEDS:
		game.player.position = seed_data.position + Vector2(0, 30)
		await frames(4)
		verify(game.current_interaction().get("id") == seed_data.id, "Area2D detecta " + seed_data.name)
		var count := game.collected.size()
		var event := InputEventKey.new()
		event.physical_keycode = KEY_E
		event.keycode = KEY_E
		event.pressed = true
		Input.parse_input_event(event)
		await frames(1)
		var release: InputEventKey = event.duplicate()
		release.pressed = false
		Input.parse_input_event(release)
		game.interact()
		verify(game.collected.size() == count + 1 and not game.world.seeds[seed_data.id].visible, "semente é recolhida uma única vez: " + seed_data.id)
		# A second interaction can now open a nearby villager's conversation.
		if game.mode == "dialog":
			game.close_dialog()
	game.player.position = WorldData.MOTHER + Vector2(0, 60)
	await frames(4)
	game.interact()
	verify(game.complete and is_equal_approx(game.world.mother_material.get_shader_parameter("vitality"), 1.0), "plantar as cinco sementes restaura a vitalidade da árvore-mãe")
	await create_timer(1.4).timeout
	verify(game.hud.modal_kind == "victory", "conclusão mostra o diálogo de vitória")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(game.journey_data()))
	game.close_dialog()
	game.reset_journey()
	verify(game.collected.is_empty() and not game.complete and game.player.position == WorldData.SPAWN, "reinício restaura objetivos e posição")
	verify(game.apply_journey(saved) and game.complete and game.collected.size() == 5, "progresso e vitória sobrevivem à serialização")
	game.save_path = "/tmp/entre-folhas-godot-test-save.json"
	game.persistence = true
	game.save_journey()
	verify(FileAccess.file_exists(game.save_path), "salvamento grava um arquivo real no disco")
	game.collected.clear()
	game.complete = false
	game._load_journey()
	verify(game.complete and game.collected.size() == 5, "salvamento gravado recupera as cinco sementes e a vitória")
	DirAccess.remove_absolute(game.save_path)
	game.persistence = false
	game.save_path = ForestGame.SAVE_PATH
	verify(not game.apply_journey({"version": 99, "seeds": []}), "salvamento de versão desconhecida é rejeitado")
	game.apply_journey({"version": 1, "seeds": ["flores", "flores", "inexistente"], "x": -999, "y": 10, "complete": true})
	verify(game.collected.size() == 1 and not game.complete and game.player.position == WorldData.SPAWN, "salvamento inválido recupera posição e filtra sementes")
	_test_character_import()
	await preload("res://tests/npc_animation_tests.gd").run(self, game)
	await NPCTests.run(self, game)
	game.reset_journey()
	root.size = Vector2i(390, 844)
	await frames(6)
	game.hud._layout()
	verify(game.hud.touch_controls.visible, "janela estreita oferece controles de toque")
	verify(game.hud.quest.size.y < 300 and game.hud.quest.position.x + game.hud.quest.size.x <= 390, "painel de missão cabe na janela estreita")
	var joystick := game.hud.joystick
	var center := joystick.global_position + joystick.size / 2.0
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = center
	Input.parse_input_event(touch)
	await frames()
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = center + Vector2(0, -30)
	Input.parse_input_event(drag)
	start = game.player.position
	await frames(18)
	var touch_release: InputEventScreenTouch = touch.duplicate()
	touch_release.pressed = false
	Input.parse_input_event(touch_release)
	await frames()
	verify(game.player.position.y < start.y - 20 and game.player.touch_vector == Vector2.ZERO, "arrastar e soltar o controle de toque move e para o personagem")
	var sound_enabled := game.audio.toggle()
	await create_timer(0.15).timeout
	var sound_disabled := not game.audio.toggle()
	await create_timer(0.15).timeout
	verify(sound_enabled and sound_disabled, "som sintetizado pode ser ativado e desativado")
	print("\nRESULTADO: %d verificações; %d falhas." % [checks, failures])
	game.queue_free()
	watchdog.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func _test_character_import() -> void:
	var fixture := Image.create(500, 800, false, Image.FORMAT_RGBA8)
	fixture.fill(Color.TRANSPARENT)
	for row in 8:
		for col in 5:
			fixture.fill_rect(Rect2i(col * 100 + 30, row * 100 + 15, 40, 80), Color.from_hsv(row / 8.0, 0.6, 0.4 + col * 0.1))
	var path := "/tmp/entre-folhas-test-character.png"
	verify(fixture.save_png(path) == OK and game.import_character(path), "prancha PNG pode ser importada nativamente")
	var library := game.player.sprite.sprite_frames
	var atlas: AtlasTexture = library.get_frame_texture("run_left", 0)
	verify(atlas.region == Rect2(100, 700, 100, 100), "corrida para a esquerda usa a oitava linha sem espelhamento")
	verify(library.get_frame_count("walk_up") == 4 and library.get_frame_count("idle_up") == 1, "animações usam quatro quadros de movimento e um parado")
	game.player.use_default_character()
	DirAccess.remove_absolute(path)

func _test_reachability() -> void:
	var step := 16
	var cols := int(WorldData.SIZE.x) / step
	var rows := int(WorldData.SIZE.y) / step
	var passable := PackedByteArray()
	var visited := PackedByteArray()
	passable.resize(cols * rows)
	visited.resize(cols * rows)
	for y in rows:
		for x in cols:
			passable[y * cols + x] = 1 if WorldData.can_stand(Vector2(x, y) * step, game.world.data) else 0
	var start := roundi(WorldData.SPAWN.y / step) * cols + roundi(WorldData.SPAWN.x / step)
	var queue := PackedInt32Array([start])
	visited[start] = 1
	var cursor := 0
	while cursor < queue.size():
		var index := queue[cursor]
		cursor += 1
		var x := index % cols
		var y := index / cols
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = x + offset.x
			var ny: int = y + offset.y
			if nx < 0 or ny < 0 or nx >= cols or ny >= rows:
				continue
			var next: int = ny * cols + nx
			if passable[next] and not visited[next]:
				visited[next] = 1
				queue.append(next)
	for spot in WorldData.SEEDS + WorldData.LANDMARKS:
		var reachable := false
		for index in queue:
			if Vector2(index % cols, index / cols).distance_to(spot.position / step) < (5.5 if spot.id == "mother" else 3.4):
				reachable = true
				break
		verify(reachable, "objetivo alcançável a partir do início: " + spot.name)
