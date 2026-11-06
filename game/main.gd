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
var light_graphics := true
var shaders_enabled := true
var map_editor: WorldEditor
var map_snapshots: Dictionary = {}
var audio: ForestAudio
var character_dialog: FileDialog
var npc_sprite_dialog: FileDialog
var npc_sprite_target: String = ""
var met_npcs: Dictionary = {}
var royal_seals: Dictionary = {}
var rpg := RPGState.new()
var economy:OpenEconomy
var building_preview:=false
var building_point:=Vector2.ZERO
var action_delay:=0.0
var damage_flash:=0.0

func _enter_tree() -> void:
	persistence=not ("--test" in OS.get_cmdline_user_args() or "--capture" in OS.get_cmdline_user_args())
	if persistence:
		var result:=MapDocument.read_file(MapDocument.ACTIVE_PATH)
		MapDocument.activate(result.document if result.ok else MapDocument.original())
	save_path=_map_save_path()

func _map_save_path() -> String:
	return SAVE_PATH if MapDocument.current.id=="reinos" else "user://maps/"+MapDocument.current.id+".journey.json"

func _ready() -> void:
	persistence = not ("--test" in OS.get_cmdline_user_args() or "--capture" in OS.get_cmdline_user_args())
	_setup_input()
	audio = ForestAudio.new()
	audio.name = "WorldAudio"
	add_child(audio)
	player.interact_requested.connect(interact)
	hud.play_requested.connect(start_journey)
	hud.pause_requested.connect(func(): close_dialog() if mode == "dialog" else show_pause())
	hud.help_requested.connect(show_help)
	hud.map_requested.connect(show_map)
	hud.sound_requested.connect(func(): hud.set_sound(audio.toggle()))
	hud.character_requested.connect(show_characters)
	hud.editor_requested.connect(show_map_editor)
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
	camera.limit_right=int(WorldData.SIZE.x)
	camera.limit_bottom=int(WorldData.SIZE.y)
	world.ensure_region(player.position,true)
	world.refresh_rpg()
	rpg.changed.connect(_refresh_quest)
	economy=OpenEconomy.new()
	add_child(economy)
	economy.setup(self)
	camera.reset_smoothing()
	if not "--test" in OS.get_cmdline_user_args() or "--hybrid" in OS.get_cmdline_user_args():
		hybrid = HybridWorld.new()
		add_child(hybrid)
		hybrid.setup(self)
	print("Entre Reinos · Godot %s · cenário e controles carregados." % Engine.get_version_info().string)
	if MapDocument.current.id!="reinos" and not FileAccess.file_exists(save_path):
		player.position=MapDocument.spawn_point()
		world.ensure_region(player.position,true)
		if hybrid!=null:hybrid.snap_camera()

