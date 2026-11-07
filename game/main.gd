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
var weather_mode:="auto"
var camera_settings:Dictionary={"zoom":13.0,"yaw":0.0}
var map_editor: WorldEditor
var equipped_slot:=0
var lantern_enabled:=false
var map_snapshots: Dictionary = {}
var audio: ForestAudio
var character_dialog: FileDialog
var npc_sprite_dialog: FileDialog
var npc_sprite_target: String = ""
var met_npcs: Dictionary = {}
var royal_seals: Dictionary = {}
var rpg := RPGState.new()
var economy:OpenEconomy
var gathering:ResourceGathering
var construction:ConstructionSystem
var social:RelationshipSystem
var politics:FactionSystem
var loading_journey:=false
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
	hud.hotbar_selected.connect(select_hotbar)
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
	gathering=ResourceGathering.new();add_child(gathering);gathering.setup(self)
	construction=ConstructionSystem.new();add_child(construction);construction.setup(self)
	social=RelationshipSystem.new();add_child(social);social.setup(self)
	politics=FactionSystem.new();add_child(politics);politics.setup(self)
	camera.reset_smoothing()
	if not "--test" in OS.get_cmdline_user_args() or "--hybrid" in OS.get_cmdline_user_args():
		hybrid = HybridWorld.new()
		add_child(hybrid)
		hybrid.setup(self)
		hybrid.visible=false;hybrid.set_process(false);hybrid.grade.hide()
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
	if hybrid!=null:hybrid.show();hybrid.set_process(true);hybrid.grade.show()
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
		if building_preview:_update_build_preview();return
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
	var nearest: Dictionary = politics.nearby_interaction() if politics!=null else {}
	var nearest_distance:float = player.position.distance_to(nearest.position)-45.0 if not nearest.is_empty() else INF
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
		if item.kind in ["shop","inn","house","piece"]:distance-=40.0
		if item.kind=="piece" and rpg.construction.pieces.has(item.id):
			if ConstructionCatalog.piece(rpg.construction.pieces[item.id].kind).layer in ["floor","roof"]:distance+=150
		elif item.kind == "seed":distance-=24.0
		elif item.kind=="resource":distance+=12.0
		if distance < nearest_distance:
			nearest = item
			nearest_distance = distance
	return nearest

func _interaction_label(item: Dictionary) -> String:
	if item.kind=="politics_post":return item.name
	if item.kind=="shop":return "Negociar na ferraria"
	if item.kind=="inn":return "Estalagem e caravanas"
	if item.kind=="house":return item.name
	if item.kind=="piece":return item.name+" · usar ou reparar"
	if item.kind=="resource":
		var entry:Dictionary=world.resources.get(item.id,{})
		if entry.is_empty():return item.name
		var definition:=ResourceRules.definition(entry.resource)
		var hp:int=rpg.resources.states.get(item.id,{}).get("hp",definition.hp)
		return "%s · %d/%d"%[definition.name,hp,definition.hp]
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
	if item.kind=="politics_post":
		if item.post_kind=="guild":politics.show_guild(item.id)
		else:politics.show_post(item.id)
		return
	if item.kind=="shop":open_shop(item.id);return
	if item.kind=="inn":open_inn(item.id);return
	if item.kind=="house":open_house(item.id);return
	if item.kind=="piece":construction.show_piece(item.id);return
	if item.kind=="resource":
		gathering.strike(item.id)
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
	if politics!=null and not politics.can_speak(profile):
		_open_dialog("REPUTAÇÃO HOSTIL",profile.name,politics.reaction(profile),[{"label":"Ver facções e reparação","callback":politics.show_overview},{"label":"Continuar explorando","callback":close_dialog}],"hostile_npc")
		return
	if social!=null and social.near(id):rpg.relationships.visit(id,world.clock.day)
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
		var bed:=rpg.construction.assigned(id,"resident");var station:=rpg.construction.assigned(id,"worker")
		if not bed.is_empty():body+="\n\nMoro na cama que você me designou. Volto para lá no meu horário de descanso."
		if not station.is_empty():body+="\nTrabalho na sua "+ConstructionCatalog.piece(rpg.construction.pieces[station].kind).name.to_lower()+" durante meu turno."
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
	if social!=null:body+="\n\nAfinidade %+d · %s\n%s"%[rpg.relationships.record(id).affinity,rpg.relationships.bond_label(id),rpg.relationships.reaction(id,world.clock.day)]
	if politics!=null:
		body+="\n\n"+politics.reaction(profile)
		if id in ["aurel","caio"]:body+="\n"+rpg.politics.narrative(rpg,profile.realm)
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
		if social!=null:actions.push_front({"label":"Conversar e relacionamentos","name":"npc_relationships","callback":social.show_menu.bind(id)})
		if politics!=null:
			for guild_id in FactionCatalog.data.guilds:
				if FactionCatalog.guild(guild_id).master==id:actions.append({"label":"Sua guilda e o QG","name":"npc_guild","callback":politics.show_guild.bind(guild_id)})
			actions.append({"label":"Facções, guildas e fronteiras","name":"npc_factions","callback":politics.show_overview})
	else:
		actions = [{"label": "Perguntar outra coisa", "callback": open_npc.bind(id, "greeting")}, {"label": "Até logo", "callback": close_dialog}]
	_open_dialog(String(KingdomData.REALMS[profile.realm].name).to_upper(), "%s · %s" % [profile.name, profile.role], body, actions, "npc")

