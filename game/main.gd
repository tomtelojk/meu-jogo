class_name ForestGame
extends Node2D

const SAVE_PATH := "user://journey.json"
const CHARACTER_PATH := "user://characters/selected.png"

@onready var world: ForestWorld = $World
@onready var player: ForestPlayer = $World/Entities/Player
@onready var hud: ForestHUD = $HUD
@onready var camera: Camera2D = $World/Entities/Player/Camera2D

var collected: Dictionary = {}
var complete: bool = false
var mode: String = "intro"
var return_mode: String = "playing"
var persistence: bool = true
var save_path: String = SAVE_PATH
var custom_character: bool = false
var save_warning_shown: bool = false
var elapsed_save: float = 0.0
var elapsed_hud: float = 0.0
var victory_delay: float = 0.0
var hybrid: HybridWorld
var audio: ForestAudio
var character_dialog: FileDialog
var npc_sprite_dialog: FileDialog
var npc_sprite_target: String = ""
var met_npcs: Dictionary = {}
var royal_seals: Dictionary = {}

func _ready() -> void:
	persistence = not ("--test" in OS.get_cmdline_user_args() or "--capture" in OS.get_cmdline_user_args())
	_setup_input()
	audio = ForestAudio.new()
	audio.name = "ForestAudio"
	add_child(audio)
	player.interact_requested.connect(interact)
	hud.play_requested.connect(start_journey)
	hud.pause_requested.connect(func(): close_dialog() if mode == "dialog" else show_pause())
	hud.help_requested.connect(show_help)
	hud.map_requested.connect(show_map)
	hud.sound_requested.connect(func(): hud.set_sound(audio.toggle()))
	hud.character_requested.connect(show_characters)
	hud.dialog_closed.connect(close_dialog)
	hud.interact_requested.connect(interact)
	hud.touch_moved.connect(func(value: Vector2): player.touch_vector = value)
	if persistence:
		_load_journey()
		for id in world.npcs:
			var sprite_path := "user://npcs/" + String(id) + ".png"
			if FileAccess.file_exists(sprite_path):
				world.npcs[id].load_original_sprite(sprite_path)
	world.apply_progress(collected, complete)
	_refresh_quest()
	hud.update_status(player, world.data, world.clock)
	camera.reset_smoothing()
	if not "--test" in OS.get_cmdline_user_args() or "--hybrid" in OS.get_cmdline_user_args():
		hybrid = HybridWorld.new()
		add_child(hybrid)
		hybrid.setup(self)
	print("Entre Folhas · Godot %s · cenário e controles carregados." % Engine.get_version_info().string)