func _setup_input() -> void:
	var bindings := {
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"run": [KEY_SHIFT], "interact": [KEY_E], "map": [KEY_M], "pause": [KEY_ESCAPE],
		"inventory":[KEY_I],"journal":[KEY_J],"build":[KEY_B],"attack":[KEY_SPACE],"editor":[KEY_F2],
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
	action_delay=maxf(0,action_delay-delta)
	damage_flash=maxf(0,damage_flash-delta)
	player.sprite.modulate=Color(1.0,0.65,0.5) if damage_flash>0 else Color.WHITE
	if mode != "playing":
		return
	elapsed_hud += delta
	elapsed_save += delta
	if elapsed_hud > 0.18:
		elapsed_hud = 0.0
		hud.update_status(player, world.data, world.clock)
		hud.update_rpg(rpg)
		for town in KingdomData.towns():
			if player.position.distance_to(town.position)<1400 and rpg.discover(town.id):hud.toast("Você descobriu "+town.name+" · +25 XP")
		var item := current_interaction()
		var label := ""
		if not item.is_empty():
			label = _interaction_label(item)
		hud.show_interaction(label, hybrid.screen_position(player.position) if hybrid != null else get_viewport().get_canvas_transform() * player.global_position)
	if elapsed_save > 2.0:
		elapsed_save = 0.0
		save_journey()
	if building_preview:_update_build_preview()
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
		if item.kind=="resource" and rpg.depleted.has(item.id):continue
		if item.kind=="animal" and (not world.animals.has(item.id) or not world.animals[item.id].alive):continue
		if item.kind == "npc" and world.npcs[item.id].sleeping:
			continue
		var distance := player.global_position.distance_to(area.global_position)
		var range_limit: float = item.get("range", 65.0 if item.kind == "npc" else 63.0)
		if distance > range_limit + 1.0:
			continue
		if item.kind in ["shop","inn","house"]:distance-=40.0
		elif item.kind == "seed":distance-=24.0
		elif item.kind=="resource":distance+=12.0
		if distance < nearest_distance:
			nearest = item
			nearest_distance = distance
	return nearest

func _interaction_label(item: Dictionary) -> String:
	if item.kind=="shop":return "Negociar na ferraria"
	if item.kind=="inn":return "Estalagem e caravanas"
	if item.kind=="house":return item.name
	if item.kind=="resource":return "Cortar madeira" if item.resource_kind=="wood" else "Extrair pedra"
	if item.kind=="animal":return "Ajudar na fazenda · "+item.name
	if item.kind == "seed":
		return "Recolher semente"
	if item.kind == "npc":
		return "Conversar com " + String(item.name)
	if item.id == "mother":
		return "Plantar as cinco sementes" if collected.size() == 5 and not complete else "Escutar a árvore-mãe"
	return "Ler o caderno" if item.id == "camp" else "Ler a placa"

func interact() -> void:
	if mode != "playing" or building_preview:
		return
	var item := current_interaction()
	if item.is_empty():
		return
	if item.kind=="shop":open_shop(item.id);return
	if item.kind=="inn":open_inn(item.id);return
	if item.kind=="house":open_house(item.id);return
	if item.kind=="resource":
		if action_delay>0:return
		action_delay=0.6
		var result:=rpg.harvest(item.id,item.resource_kind)
		hud.toast(result.message)
		if result.ok:audio.chime();save_journey()
		return
	if item.kind=="animal":
		hud.toast(world.animals[item.id].produce().message)
		save_journey()
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
		victory_delay = 0.0
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
		_open_dialog("HISTÓRIAS DOS REINOS", item.name, body, actions)

func peace_achieved() -> bool:
	return royal_seals.has("aurelia") and royal_seals.has("valverde")

func _refresh_quest() -> void:
	hud.update_rpg(rpg)

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
	elif topic=="economy":
		var account:=rpg.npc_account(id)
		var names:=PackedStringArray()
		for tool in account.tools:names.append(RPGState.ITEMS[tool].name)
		var home:Dictionary=rpg.houses.get("home_"+id,{})
		body="Moedas: %d\nMadeira: %d · Pedra: %d\nFerramentas: %s\n\nPlano atual: %s\nCasa: %s"%[account.gold,account.wood,account.stone,", ".join(names) if not names.is_empty() else "economizando",account.job,"ainda não reservei terreno" if home.is_empty() else RPGState.STAGES[home.stage]]
	elif topic=="peace":
		if id in ["aurel","caio"]:
			var first:=not royal_seals.has(profile.realm)
			royal_seals[profile.realm]=true
			if first:rpg.xp+=30
			body="As estradas e os mercados ligam os dois povos. Você tem minha palavra: viajantes e artesãos serão bem-vindos. Faça seu caminho, conheça os vilarejos e construa seu lugar entre os reinos."
		else:body="Aurélia e Valverde dependem do comércio e de quem mantém seus caminhos vivos. Converse com os dois reis nas capitais."

	_refresh_quest()
	save_journey()
	var actions: Array[Dictionary] = []
	if topic == "greeting":
		actions = [
			{"label": "Sobre os dois reinos", "callback": open_npc.bind(id, "realm")},
			{"label": "Como é sua rotina?", "callback": open_npc.bind(id, "routine")},
			{"label":"Suas compras e sua casa","callback":open_npc.bind(id,"economy")},
			{"label": "Tem algum conselho para mim?", "callback": open_npc.bind(id, "hint")},
			{"label": "Podemos unir os dois reinos?", "callback": open_npc.bind(id, "peace")},
			{"label": "Escolher sprite deste morador", "callback": _open_npc_sprite.bind(id)},
			{"label": "Até logo", "callback": close_dialog},
		]
		if id in ["bento","lia","iris"] or profile.role=="Mercador":
			actions.push_front({"label":"Comprar e vender","callback":open_shop.bind(KingdomData.nearest_town(npc.position).id)})
	else:
		actions = [{"label": "Perguntar outra coisa", "callback": open_npc.bind(id, "greeting")}, {"label": "Até logo", "callback": close_dialog}]
	_open_dialog(String(KingdomData.REALMS[profile.realm].name).to_upper(), "%s · %s" % [profile.name, profile.role], body, actions, "npc")

func rest_until_morning() -> void:
	rpg.health=100
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
	if building_preview:cancel_building()
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
	if mode != "playing" and not (mode=="dialog" and hud.modal_kind=="pause"):
		return
	save_journey()
	_open_dialog("UMA PEQUENA PAUSA", "A aventura espera por você.", "Não é preciso ter pressa. Sua jornada é salva automaticamente neste dispositivo.", [
		{"label": "Continuar a jornada", "callback": close_dialog},
		{"label": "Escolher personagem", "callback": show_characters},
		{"label": "Criar / editar mapa · F2", "callback": show_map_editor},
		{"label": "Gráficos: " + ("leve" if light_graphics else "nítido"), "callback": toggle_graphics},
		{"label": "Shaders: " + ("ligados" if shaders_enabled else "desligados"), "callback": toggle_shaders},
		{"label": "Como jogar", "callback": show_help},
		{"label": "Começar de novo", "callback": confirm_reset},
	], "pause")

func toggle_graphics() -> void:
	light_graphics = not light_graphics
	if hybrid != null:
		hybrid.set_light_graphics(light_graphics)
	show_pause()

func toggle_shaders() -> void:
	shaders_enabled=not shaders_enabled
	if hybrid!=null:hybrid.set_shaders(shaders_enabled)
	save_journey()
	show_pause()

func show_map_editor() -> void:
	if map_editor==null:
		map_editor=WorldEditor.new()
		add_child(map_editor)
		map_editor.setup(self)
	if map_editor.visible:map_editor.close()
	else:map_editor.open()

func apply_map(document:Dictionary) -> bool:
	var checked:=MapDocument.validate(document)
	if not checked.ok:return false
	map_snapshots[MapDocument.current.id]=journey_data().duplicate(true)
	save_journey()
	if hybrid!=null:hybrid.free();hybrid=null
	world.free()
	MapDocument.activate(checked.document)
	save_path=_map_save_path()
	rpg=RPGState.new()
	collected.clear();met_npcs.clear();royal_seals.clear();complete=false
	var template:Node=load("res://scenes/main.tscn").instantiate()
	world=template.get_node("World")
	template.remove_child(world);template.free()
	world.name="World"
	add_child(world)
	player=world.player
	camera=player.get_node("Camera2D")
	player.position=MapDocument.spawn_point()
	player.interact_requested.connect(interact)
	rpg.changed.connect(_refresh_quest)
	if map_snapshots.has(MapDocument.current.id):apply_journey(map_snapshots[MapDocument.current.id])
	elif persistence:_load_journey()
	world.refresh_rpg();world.ensure_region(player.position,true)
	player.position=world.safe_position(player.position)
	player.restore_surface()
	if not "--test" in OS.get_cmdline_user_args() or "--hybrid" in OS.get_cmdline_user_args():
		hybrid=HybridWorld.new();add_child(hybrid);hybrid.setup(self)
	mode="playing";return_mode="playing"
	player.active=true;world.set_population_active(true)
	hud.root.show();hud.show_game();hud.close_dialog()
	_refresh_quest()
	if map_editor!=null:map_editor.visible=false
	save_journey()
	hud.toast("Seu mapa está pronto para explorar. F2 volta ao ateliê.")
	return true

func show_help()->void:
	_open_dialog("GUIA DO AVENTUREIRO","Faça seu caminho.","WASD/setas · Mover e nadar\nShift · Correr / nadar mais rápido\nE · Conversar, negociar e colher\nEspaço ou clique esquerdo · Atacar\nI · Inventário e provisões\nJ · Objetivos e registros\nB · Escolher terreno para sua casa\nM · Mapa do continente\nF2 · Criar ou editar seu mapa\nEsc · Pausar\n\nCompre machado, picareta e martelo no comércio. Madeira e pedra servem para construir ou podem ser vendidas. A casa cresce em três etapas. Vilarejos têm estalagens, caravanas e encomendas. Alguns moradores também compram ferramentas e constroem casas. Javalis podem atacar; provisões e descanso recuperam vida.",[{"label":"Continuar","callback":close_dialog}],"help")

func show_map() -> void:
	if mode == "dialog" and hud.modal_kind == "map":
		close_dialog()
		return
	var map_view := ForestMinimap.new()
	map_view.world_data = world.data
	map_view.collected = collected
	map_view.player_position = player.position
	map_view.restored = complete
	var home:Dictionary=rpg.houses.get("home_player",{})
	if not home.is_empty():map_view.home_position=Vector2(home.x,home.y)
	_open_dialog("CADA CAMINHO, UMA DESCOBERTA", "Entre os dois reinos", "Mapa do continente · 25 vezes a área original\nQuadrados · cidades e vilarejos\nPonto claro · você\nCírculo dourado · sua casa", [{"label": "Voltar ao caminho", "callback": close_dialog}], "map", map_view)

func confirm_reset() -> void:
	_open_dialog("UMA NOVA JORNADA", "Voltar ao primeiro passo?", "O inventário, as casas, o dinheiro e a exploração desta aventura serão reiniciados.", [
		{"label": "Manter minha jornada", "callback": close_dialog},
		{"label": "Sim, começar de novo", "callback": reset_journey},
	], "reset")

func reset_journey() -> void:
	cancel_building()
	for node in world.houses.values():node.queue_free()
	for node in world.house_areas.values():node.queue_free()
	world.houses.clear();world.house_areas.clear()
	if hybrid!=null:
		for node in hybrid.landscape.house_models.values():node.queue_free()
		hybrid.landscape.house_models.clear()
	var fresh:=RPGState.new()
	rpg.restore(fresh.save_data())
	for coord in world.chunks.keys():world._unload_chunk(coord)
	collected.clear()
	met_npcs.clear()
	royal_seals.clear()
	for npc in world.npcs.values():npc.home_override=Vector2(INF,INF);npc.economic_target=Vector2(INF,INF)
	world.reset_population()
	complete = false
	victory_delay = 0.0
	player.position = MapDocument.spawn_point()
	player.restore_surface()
	world.data=WorldData.generate()
	world.ensure_region(player.position,true)
	player.stamina = 1.0
	player.touch_vector = Vector2.ZERO
	world.apply_progress(collected, false)
	_refresh_quest()
	camera.reset_smoothing()
	start_journey()
	if hybrid != null:
		hybrid.snap_camera()
	hud.toast("Uma nova aventura entre os dois reinos.")

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
	return {"version": 2,"rpg":rpg.save_data(), "x": player.position.x, "y": player.position.y, "swimming": player.swimming, "light_graphics": light_graphics,"shaders":shaders_enabled,"map_id":MapDocument.current.id, "seeds": collected.keys(), "complete": complete, "custom_character": custom_character, "clock": world.clock.save_data(), "npcs": world.population_data(), "met_npcs": met_npcs.keys(), "royal_seals": royal_seals.keys()}

func apply_journey(data: Dictionary) -> bool:
	if (data.get("version")!=1 and data.get("version")!=2) or not data.get("seeds",[]) is Array:
		return false
	collected.clear()
	for id in data.get("seeds",[]):
		for seed_data in WorldData.SEEDS:
			if id == seed_data.id:
				collected[id] = true
	complete = data.get("complete") == true and collected.size() == 5
	player.position = MapDocument.spawn_point()
	var x = data.get("x")
	var y = data.get("y")
	if data.get("version")==2 and (x is float or x is int) and (y is float or y is int):
		var point := Vector2(x, y)
		if point.is_finite() and point.x>38.4 and point.y>38.4 and point.x<WorldData.SIZE.x-38.4 and point.y<WorldData.SIZE.y-38.4:
			player.position = point
	if data.get("rpg") is Dictionary:rpg.restore(data.rpg)
	for coord in world.chunks.keys():world._unload_chunk(coord)
	world.refresh_rpg()
	world.ensure_region(player.position,true)
	if not WorldData.can_stand(player.position,world.data,10,true):
		player.position=MapDocument.spawn_point()
		world.ensure_region(player.position,true)
	player.restore_surface(data.get("swimming", false) == true)
	shaders_enabled=data.get("shaders",true)!=false
	light_graphics = data.get("light_graphics", true) != false
	if hybrid != null:
		hybrid.set_light_graphics(light_graphics)
		hybrid.set_shaders(shaders_enabled)
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
	if data.get("version")==2 and saved_population is Dictionary:
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
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_path).get_base_dir())
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		if not save_warning_shown:
			save_warning_shown = true
			hud.toast("Não foi possível salvar neste dispositivo. A jornada continua nesta sessão.", 6.0)
		return
	file.store_string(JSON.stringify(journey_data()))