func rest_until_morning() -> void:
	rpg.health=100
	world.clock.set_time(7.0, world.clock.day + 1)
	for npc in world.npcs.values():
		npc.apply_schedule(world.clock.minute, true)
		if npc.companion_mode:npc.hunger=0.1;npc.fatigue=0.0
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
	if social!=null and kind!="relationship_scene":social.reset_cinematic()
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
	if social!=null:social.reset_cinematic()
	hud.close_dialog()
	mode = return_mode
	player.active = mode == "playing"
	world.set_population_active(mode == "playing")

func show_pause() -> void:
	if mode != "playing" and not (mode=="dialog" and hud.modal_kind=="pause"):
		return
	save_journey()
	_open_dialog("UMA PEQUENA PAUSA", "A aventura espera por você.", "Q/R · Girar a câmera\nCtrl+roda ou PgUp/PgDn · Zoom\nHome · Centralizar\nClima atual: "+WeatherState.sample(world.clock.day,world.clock.minute,weather_mode).label+"\n\nHD-2D ativa foco suave, bloom e sombras. O modo leve economiza desempenho. Sua jornada é salva automaticamente.", [
		{"label": "Continuar a jornada", "callback": close_dialog},
		{"label": "Escolher personagem", "callback": show_characters},
		{"label": "Criar / editar mapa · F2", "callback": show_map_editor},
		{"label": "Gráficos: " + ("leve" if light_graphics else "HD-2D"), "callback": toggle_graphics},
		{"label": "Shaders: " + ("ligados" if shaders_enabled else "desligados"), "callback": toggle_shaders},
		{"label": "Clima: "+WeatherState.NAMES[weather_mode], "callback": cycle_weather},
		{"label": "Como jogar", "callback": show_help},
		{"label": "Começar de novo", "callback": confirm_reset},
	], "pause")

func toggle_graphics() -> void:
	light_graphics = not light_graphics
	if hybrid != null:
		hybrid.set_light_graphics(light_graphics)
	show_pause()