func _setup_input() -> void:
	var bindings := {
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"run": [KEY_SHIFT], "interact": [KEY_E], "map": [KEY_M], "pause": [KEY_ESCAPE],
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			if not InputMap.action_has_event(action, event):
				InputMap.action_add_event(action, event)

func start_journey() -> void:
	mode = "playing"
	player.active = true
	world.set_population_active(true)
	hud.show_game()
	hud.close_dialog()
	save_journey()

func _process(delta: float) -> void:
	if mode != "playing":
		return
	elapsed_hud += delta
	elapsed_save += delta
	if elapsed_hud > 0.08:
		elapsed_hud = 0.0
		hud.update_status(player, world.data, world.clock)
		var item := current_interaction()
		var label := ""
		if not item.is_empty():
			label = _interaction_label(item)
		hud.show_interaction(label, hybrid.screen_position(player.position) if hybrid != null else get_viewport().get_canvas_transform() * player.global_position)
	if elapsed_save > 2.0:
		elapsed_save = 0.0
		save_journey()
	if victory_delay > 0:
		victory_delay -= delta
		if victory_delay <= 0:
			_show_victory()

func current_interaction() -> Dictionary:
	var nearest: Dictionary = {}
	var nearest_distance := INF
	for area in player.sensor.get_overlapping_areas():
		if not area.has_meta("interaction"):
			continue
		var item: Dictionary = area.get_meta("interaction")
		if item.kind == "seed" and collected.has(item.id):
			continue
		if item.kind == "npc" and world.npcs[item.id].sleeping:
			continue
		var distance := player.global_position.distance_to(area.global_position)
		var range_limit: float = item.get("range", 65.0 if item.kind == "npc" else 63.0)
		if distance > range_limit + 1.0:
			continue
		if item.kind == "seed":
			distance -= 24.0
		if distance < nearest_distance:
			nearest = item
			nearest_distance = distance
	return nearest

func _interaction_label(item: Dictionary) -> String:
	if item.kind == "seed":
		return "Recolher semente"
	if item.kind == "npc":
		return "Conversar com " + String(item.name)
	if item.id == "mother":
		return "Plantar as cinco sementes" if collected.size() == 5 and not complete else "Escutar a árvore-mãe"
	return "Ler o caderno" if item.id == "camp" else "Ler a placa"

func interact() -> void:
	if mode != "playing":
		return
	var item := current_interaction()
	if item.is_empty():
		return
	if item.kind == "seed":
		collected[item.id] = true
		world.seeds[item.id].gather()
		world.burst(item.position + Vector2(0, -20))
		audio.chime()
		_refresh_quest()
		hud.toast("As cinco sementes estão com você. Volte à árvore-mãe!" if collected.size() == 5 else "%s encontrada · %d de 5" % [item.name, collected.size()])
		save_journey()
	elif item.id == "mother" and collected.size() == 5 and not complete:
		complete = true
		world.apply_progress(collected, true)
		world.burst(WorldData.MOTHER + Vector2(0, -65), 100)
		audio.chime(true)
		_refresh_quest()
		hud.toast("As raízes despertam. A primavera está de volta.")
		victory_delay = 1.2
		save_journey()
	elif item.kind == "npc":
		open_npc(item.id)
	else:
		var body: String = item.text
		if item.id == "mother" and complete:
			body = "Cinco sementes, uma nova primavera. As raízes estão vivas e os galhos dançam com o vento. Você pode ficar e explorar por quanto tempo quiser."
		var actions: Array[Dictionary] = [{"label": "Continuar explorando", "callback": close_dialog}]
		if item.id == "camp":
			actions.push_front({"label": "Descansar até a próxima manhã", "callback": rest_until_morning})
		_open_dialog("AS HISTÓRIAS DO BOSQUE", item.name, body, actions)

func peace_achieved() -> bool:
	return complete and royal_seals.has("aurelia") and royal_seals.has("valverde")

func _refresh_quest() -> void:
	hud.update_quest(collected, complete, peace_achieved())

func open_npc(id: String, topic: String = "greeting") -> void:
	if not world.npcs.has(id):
		return
	var npc: ForestNPC = world.npcs[id]
	if npc.sleeping:
		hud.toast("%s está descansando. Volte pela manhã." % npc.definition.name)
		return
	var profile: Dictionary = npc.definition
	var known := met_npcs.has(id)
	met_npcs[id] = true
	npc.face(player.position)
	var body: String = profile.greeting
	if topic == "greeting":
		body = ("Bom te ver de novo, viajante.\n\n" if known else "") + body
	elif topic == "realm":
		body = profile.realm_text + "\n\n" + profile.other_text
	elif topic == "routine":
		body = "Agora: %s.\n\n%s" % [npc.activity(), KingdomData.routine_text(profile)]
	elif topic == "hint":
		body = "Você conseguiu! O bosque voltou a respirar. Agora podemos pensar no futuro dos dois reinos." if complete else String(profile.hint)
	elif topic == "peace":
		if id in ["aurel", "caio"]:
			royal_seals[profile.realm] = true
			if peace_achieved():
				body = "O bosque renasceu e os dois reis deram sua palavra. Renovamos o Acordo das Raízes: a ponte continuará aberta e os dois povos cuidarão juntos da floresta. Você tem nossa gratidão."
			elif royal_seals.size() == 2:
				body = "Você tem a palavra dos dois reis. Aurélia e Valverde vão cooperar. Resta devolver as cinco sementes à árvore-mãe para que nosso acordo crie raízes de verdade."
			else:
				var other := "Caio, em Valverde" if id == "aurel" else "Aurel, em Aurélia"
				body = "Dou minha palavra: quero renovar a aliança e proteger o bosque. Leve essa mensagem ao rei %s. Uma ponte aberta e uma floresta viva valem mais que uma disputa." % other
		else:
			body = profile.other_text + "\n\nFale com os dois reis sobre cooperação. A árvore-mãe pode ser o começo de um novo acordo."
	_refresh_quest()
	save_journey()
	var actions: Array[Dictionary] = []
	if topic == "greeting":
		actions = [
			{"label": "Sobre os dois reinos", "callback": open_npc.bind(id, "realm")},
			{"label": "Como é sua rotina?", "callback": open_npc.bind(id, "routine")},
			{"label": "Tem algum conselho para mim?", "callback": open_npc.bind(id, "hint")},
			{"label": "Podemos unir os dois reinos?", "callback": open_npc.bind(id, "peace")},
			{"label": "Escolher sprite deste morador", "callback": _open_npc_sprite.bind(id)},
			{"label": "Até logo", "callback": close_dialog},
		]
	else:
		actions = [{"label": "Perguntar outra coisa", "callback": open_npc.bind(id, "greeting")}, {"label": "Até logo", "callback": close_dialog}]
	_open_dialog(String(KingdomData.REALMS[profile.realm].name).to_upper(), "%s · %s" % [profile.name, profile.role], body, actions, "npc")

func rest_until_morning() -> void:
	world.clock.set_time(7.0, world.clock.day + 1)
	for npc in world.npcs.values():
		npc.apply_schedule(world.clock.minute, true)
	close_dialog()
	save_journey()
	hud.toast("Uma nova manhã. Os moradores começam mais um dia.")

func _open_npc_sprite(id: String) -> void:
	npc_sprite_target = id
	if npc_sprite_dialog == null:
		npc_sprite_dialog = FileDialog.new()
		npc_sprite_dialog.title = "Escolher prancha original do morador"
		npc_sprite_dialog.access = FileDialog.ACCESS_FILESYSTEM
		npc_sprite_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		npc_sprite_dialog.filters = PackedStringArray(["*.png ; Prancha de personagem PNG"])
		npc_sprite_dialog.file_selected.connect(import_npc_sprite)
		hud.add_child(npc_sprite_dialog)
	npc_sprite_dialog.popup_centered_ratio(0.7)

func import_npc_sprite(path: String) -> bool:
	if not world.npcs.has(npc_sprite_target) or not world.npcs[npc_sprite_target].load_original_sprite(path):
		hud.toast("Escolha uma prancha PNG de até 12 MB, com 5 colunas e 8 linhas.")
		return false
	if persistence:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://npcs"))
		var destination := ProjectSettings.globalize_path("user://npcs/" + npc_sprite_target + ".png")
		if path != destination and DirAccess.copy_absolute(path, destination) != OK:
			hud.toast("Sprite disponível nesta sessão; não foi possível guardar a imagem.")
		else:
			hud.toast("A aparência do morador foi atualizada.")
	close_dialog()
	return true

func _open_dialog(eyebrow: String, title: String, body: String, actions: Array[Dictionary], kind: String = "dialog", map_view: ForestMinimap = null) -> void:
	if mode != "dialog":
		return_mode = mode
	mode = "dialog"
	player.active = false
	world.set_population_active(false)
	player.touch_vector = Vector2.ZERO
	hud.show_dialog(eyebrow, title, body, actions, kind, map_view)

func close_dialog() -> void:
	if mode != "dialog":
		return
	hud.close_dialog()
	mode = return_mode
	player.active = mode == "playing"
	world.set_population_active(mode == "playing")

func show_pause() -> void:
	if mode != "playing":
		return
	save_journey()
	_open_dialog("UMA PEQUENA PAUSA", "O bosque espera por você.", "Não é preciso ter pressa. Sua jornada é salva automaticamente neste dispositivo.", [
		{"label": "Continuar a jornada", "callback": close_dialog},
		{"label": "Escolher personagem", "callback": show_characters},
		{"label": "Como jogar", "callback": show_help},
		{"label": "Começar de novo", "callback": confirm_reset},
	], "pause")

func show_help() -> void:
	_open_dialog("SEU GUIA DO BOSQUE", "Siga a sua curiosidade.", "Encontre cinco sementes douradas e leve-as à árvore-mãe. Os pontos dourados no mapa mostram onde procurar.\n\nWASD ou setas · Caminhar\nShift · Correr\nE · Recolher, ler e plantar\nM · Abrir e fechar o mapa\nEsc · Pausar e voltar\n\nNo celular, use o controle à esquerda e o botão à direita. O riacho pode ser atravessado pela ponte de madeira.", [{"label": "Entendi, vamos explorar", "callback": close_dialog}], "help")

func show_map() -> void:
	if mode == "dialog" and hud.modal_kind == "map":
		close_dialog()
		return
	var map_view := ForestMinimap.new()
	map_view.world_data = world.data
	map_view.collected = collected
	map_view.player_position = player.position
	map_view.restored = complete
	_open_dialog("CADA CAMINHO, UMA DESCOBERTA", "Bosque do vento", "Pontos dourados · Sementes\nCírculo claro · Árvore-mãe\nPonto branco · Você", [{"label": "Voltar ao caminho", "callback": close_dialog}], "map", map_view)

func confirm_reset() -> void:
	_open_dialog("UMA NOVA JORNADA", "Voltar ao primeiro passo?", "As sementes e a posição desta jornada serão reiniciadas. O bosque estará esperando por uma nova aventura.", [
		{"label": "Manter minha jornada", "callback": close_dialog},
		{"label": "Sim, começar de novo", "callback": reset_journey},
	], "reset")

func reset_journey() -> void:
	collected.clear()
	met_npcs.clear()
	royal_seals.clear()
	world.reset_population()
	complete = false
	victory_delay = 0.0
	player.position = WorldData.SPAWN
	player.stamina = 1.0
	player.touch_vector = Vector2.ZERO
	world.apply_progress(collected, false)
	_refresh_quest()
	camera.reset_smoothing()
	start_journey()
	if hybrid != null:
		hybrid.snap_camera()
	hud.toast("Uma nova jornada. Que o vento guie seus passos.")

func _show_victory() -> void:
	_open_dialog("CAPÍTULO 01 · CONCLUÍDO", "Você plantou um novo começo.", "As cinco sementes encontraram seu lar. A árvore-mãe voltou a florescer, e o vento já leva histórias de uma nova primavera.\n\nÀs vezes, cuidar de uma pequena coisa muda um mundo inteiro.\n\n❧ Obrigado por caminhar entre folhas.", [
		{"label": "Ficar mais um pouco", "callback": close_dialog},
		{"label": "Começar uma nova jornada", "callback": confirm_reset},
	], "victory")

func show_characters() -> void:
	_open_dialog("QUEM SEGUE O VENTO?", "Toda jornada tem um rosto.", "O agricultor do pacote já está pronto para explorar nas quatro direções. Você também pode importar uma prancha PNG de 5 colunas e 8 linhas. A imagem escolhida fica apenas neste dispositivo.", [
		{"label": "Importar prancha PNG", "callback": _open_character_file},
		{"label": "Usar agricultor do pacote", "callback": _use_default_character},
		{"label": "Voltar à jornada", "callback": close_dialog},
	], "characters")

func _open_character_file() -> void:
	if character_dialog == null:
		character_dialog = FileDialog.new()
		character_dialog.title = "Escolher prancha de personagem"
		character_dialog.access = FileDialog.ACCESS_FILESYSTEM
		character_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		character_dialog.filters = PackedStringArray(["*.png ; Prancha de personagem PNG"])
		character_dialog.file_selected.connect(import_character)
		hud.add_child(character_dialog)
	character_dialog.popup_centered_ratio(0.7)

func import_character(path: String) -> bool:
	if not player.load_character_file(path):
		hud.toast("Use uma prancha PNG de até 12 MB, com 5 colunas e 8 linhas.", 6.0)
		return false
	custom_character = true
	if persistence:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://characters"))
		var target := ProjectSettings.globalize_path(CHARACTER_PATH)
		if path != target and DirAccess.copy_absolute(path, target) != OK:
			hud.toast("Personagem disponível nesta sessão. Não foi possível guardar a imagem.", 6.0)
		else:
			hud.toast("Seu personagem está pronto para explorar.")
	save_journey()
	hud.update_status(player, world.data, world.clock)
	close_dialog()
	return true

func _use_default_character() -> void:
	custom_character = false
	player.use_default_character()
	hud.update_status(player, world.data, world.clock)
	save_journey()
	close_dialog()

func journey_data() -> Dictionary:
	return {"version": 1, "x": player.position.x, "y": player.position.y, "seeds": collected.keys(), "complete": complete, "custom_character": custom_character, "clock": world.clock.save_data(), "npcs": world.population_data(), "met_npcs": met_npcs.keys(), "royal_seals": royal_seals.keys()}

func apply_journey(data: Dictionary) -> bool:
	if data.get("version") != 1 or not data.get("seeds") is Array:
		return false
	collected.clear()
	for id in data.seeds:
		for seed_data in WorldData.SEEDS:
			if id == seed_data.id:
				collected[id] = true
	complete = data.get("complete") == true and collected.size() == 5
	player.position = WorldData.SPAWN
	var x = data.get("x")
	var y = data.get("y")
	if (x is float or x is int) and (y is float or y is int):
		var point := Vector2(x, y)
		if is_finite(point.x) and is_finite(point.y) and WorldData.can_stand(point, world.data):
			player.position = point
	custom_character = data.get("custom_character") == true
	met_npcs.clear()
	royal_seals.clear()
	var saved_met = data.get("met_npcs", [])
	if saved_met is Array:
		for id in saved_met:
			if id is String and world.npcs.has(id):
				met_npcs[id] = true
	var saved_seals = data.get("royal_seals", [])
	if saved_seals is Array:
		for realm in saved_seals:
			if realm in ["aurelia", "valverde"]:
				royal_seals[realm] = true
	var saved_clock = data.get("clock", {})
	world.clock.restore(saved_clock if saved_clock is Dictionary else {})
	for npc in world.npcs.values():
		npc.apply_schedule(world.clock.minute, true)
	var saved_population = data.get("npcs", {})
	if saved_population is Dictionary:
		world.restore_population(saved_population)
	if custom_character and persistence:
		custom_character = player.load_character_file(CHARACTER_PATH)
	return true

func _load_journey() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if parsed is Dictionary and apply_journey(parsed):
		hud.set_started(true)

func save_journey() -> void:
	if not persistence:
		return
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		if not save_warning_shown:
			save_warning_shown = true
			hud.toast("Não foi possível salvar neste dispositivo. A jornada continua nesta sessão.", 6.0)
		return
	file.store_string(JSON.stringify(journey_data()))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("pause"):
		close_dialog() if mode == "dialog" else show_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("map") and (mode == "playing" or (mode == "dialog" and hud.modal_kind == "map")):
		show_map()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		player.touch_vector = Vector2.ZERO
		if mode == "playing":
			show_pause()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		if mode != "intro":
			save_journey()