func _unhandled_input(event:InputEvent)->void:
	if event.is_echo():return
	if mode=="editor":return
	if event.is_action_pressed("editor"):show_map_editor();get_viewport().set_input_as_handled();return
	if building_preview:
		if event.is_action_pressed("pause") or event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:cancel_building()
		elif event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:place_house(building_point)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		close_dialog() if mode=="dialog" else show_pause()
	elif event.is_action_pressed("map") and (mode=="playing" or mode=="dialog" and hud.modal_kind=="map"):show_map()
	elif event.is_action_pressed("inventory") and (mode=="playing" or mode=="dialog" and hud.modal_kind=="inventory"):
		close_dialog() if mode=="dialog" else show_inventory()
	elif event.is_action_pressed("journal") and (mode=="playing" or mode=="dialog" and hud.modal_kind=="journal"):
		close_dialog() if mode=="dialog" else show_journal()
	elif mode=="playing":
		if event.is_action_pressed("inventory"):show_inventory()
		elif event.is_action_pressed("journal"):show_journal()
		elif event.is_action_pressed("build"):start_building()
		elif event.is_action_pressed("attack") or event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:attack()

func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		player.touch_vector = Vector2.ZERO
		if mode == "playing":
			show_pause()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		if map_editor!=null and map_editor.visible and map_editor.dirty:map_editor.save_draft(false)
		if mode != "intro":
			save_journey()