func cycle_weather()->void:
	weather_mode=WeatherState.MODES[(WeatherState.MODES.find(weather_mode)+1)%WeatherState.MODES.size()]
	save_journey();show_pause()

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
	if construction!=null:construction.bind_world()
	player=world.player
	camera=player.get_node("Camera2D")
	player.position=MapDocument.spawn_point()
	player.interact_requested.connect(interact)
	rpg.changed.connect(_refresh_quest)
	if map_snapshots.has(MapDocument.current.id):apply_journey(map_snapshots[MapDocument.current.id])
	elif persistence:_load_journey()
	world.refresh_rpg();world.ensure_region(player.position,true)
	if social!=null:social.bind_world()
	if politics!=null:politics.bind_world()
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
	_open_dialog("GUIA DO AVENTUREIRO","Faça seu caminho.","WASD/setas · Mover e nadar\nShift · Correr / nadar mais rápido\nE · Conversar, negociar e usar estruturas\nEspaço · Atacar\n1–4 · Equipar ferramentas\n5 · Comer / 6 · Mapa / 7 · Diário / 8 · Lanterna\nRoda do mouse · Selecionar espaço\nClique esquerdo · Usar item selecionado\nI · Inventário e provisões\nJ · Objetivos e registros\nB · Catálogo de construção\nT · Girar peça durante a prévia\nM · Mapa do continente\nF2 · Criar ou editar seu mapa\nQ/R · Girar câmera / Home · Centralizar\nCtrl+roda / PgUp / PgDn · Zoom\nEsc · Pausar, clima e modo HD-2D\n\nCompre ferramentas na ferraria e reúna madeira e pedra. B abre paredes, chão, móveis e estações, com custos e prévia verde/vermelha. A bancada transforma materiais; a forja permite ferramentas de ferro. Use E em camas e estações para designar moradores. Camas livres permitem descansar, salvar e definir um ponto de retorno. Javalis danificam estruturas que bloqueiam sua perseguição; use E para reparar com martelo. Produção avança no tempo do mundo e também durante o descanso; menus pausam o relógio. O inventário, as peças, as filas e as designações são salvos automaticamente.\n\nE em um NPC abre conversas, presentes, memórias e vínculos. J > Relações, missões e identidade acompanha afinidade, classe e facção. Amizade e ajuda abrem cenas pessoais, romance, casamento e companhia de viagem.\n\nJ > Facções, guildas e territórios mostra reputação, ranks, postos e história. E nas bandeiras abre o QG ou posto. Ajudar uma Coroa pode irritar a outra: confira os efeitos antes de entregar recursos.",[{"label":"Continuar","callback":close_dialog}],"help")

func show_map() -> void:
	if mode == "dialog" and hud.modal_kind == "map":
		close_dialog()
		return
	var map_view := ForestMinimap.new()
	map_view.world_data = world.data
	map_view.rpg_state=rpg
	map_view.collected = collected
	map_view.player_position = player.position
	map_view.restored = complete
	var home:Dictionary=rpg.houses.get("home_player",{})
	if not home.is_empty():map_view.home_position=Vector2(home.x,home.y)
	if rpg.construction.pieces.has(rpg.construction.player_bed):map_view.home_position=ConstructionCatalog.footprint(rpg.construction.pieces[rpg.construction.player_bed]).get_center()
	_open_dialog("CADA CAMINHO, UMA DESCOBERTA", "Entre os dois reinos", "Mapa do continente · 25 vezes a área original\nQuadrados · cidades e vilarejos\nÁreas douradas/verdes · administração dos postos\nLosangos · QGs das guildas\nPonto claro · você · Círculo dourado · sua casa", [{"label":"Facções e territórios","callback":politics.show_overview},{"label": "Voltar ao caminho", "callback": close_dialog}], "map", map_view)

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
	world.refresh_rpg()
	if social!=null:social.bind_world()
	if politics!=null:politics.bind_world()
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
	if construction!=null and not loading_journey:construction._time_changed()
	return {"version": 2,"rpg":rpg.save_data(), "x": player.position.x, "y": player.position.y, "swimming": player.swimming, "light_graphics": light_graphics,"shaders":shaders_enabled,"map_id":MapDocument.current.id,"equipped_slot":equipped_slot,"lantern":lantern_enabled,"stamina":player.stamina,"visual":{"zoom":camera_settings.zoom,"yaw":camera_settings.yaw,"weather":weather_mode}, "seeds": collected.keys(), "complete": complete, "custom_character": custom_character, "clock": world.clock.save_data(), "npcs": world.population_data(), "met_npcs": met_npcs.keys(), "royal_seals": royal_seals.keys()}

func apply_journey(data: Dictionary) -> bool:
	if (data.get("version")!=1 and data.get("version")!=2) or not data.get("seeds",[]) is Array:
		return false
	loading_journey=true
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
	for npc in world.npcs.values():npc.companion_mode=false;npc.follow_target=Vector2(INF,INF)
	for coord in world.chunks.keys():world._unload_chunk(coord)
	world.refresh_rpg()
	if rpg.construction.migrated:player.position=world.safe_position(player.position)
	world.ensure_region(player.position,true)
	if not WorldData.can_stand(player.position,world.data,10,true):
		player.position=MapDocument.spawn_point()
		world.ensure_region(player.position,true)
	player.restore_surface(data.get("swimming", false) == true)
	player.stamina=clampf(float(data.get("stamina",1.0)),0,1) if ResourceProgress.number(data.get("stamina",1.0)) else 1.0
	equipped_slot=clampi(int(data.get("equipped_slot",0)),0,7)
	lantern_enabled=data.get("lantern",false)==true
	hud.hotbar.slot=equipped_slot;hud.hotbar.lantern=lantern_enabled
	var visual:Variant=data.get("visual",{})
	if visual is Dictionary:
		camera_settings={"zoom":clampf(float(visual.get("zoom",13)),HybridWorld.MIN_ZOOM,HybridWorld.MAX_ZOOM) if ResourceProgress.number(visual.get("zoom",13)) else 13.0,"yaw":clampf(float(visual.get("yaw",0)),-HybridWorld.MAX_YAW,HybridWorld.MAX_YAW) if ResourceProgress.number(visual.get("yaw",0)) else 0.0}
		weather_mode=visual.get("weather","auto") if visual.get("weather","auto") in WeatherState.MODES else "auto"
	if hybrid!=null:hybrid.restore_view(camera_settings)
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
	loading_journey=false
	if construction!=null:construction.bind_world()
	if social!=null:social.bind_world()
	if politics!=null:politics.bind_world()
	return true

func _load_journey() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if parsed is Dictionary:
		var building_data:Variant=ConstructionAudit.unwrap(parsed)
		if building_data is Dictionary and building_data.get("pieces") is Dictionary and not building_data.pieces.is_empty() and (not ResourceProgress.number(building_data.get("grid_version",1)) or int(building_data.get("grid_version",1))<WorldGrid.VERSION):
			var backup:=save_path+".grid-v1.bak"
			if not FileAccess.file_exists(backup) and DirAccess.copy_absolute(ProjectSettings.globalize_path(save_path),ProjectSettings.globalize_path(backup))!=OK:
				persistence=false;hud.toast("Não foi possível guardar a cópia do grid antigo. A aventura continuará sem sobrescrever seu save.",8)
	if parsed is Dictionary and apply_journey(parsed):
		hud.set_started(true)

func save_journey() -> void:
	if not persistence:
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_path).get_base_dir())
	var temporary:=save_path+".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		if not save_warning_shown:
			save_warning_shown = true
			hud.toast("Não foi possível salvar neste dispositivo. A jornada continua nesta sessão.", 6.0)
		return
	file.store_string(JSON.stringify(journey_data()))
	file.flush()
	var write_error:=file.get_error();file.close()
	if write_error!=OK or DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(save_path))!=OK:
		if not save_warning_shown:save_warning_shown=true;hud.toast("Não foi possível atualizar o save. O salvamento anterior foi preservado.",6)