func open_shop(town:String,page:String="main")->void:
	var actions:Array[Dictionary]=[]
	var body:="Moedas: %d\nMadeira: %d · Pedra: %d\nEscolha o que deseja negociar."%[rpg.gold,rpg.wood,rpg.stone]
	if page=="tools":
		for item in ["axe","pickaxe","hammer","sword"]:
			var owned:=rpg.tools.has(item)
			actions.append({"label":RPGState.ITEMS[item].name+(" · adquirido" if owned else " · %d moedas"%RPGState.ITEMS[item].price),"callback":buy_item.bind(town,item)})
		actions.append({"label":"Voltar ao comércio","callback":open_shop.bind(town)})
	elif page=="sell":
		actions=[{"label":"Vender 10 madeira · +20 moedas","callback":sell_item.bind(town,"wood",10)},{"label":"Vender 8 pedra · +24 moedas","callback":sell_item.bind(town,"stone",8)},{"label":"Vender 2 carne · +8 moedas","callback":sell_item.bind(town,"meat",2)},{"label":"Voltar","callback":open_shop.bind(town)}]
	else:
		actions=[{"label":"Comprar ferramentas e espada","callback":open_shop.bind(town,"tools")},{"label":"Comprar provisão · 5 moedas","callback":buy_item.bind(town,"bread")},{"label":"Vender materiais","callback":open_shop.bind(town,"sell")},{"label":"Entregar encomenda · 15 madeira e 8 pedra","callback":deliver_order.bind(town)},{"label":"Continuar explorando","callback":close_dialog}]
	_open_dialog("COMÉRCIO DOS REINOS","Ferramentas e provisões",body,actions,"shop")