func _input(event:InputEvent)->void:
	# Camera keys remain usable when a HUD button still owns keyboard focus.
	if mode=="playing" and hybrid!=null and event is InputEventKey and event.pressed and not event.is_echo():
		if hybrid.camera_input(event):get_viewport().set_input_as_handled()
	if building_preview and construction!=null and not construction.selected.is_empty() and event is InputEventKey and event.pressed and not event.is_echo() and event.physical_keycode==KEY_T:
		construction.turn=posmod(construction.turn+1,4);construction.update_preview();get_viewport().set_input_as_handled()

func _unhandled_input(event:InputEvent)->void:
	if event.is_echo():return
	if mode=="editor":return
	if event.is_action_pressed("editor"):show_map_editor();get_viewport().set_input_as_handled();return
	if mode=="playing" and hybrid!=null and hybrid.camera_input(event):get_viewport().set_input_as_handled();return
	if mode=="playing" and event is InputEventKey and event.pressed and event.physical_keycode>=KEY_1 and event.physical_keycode<=KEY_8:
		select_hotbar(int(event.physical_keycode-KEY_1));get_viewport().set_input_as_handled();return
	if mode=="playing" and event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		select_hotbar(posmod(equipped_slot+(1 if event.button_index==MOUSE_BUTTON_WHEEL_DOWN else -1),8),false);return
	if building_preview:
		if event.is_action_pressed("pause") or event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:cancel_building()
		elif event.is_action_pressed("build") and construction!=null:construction.show_catalog(construction.category)
		elif event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
			if construction!=null and not construction.selected.is_empty():construction.place(building_point)
			else:place_house(building_point)
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
		elif event.is_action_pressed("build"):construction.show_catalog()
		elif event.is_action_pressed("attack"):attack()
		elif event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:use_equipped()

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
	if politics!=null and not politics.trade_allowed(town):return
	var price_factor:float=rpg.politics.trade_factor(rpg,town)
	var actions:Array[Dictionary]=[]
	var body:="Moedas: %d\nMadeira: %d · Pedra: %d\nEscolha o que deseja negociar."%[rpg.gold,rpg.wood,rpg.stone]
	body+="\n\nAdministração: "+FactionCatalog.faction(FactionCatalog.town_faction(rpg,town)).get("name","")+" · preços %d%%"%roundi(price_factor*100)
	if page=="tools":
		for item in ["axe","pickaxe","hammer","sword"]:
			var owned:=rpg.tools.has(item)
			actions.append({"label":RPGState.ITEMS[item].name+(" · adquirido" if owned else " · %d moedas"%ceili(RPGState.ITEMS[item].price*price_factor)),"callback":buy_item.bind(town,item)})
		for tool in ["axe","pickaxe"]:
			var tier:=rpg.resources.tier(tool,rpg.tools)
			if tier>0 and tier<3:actions.append({"label":"Melhorar "+RPGState.ITEMS[tool].name+" para "+ResourceRules.TIERS[tier+1]+(" · %d moedas, 5 madeira, 10 pedra"%ceili(40*price_factor) if tier==1 else " · %d moedas, 6 ferro"%ceili(90*price_factor)),"callback":upgrade_tool.bind(town,tool)})
		actions.append({"label":"Voltar ao comércio","callback":open_shop.bind(town)})
	elif page=="sell":
		actions=[{"label":"Vender 10 madeira · +20 moedas","callback":sell_item.bind(town,"wood",10)},{"label":"Vender 8 pedra · +24 moedas","callback":sell_item.bind(town,"stone",8)},{"label":"Vender 2 carne · +8 moedas","callback":sell_item.bind(town,"meat",2)},{"label":"Voltar","callback":open_shop.bind(town)}]
		actions.insert(3,{"label":"Vender 3 cobre · +21 moedas","callback":sell_item.bind(town,"copper",3)})
		actions.insert(4,{"label":"Vender 3 ferro · +36 moedas","callback":sell_item.bind(town,"iron",3)})
	else:
		actions=[{"label":"Comprar ferramentas e espada","callback":open_shop.bind(town,"tools")},{"label":"Comprar provisão · %d moedas"%ceili(5*price_factor),"callback":buy_item.bind(town,"bread")},{"label":"Vender materiais","callback":open_shop.bind(town,"sell")},{"label":"Entregar encomenda · 15 madeira e 8 pedra · reputação +4 / rival -1","callback":deliver_order.bind(town)},{"label":"Continuar explorando","callback":close_dialog}]
	_open_dialog("COMÉRCIO DOS REINOS","Ferramentas e provisões",body,actions,"shop")