func buy_item(town:String,item:String)->void:
	var result:=rpg.buy(item)
	open_shop(town,"tools" if item!="bread" else "main")
	hud.toast(result.message)
	save_journey()

func sell_item(town:String,kind:String,amount:int)->void:
	var result:=rpg.sell(kind,amount)
	open_shop(town,"sell")
	hud.toast(result.message)
	save_journey()

func deliver_order(town:String)->void:
	var result:=rpg.deliver(town,world.clock.day)
	open_shop(town)
	hud.toast(result.message)
	save_journey()

func open_inn(town:String)->void:
	_open_dialog("ESTALAGEM","Descanso e caravanas","Uma cama quente recupera toda a vida. As caravanas fazem viagens entre as duas capitais e os quatro vilarejos.\n\nMoedas: %d"%rpg.gold,[{"label":"Descansar até a manhã · 5 moedas","callback":rest_inn.bind(town)},{"label":"Viajar de caravana","callback":show_caravans.bind(town)},{"label":"Continuar explorando","callback":close_dialog}],"inn")

func rest_inn(town:String)->void:
	if rpg.gold<5:hud.toast("O descanso custa 5 moedas.");return
	rpg.gold-=5
	rpg.health=100
	rest_until_morning()
	rpg.changed.emit()

func show_caravans(origin:String)->void:
	var actions:Array[Dictionary]=[]
	for town in KingdomData.towns():
		if town.id!=origin:actions.append({"label":town.name+" · 5 moedas","callback":travel_to.bind(town.id)})
	actions.append({"label":"Voltar à estalagem","callback":open_inn.bind(origin)})
	_open_dialog("CARAVANAS","Rotas do continente","Viaje com os mercadores ou faça o caminho a pé. Novos lugares também dão experiência.",actions,"travel")