func buy_item(town:String,item:String)->void:
	if politics!=null and not politics.trade_allowed(town):return
	var result:=rpg.buy(item,"player",rpg.politics.trade_factor(rpg,town))
	open_shop(town,"tools" if item!="bread" else "main")
	hud.toast(result.message)
	save_journey()

func upgrade_tool(town:String,tool:String)->void:
	if politics!=null and not politics.trade_allowed(town):return
	var result:=rpg.upgrade_tool(tool,rpg.politics.trade_factor(rpg,town));open_shop(town,"tools");hud.toast(result.message);save_journey()

func sell_item(town:String,kind:String,amount:int)->void:
	if politics!=null and not politics.trade_allowed(town):return
	var result:=rpg.sell(kind,amount)
	open_shop(town,"sell")
	hud.toast(result.message)
	save_journey()

func deliver_order(town:String)->void:
	if politics!=null and not politics.trade_allowed(town):return
	var result:=rpg.deliver(town,world.clock.day)
	if result.ok:rpg.politics.change_reputation(rpg,FactionCatalog.town_faction(rpg,town),4,world.clock.day,"Encomenda de "+FactionCatalog.service_name(town),-1)
	open_shop(town)
	hud.toast(result.message)
	save_journey()

func open_inn(town:String)->void:
	if politics!=null and not politics.trade_allowed(town):return
	_open_dialog("ESTALAGEM","Descanso e caravanas","Uma cama quente recupera toda a vida. As caravanas fazem viagens entre as duas capitais e os quatro vilarejos.\n\nMoedas: %d"%rpg.gold,[{"label":"Descansar até a manhã · 5 moedas","callback":rest_inn.bind(town)},{"label":"Viajar de caravana","callback":show_caravans.bind(town)},{"label":"Continuar explorando","callback":close_dialog}],"inn")

func rest_inn(town:String)->void:
	if politics!=null and not politics.trade_allowed(town):return
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
	if politics!=null and not politics.trade_allowed(id):return false
	rpg.gold-=5
	player.position=target.position+Vector2(0,384)
	player.restore_surface()
	world.ensure_region(player.position,true)
	if social!=null:social.travel_with_player()
	if hybrid!=null:hybrid.snap_camera()
	camera.reset_smoothing()
	rpg.discover(id)
	close_dialog()
	hud.toast("A caravana chegou a "+target.name+".")
	save_journey()
	return true

func show_inventory()->void:
	var names:=PackedStringArray()
	for tool in rpg.tools:names.append(RPGState.ITEMS[tool].name+(" de "+ResourceRules.TIERS[rpg.resources.tier(tool,rpg.tools)] if tool in ["axe","pickaxe"] else ""))
	var body:="Nível %d · %d XP\nVida %d / 100 · Moedas %d\nMadeira %d · Pedra %d\nProvisões %d · Carne %d\n\nFerramentas: %s"%[rpg.level(),rpg.xp,rpg.health,rpg.gold,rpg.wood,rpg.stone,rpg.food,rpg.meat,", ".join(names) if not names.is_empty() else "nenhuma — visite uma ferraria"]
	body+="\nCobre %d · Ferro %d\nEnergia %d / 100\nLenhador nível %d · Mineiro nível %d\n\nUse E ou a ferramenta da hotbar para golpear. Materiais caem no chão: aproxime-se para recolher. Árvores voltam em 3 dias; rochas e minérios em 5–7 dias."%[rpg.copper,rpg.iron,roundi(player.stamina*100),rpg.resources.level("woodcutting"),rpg.resources.level("mining")]
	if construction!=null:
		for item in ConstructionCatalog.PROCESSED:body+="\n%s: %d"%[ConstructionCatalog.MATERIALS[item].capitalize(),rpg.construction.amount(rpg,item)]
	_open_dialog("SEU EQUIPAMENTO","Inventário",body,[{"label":"Comer provisão · recuperar 30 vida","callback":eat_food},{"label":"Ver objetivos e registros","callback":show_journal},{"label":"Construção e fabricação","callback":construction.show_catalog.bind("stations")},{"label":"Voltar à aventura","callback":close_dialog}],"inventory")