func travel_to(id:String)->bool:
	var target:Dictionary={}
	for town in KingdomData.towns():
		if town.id==id:target=town
	if target.is_empty() or rpg.gold<5:hud.toast("São necessárias 5 moedas para a viagem.");return false
	rpg.gold-=5
	player.position=target.position+Vector2(0,384)
	player.restore_surface()
	world.ensure_region(player.position,true)
	if hybrid!=null:hybrid.snap_camera()
	camera.reset_smoothing()
	rpg.discover(id)
	close_dialog()
	hud.toast("A caravana chegou a "+target.name+".")
	save_journey()
	return true

func show_inventory()->void:
	var names:=PackedStringArray()
	for tool in rpg.tools:names.append(RPGState.ITEMS[tool].name)
	var body:="Nível %d · %d XP\nVida %d / 100 · Moedas %d\nMadeira %d · Pedra %d\nProvisões %d · Carne %d\n\nFerramentas: %s"%[rpg.level(),rpg.xp,rpg.health,rpg.gold,rpg.wood,rpg.stone,rpg.food,rpg.meat,", ".join(names) if not names.is_empty() else "nenhuma — visite uma ferraria"]
	_open_dialog("SEU EQUIPAMENTO","Inventário",body,[{"label":"Comer provisão · recuperar 30 vida","callback":eat_food},{"label":"Ver objetivos e registros","callback":show_journal},{"label":"Construir minha casa","callback":start_building},{"label":"Voltar à aventura","callback":close_dialog}],"inventory")

func eat_food()->void:
	var result:=rpg.eat()
	show_inventory()
	hud.toast(result.message)
	save_journey()

func show_journal()->void:
	var house:Dictionary=rpg.houses.get("home_player",{})
	var body:="SUA VIDA ENTRE OS REINOS\n\nFerramentas: %d / 4\nLugares descobertos: %d / 6\nSua casa: %s\n\nCompre machado e picareta, extraia recursos e escolha entre vender ou construir. Encomendas pagam 80 moedas por 15 madeira e 8 pedra, uma vez por dia em cada povoado.\n\nUma casa precisa de 50 madeira, 20 pedra e um martelo, em três etapas. O terreno custa 20 moedas.\n\nNos vilarejos, construtores também compram ferramentas, recolhem material e erguem suas casas. Fale com eles para acompanhar.\n\nTRADIÇÃO DO VALE (OPCIONAL)\nAs antigas sementes e a árvore ancestral continuam no vale noroeste. Este é apenas um dos caminhos da sua aventura."%[rpg.tools.size(),rpg.discovered.size(),"nenhum terreno" if house.is_empty() else RPGState.STAGES[house.stage]]
	_open_dialog("REGISTROS DO AVENTUREIRO","Um mundo para descobrir",body,[{"label":"Abrir mapa do continente","callback":show_map},{"label":"Voltar à aventura","callback":close_dialog}],"journal")

func can_build_at(point:Vector2)->Dictionary:
	if not point.is_finite() or point.distance_to(player.position)>500:return {"ok":false,"message":"Escolha um terreno perto de você."}
	var rect:=Rect2(point-Vector2(96,128),Vector2(192,128))
	for wall in world.data.solid_rects:
		if rect.grow(24).intersects(wall):return {"ok":false,"message":"Há uma construção muito perto."}
	for entry in world.resources.values():
		if entry.resource.get("active",true) and WorldData.circle_hits_rect(entry.resource.position,entry.resource.radius+16,rect):return {"ok":false,"message":"Retire árvores e pedras antes de reservar este terreno."}
	for town in KingdomData.towns():
		if town.capital:continue
		var reserved:=Rect2(KingdomData.point(town.id+"_plot")-Vector2(96,128),Vector2(192,128))
		if rect.grow(24).intersects(reserved):return {"ok":false,"message":"Este terreno está reservado para um morador."}
	for y in [0.0,0.5,1.0]:
		for x in [0.0,0.5,1.0]:
			var sample:=rect.position+rect.size*Vector2(x,y)
			if not WorldData.can_stand(sample,world.data,16):return {"ok":false,"message":"O terreno precisa estar livre de água, árvores e pedras."}
			if WorldData.path_distance(sample)<70:return {"ok":false,"message":"Deixe as ruas e estradas livres."}
	return {"ok":true,"message":"Terreno livre · 20 moedas"}

func start_building()->void:
	if mode=="dialog":close_dialog()
	if mode!="playing":return
	if rpg.houses.has("home_player"):open_house("home_player");return
	building_preview=true
	player.active=false
	world.set_population_active(false)
	hud.toast("Escolha um terreno livre. Clique para reservar (20 moedas); botão direito ou Esc cancela.",8)

func _update_build_preview()->void:
	building_point=hybrid.world_position(get_viewport().get_mouse_position()).snapped(Vector2.ONE*16) if hybrid!=null else player.position+Vector2(192,192)
	var result:=can_build_at(building_point)
	if hybrid!=null:hybrid.preview_house(building_point,result.ok and rpg.gold>=20)
	hud.show_interaction(result.message,hybrid.screen_position(player.position) if hybrid!=null else Vector2(640,400))
	hud.interaction_label.text="Clique · "+result.message
	hud.controls.text="Clique para reservar   •   Botão direito ou Esc para cancelar"