func eat_food()->void:
	var result:=rpg.eat()
	show_inventory()
	hud.toast(result.message)
	save_journey()

func show_journal()->void:
	var house:Dictionary=rpg.houses.get("home_player",{})
	var body:="SUA VIDA ENTRE OS REINOS\n\nFerramentas: %d / 4\nLugares descobertos: %d / 6\nSua casa: %s\n\nCompre machado e picareta, extraia recursos e escolha entre vender ou construir. Encomendas pagam 80 moedas por 15 madeira e 8 pedra, uma vez por dia em cada povoado.\n\nUma casa precisa de 50 madeira, 20 pedra e um martelo, em três etapas. O terreno custa 20 moedas.\n\nNos vilarejos, construtores também compram ferramentas, recolhem material e erguem suas casas. Fale com eles para acompanhar.\n\nTRADIÇÃO DO VALE (OPCIONAL)\nAs antigas sementes e a árvore ancestral continuam no vale noroeste. Este é apenas um dos caminhos da sua aventura."%[rpg.tools.size(),rpg.discovered.size(),"nenhum terreno" if house.is_empty() else RPGState.STAGES[house.stage]]
	var actions:Array[Dictionary]=[]
	if social!=null:actions.append({"label":"Relações, missões e identidade","name":"journal_relationships","callback":social.show_journal.bind(0)})
	if politics!=null:actions.append({"label":"Facções, guildas e territórios","name":"journal_factions","callback":politics.show_overview})
	actions.append({"label":"Abrir mapa do continente","callback":show_map})
	actions.append({"label":"Voltar à aventura","callback":close_dialog})
	_open_dialog("REGISTROS DO AVENTUREIRO","Um mundo para descobrir",body,actions,"journal")

func can_build_at(point:Vector2)->Dictionary:
	point=RPGState.snap_home(point)
	if not point.is_finite() or point.distance_to(player.position)>500:return {"ok":false,"message":"Escolha um terreno perto de você."}
	var rect:=Rect2(point-Vector2(96,128),Vector2(192,128))
	for entry in rpg.construction.pieces.values():
		if rect.intersects(ConstructionCatalog.footprint(entry)):return {"ok":false,"message":"Há uma peça construída neste terreno."}
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
	if construction!=null:construction.selected=""
	if mode=="dialog":close_dialog()
	if mode!="playing":return
	if rpg.houses.has("home_player"):open_house("home_player");return
	building_preview=true
	player.active=false
	world.set_population_active(false)
	hud.toast("Escolha um terreno livre. Clique para reservar (20 moedas); botão direito ou Esc cancela.",8)

func _update_build_preview()->void:
	if construction!=null and not construction.selected.is_empty():construction.update_preview();return
	building_point=RPGState.snap_home(hybrid.world_position(get_viewport().get_mouse_position()) if hybrid!=null else player.position+Vector2(192,192))
	var result:=can_build_at(building_point)
	if hybrid!=null:hybrid.preview_house(building_point,result.ok and rpg.gold>=20)
	hud.show_interaction(result.message,hybrid.screen_position(player.position) if hybrid!=null else Vector2(640,400))
	hud.interaction_label.text="Clique · "+result.message
	hud.controls.text="Clique para reservar   •   Botão direito ou Esc para cancelar"