func cancel_building()->void:
	if not building_preview:return
	building_preview=false
	if hybrid!=null:hybrid.cancel_preview()
	player.active=mode=="playing"
	world.set_population_active(mode=="playing")

func place_house(point:Vector2)->Dictionary:
	var valid:=can_build_at(point)
	if not valid.ok:hud.toast(valid.message);return valid
	var result:=rpg.claim(point)
	if result.ok:
		cancel_building()
		open_house("home_player")
		save_journey()
	hud.toast(result.message)
	return result

func open_house(id:String)->void:
	if not rpg.houses.has(id):return
	var house:Dictionary=rpg.houses[id]
	var actions:Array[Dictionary]=[]
	var body:String="Etapa: "+RPGState.STAGES[house.stage]
	if house.owner=="player":
		var nearby:bool=player.position.distance_to(Vector2(house.x,house.y+36))<140
		if not nearby:
			body+="\nVá até o terreno para construir ou descansar. Seu lar está marcado no mapa."
			actions.append({"label":"Ver no mapa","callback":show_map})
		elif house.stage<3:
			var cost:Dictionary=RPGState.BUILD_COSTS[house.stage]
			body+="\nPróxima etapa: %d madeira e %d pedra.\nUm martelo é necessário."%[cost.wood,cost.stone]
			actions.append({"label":"Construir próxima etapa","callback":build_house.bind(id)})
		else:
			body+="\nEste é seu lar. Descansar recupera a vida, e você retorna aqui se for socorrido."
			actions.append({"label":"Descansar em casa","callback":rest_until_morning})
	else:body+="\nMorador: "+KingdomData.person(house.owner).get("name","Viajante")
	actions.append({"label":"Continuar explorando","callback":close_dialog})
	_open_dialog("CONSTRUÇÃO","Meu lar" if house.owner=="player" else "Casa de um morador",body,actions,"house")

func build_house(id:String)->void:
	if not rpg.houses.has(id):return
	var at:Dictionary=rpg.houses[id]
	if player.position.distance_to(Vector2(at.x,at.y+36))>140:
		hud.toast("Vá até sua casa para construir.")
		return
	var result:=rpg.build(id)
	if result.ok:
		var house:Dictionary=rpg.houses[id]
		if rpg.home_rect(house).grow(20).has_point(player.position):
			player.position=Vector2(house.x,house.y+48)
			player.restore_surface()
	open_house(id)
	hud.toast(result.message)
	save_journey()

func attack()->void:
	if mode!="playing" or building_preview or action_delay>0:return
	action_delay=0.55
	var target:WorldAnimal
	var nearest:=95.0
	for animal in world.animals.values():
		if not animal.alive:continue
		var distance:float=animal.position.distance_to(player.position)
		if distance<nearest:nearest=distance;target=animal
	if target==null:hud.toast("Espaço: ataque um animal próximo. Uma espada aumenta o dano.");return
	var damage:=(20 if rpg.tools.has("sword") else 7)+rpg.level()*2
	var defeated:=target.hurt(damage)
	hud.toast("Caça concluída: carne e experiência." if defeated else "%s · -%d vida"%[target.definition.name,damage])
	save_journey()

func take_damage(amount:int)->void:
	if mode!="playing" or building_preview:return
	rpg.health=maxi(0,rpg.health-amount)
	damage_flash=0.25
	if rpg.health==0:
		rpg.health=60
		rpg.gold=maxi(0,rpg.gold-5)
		var home:Dictionary=rpg.houses.get("home_player",{})
		player.position=Vector2(home.x,home.y+64) if not home.is_empty() and home.stage==3 else MapDocument.spawn_point()
		player.restore_surface()
		world.ensure_region(player.position,true)
		if hybrid!=null:hybrid.snap_camera()
		hud.toast("Você foi socorrido. Perdeu 5 moedas e manteve seu equipamento.")
	rpg.changed.emit()
	save_journey()