func cancel_building()->void:
	if hybrid!=null:hybrid.cancel_preview()
	if construction!=null and is_instance_valid(construction.grid_guide):construction.grid_guide.hide()
	if construction!=null:construction.selected=""
	if not building_preview:return
	building_preview=false
	player.active=mode=="playing"
	world.set_population_active(mode=="playing")

func place_house(point:Vector2)->Dictionary:
	point=RPGState.snap_home(point)
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
	body+="\nVida: %d/%d"%[house.get("hp",RPGState.HOUSE_HP[house.stage]),RPGState.HOUSE_HP[house.stage]]
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
		if nearby and not rpg.house_repair_cost(id).is_empty():actions.append({"label":"Reparar · "+ConstructionCatalog.cost_text(rpg.house_repair_cost(id)),"callback":repair_house.bind(id)})
		actions.append({"label":"Abrir catálogo de construção","callback":construction.show_catalog.bind("walls")})
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

func repair_house(id:String)->void:
	if not rpg.houses.has(id):return
	var at:Dictionary=rpg.houses[id]
	if player.position.distance_to(Vector2(at.x,at.y+36))>140:hud.toast("Vá até sua casa para reparar.");return
	var result:=rpg.repair_house(id);open_house(id);hud.toast(result.message);save_journey()

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
	var damage:=(20 if rpg.tools.has("sword") and equipped_slot==0 else 7)+rpg.level()*2
	var defeated:=target.hurt(damage)
	if defeated and target.species=="boar":rpg.relationships.boars_killed+=1
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
		var bed_spawn:=construction.respawn() if construction!=null else Vector2(INF,INF)
		player.position=bed_spawn if bed_spawn.is_finite() else (Vector2(home.x,home.y+64) if not home.is_empty() and home.stage==3 else MapDocument.spawn_point())
		player.restore_surface()
		world.ensure_region(player.position,true)
		if social!=null:social.travel_with_player("Seu companheiro acompanhou o resgate.")
		if hybrid!=null:hybrid.snap_camera()
		hud.toast("Você foi socorrido. Perdeu 5 moedas e manteve seu equipamento.")
	rpg.changed.emit()
	save_journey()

func select_hotbar(index:int,activate:bool=true)->void:
	if mode!="playing":return
	equipped_slot=clampi(index,0,7)
	hud.hotbar.slot=equipped_slot;hud.hotbar.queue_redraw()
	var item:String=RPGHotbar.ITEMS[equipped_slot]
	if equipped_slot<4:
		hud.toast(RPGHotbar.NAMES[equipped_slot]+(" equipado." if rpg.tools.has(item) else " · Compre na ferraria."),2)
	elif activate:use_equipped()
	save_journey()

func use_equipped()->void:
	if mode!="playing" or building_preview:return
	match equipped_slot:
		0:attack()
		1,2:
			var kind:="wood" if equipped_slot==1 else "stone"
			var nearest:="";var distance:=65.0
			for entry in world.resources.values():
				if not entry.resource.active or entry.resource.kind!=kind:continue
				var gap:float=entry.resource.position.distance_to(player.position)
				if gap<distance:nearest=entry.resource.id;distance=gap
			if not nearest.is_empty():gathering.strike(nearest)
			else:hud.toast("Aproxime-se de uma árvore." if equipped_slot==1 else "Aproxime-se de uma rocha.")
		3:
			if not rpg.tools.has("hammer"):hud.toast("Compre um martelo na ferraria.");return
			construction.show_catalog()
		4:
			var result:=rpg.eat();hud.toast(result.message);_refresh_quest();save_journey()
		5:show_map()
		6:show_journal()
		7:
			lantern_enabled=not lantern_enabled;hud.hotbar.lantern=lantern_enabled;hud.hotbar.queue_redraw();save_journey()
