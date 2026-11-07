class_name ForestHUD
extends CanvasLayer

signal play_requested
signal pause_requested
signal help_requested
signal map_requested
signal hotbar_selected(index:int)
signal editor_requested
signal sound_requested
signal character_requested
signal dialog_closed
signal interact_requested
signal touch_moved(value: Vector2)

const CREAM := Color("f4eedb")
const INK := Color("e8d6b2")
const MUTED := Color("cbd0b3")
const PAPER := Color("1c2430")
const MOSS := Color("604d3a")

var root: Control
var brand: Control
var brand_title: Label
var brand_subtitle: Label
var brand_icon: TextureRect
var toolbar: HBoxContainer
var location: Label
var time_label: Label
var quest: PanelContainer
var quest_description: Label
var quest_title: Label
var quest_note: Label
var seed_counter: Label
var seed_slots: Array[PanelContainer] = []
var intro: Control
var intro_body: VBoxContainer
var intro_title: Label
var play_button: Button
var caption: Label
var bottom_player: Control
var stamina: ProgressBar
var controls: Label
var map_panel: PanelContainer
var minimap: ForestMinimap
var interaction_panel: PanelContainer
var interaction_label: Label
var toast_panel: PanelContainer
var toast_label: Label
var toast_time: float = 0.0
var modal: Control
var modal_panel: PanelContainer
var modal_kind: String = ""
var sound_button: Button
var touch_controls: Control
var joystick: ForestJoystick
var touch_action: Button
var serif: Font
var hotbar:RPGHotbar
var life_bar:ProgressBar
var game_started: bool = false
var modal_scroll:ScrollContainer
var modal_content:VBoxContainer
var portrait: TextureRect

func _ready() -> void:
	serif=load(PixelArt.FONT)
	root = Control.new()
	root.name = "Interface"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var theme:=Theme.new();theme.default_font=serif;theme.default_font_size=16;root.theme=theme
	_build_atmosphere()
	_build_header()
	_build_quest()
	_build_bottom()
	_build_intro()
	_build_feedback()
	_build_touch()
	get_viewport().size_changed.connect(_layout)
	call_deferred("_layout")

func _style(color: Color, radius: int = 8, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(0)
	style.set_border_width_all(2)
	style.border_color = Color("99825b") if border.a<0.1 else border
	style.shadow_size=3;style.shadow_offset=Vector2(3,3);style.shadow_color=Color(0,0,0,0.55)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _text(value: String, font_size: int = 12, color: Color = CREAM, display_font: bool = false) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font",serif)
	label.add_theme_font_size_override("font_size",48 if font_size>=40 else (24 if font_size>=24 else (16 if font_size>=12 else 12)))
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if display_font:
		label.add_theme_font_override("font", serif)
	return label

func _button(value: String, callback: Callable, filled: bool = false, dark: bool = false) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(0, 40)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font",serif)
	button.add_theme_font_size_override("font_size",16)
	var bg:=Color("614d36") if filled and not dark else Color("202936")
	var fg:=CREAM
	button.add_theme_color_override("font_color", fg)
	button.add_theme_color_override("font_hover_color", fg)
	button.add_theme_color_override("font_focus_color", fg)
	button.add_theme_stylebox_override("normal", _style(bg, 5, Color(0.86, 0.88, 0.73, 0.25)))
	button.add_theme_stylebox_override("hover", _style(bg.lightened(0.12), 5, Color(0.91, 0.89, 0.73, 0.6)))
	button.add_theme_stylebox_override("pressed", _style(bg.darkened(0.1), 5))
	button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, 5, Color("e5d59e")))
	button.pressed.connect(callback)
	return button

func _panel(parent: Node, color: Color, padding: int = 18) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := _style(PAPER, 0)
	style.set_content_margin_all(padding)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel

func _build_atmosphere() -> void:
	pass

func _build_header() -> void:
	brand = Control.new()
	brand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(brand)
	brand_icon = TextureRect.new()
	brand_icon.texture = PixelArt.icon("map")
	brand_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	brand_icon.size = Vector2(36, 36)
	brand_icon.position.y = 4
	brand.add_child(brand_icon)
	brand_title = _text("entre reinos", 28, CREAM, true)
	brand_title.position = Vector2(48, 0)
	brand.add_child(brand_title)
	brand_subtitle = _text("RPG DE MUNDO ABERTO", 8, MUTED)
	brand_subtitle.position = Vector2(49, 38)
	brand.add_child(brand_subtitle)
	location = _text("•  Bosque do vento     |     ☼ Fim de tarde", 11, Color("dee1c5"))
	root.add_child(location)
	time_label = _text("Dia 1 · 08:30 · Manhã", 10, MUTED)
	root.add_child(time_label)
	toolbar = HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	root.add_child(toolbar)
	sound_button = _button("♪", sound_requested.emit)
	sound_button.tooltip_text = "Ativar ou desativar o som ambiente"
	toolbar.add_child(sound_button)
	var help := _button("?", help_requested.emit)
	help.tooltip_text = "Como jogar"
	toolbar.add_child(help)
	var pause := _button("Ⅱ", pause_requested.emit)
	pause.tooltip_text = "Pausar (Esc)"
	toolbar.add_child(pause)
	for button in toolbar.get_children():
		button.custom_minimum_size = Vector2(38, 38)
		button.add_theme_font_size_override("font_size", 18)

func _build_quest()->void:
	quest=_panel(root,PAPER,10)
	quest.name="RPGStatus"
	var box:=VBoxContainer.new();box.add_theme_constant_override("separation",3);quest.add_child(box)
	quest_title=_text("VIAJANTE · NÍVEL 1",16,CREAM)
	box.add_child(quest_title)
	seed_counter=_text("100 MOEDAS",12,Color("dec083"));box.add_child(seed_counter)
	life_bar=ProgressBar.new();life_bar.show_percentage=false;life_bar.custom_minimum_size=Vector2(240,10)
	life_bar.add_theme_stylebox_override("background",_style(Color("111822"),0))
	var fill:=StyleBoxFlat.new();fill.bg_color=Color("b65f5c");life_bar.add_theme_stylebox_override("fill",fill);box.add_child(life_bar)
	quest_description=_text("",12,Color("c1c5bf"));box.add_child(quest_description)
	quest_note=_text("",12);quest_note.hide();box.add_child(quest_note)
	quest.hide()

func _build_intro()->void:
	intro=Control.new();intro.name="Introduction";intro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);intro.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(intro)
	var art:=PixelTitle.new();art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);intro.add_child(art)
	intro_body=VBoxContainer.new();intro_body.add_theme_constant_override("separation",12);intro.add_child(intro_body)
	var kicker:=_text("RPG DE MUNDO ABERTO",12,Color("d8bd88"));kicker.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;intro_body.add_child(kicker)
	intro_title=_text("ENTRE REINOS",48,CREAM,true);intro_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;intro_body.add_child(intro_title)
	var subtitle:=_text("DOIS REINOS. SUA PRÓPRIA HISTÓRIA.",12,Color("b7bdc3"));subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;intro_body.add_child(subtitle)
	intro_body.add_child(Control.new())
	play_button=_button("INICIAR AVENTURA",play_requested.emit,true);play_button.name="PlayButton";intro_body.add_child(play_button)
	intro_body.add_child(_button("PERSONAGEM",character_requested.emit))
	intro_body.add_child(_button("CRIAR MEU MAPA · F2",editor_requested.emit))
	intro_body.add_child(_button("COMO JOGAR",help_requested.emit))
	caption=_text("WASD MOVER  ·  E INTERAGIR  ·  1-8 ATALHOS",12,Color("a7b0bc"));root.add_child(caption)

func _build_bottom() -> void:
	bottom_player = Control.new()
	bottom_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom_player)
	hotbar=RPGHotbar.new();hotbar.selected.connect(hotbar_selected.emit);root.add_child(hotbar);hotbar.hide()
	portrait = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.size = Vector2(40, 52)
	bottom_player.add_child(portrait)
	var name_label := _text("VIAJANTE", 12, CREAM, true)
	name_label.position = Vector2(55, 0)
	bottom_player.add_child(name_label)
	var role := _text("F2 EDITOR", 9, MUTED)
	role.position = Vector2(55, 25)
	bottom_player.add_child(role)
	stamina = ProgressBar.new()
	stamina.position = Vector2(55, 46)
	stamina.size = Vector2(124, 4)
	stamina.show_percentage = false
	var track := _style(Color(0.06, 0.17, 0.13, 0.45), 3)
	track.set_content_margin_all(0)
	track.set_border_width_all(0)
	var fill := _style(Color("c6cf93"), 3)
	fill.set_content_margin_all(0)
	fill.set_border_width_all(0)
	stamina.add_theme_stylebox_override("background", track)
	stamina.add_theme_stylebox_override("fill", fill)
	stamina.size = Vector2(124, 4)
	bottom_player.add_child(stamina)
	stamina.set_deferred("size", Vector2(124, 4))
	controls = _text("WASD mover   Shift correr   E interagir   I inventário   B construir   Espaço atacar", 10, Color("e0e3cd"))
	root.add_child(controls)
	map_panel = _panel(root, Color(0.145, 0.22, 0.17, 0.93), 10)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	map_panel.add_child(box)
	var heading := HBoxContainer.new()
	box.add_child(heading)
	var map_title := _text("MAPA DOS REINOS", 8, Color("dee2bf"))
	map_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(map_title)
	var map_button := _button("M", map_requested.emit)
	map_button.custom_minimum_size = Vector2(24, 24)
	map_button.tooltip_text = "Ampliar mapa (M)"
	map_button.add_theme_font_size_override("font_size", 9)
	heading.add_child(map_button)
	minimap = ForestMinimap.new()
	minimap.local_mode=true
	box.add_child(minimap)
	box.add_child(_text("● você    ■ cidades    ◇ seu lar", 8, Color("bec8a1")))
	bottom_player.hide()
	controls.hide()
	map_panel.hide()

func _build_feedback() -> void:
	interaction_panel = _panel(root, PAPER, 10)
	interaction_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interaction_label = _text("E  Interagir", 11, INK)
	interaction_panel.add_child(interaction_label)
	interaction_panel.hide()
	toast_panel = _panel(root, PAPER, 15)
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_label = _text("", 12, INK)
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_panel.add_child(toast_label)
	toast_panel.hide()

func _build_touch() -> void:
	touch_controls = Control.new()
	touch_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(touch_controls)
	joystick = ForestJoystick.new()
	joystick.size = Vector2(108, 108)
	joystick.vector_changed.connect(touch_moved.emit)
	touch_controls.add_child(joystick)
	touch_action = _button("E\ninteragir", interact_requested.emit)
	touch_action.custom_minimum_size = Vector2(64, 64)
	touch_controls.add_child(touch_action)
	touch_controls.hide()

func _layout()->void:
	if root==null:return
	var viewport_size:=get_viewport().get_visible_rect().size
	brand.position=Vector2(20,8);brand.visible=game_started
	brand_title.position=Vector2(30,0);brand_title.add_theme_font_size_override("font_size",16)
	brand_subtitle.hide();brand_icon.size=Vector2(24,24)
	toolbar.position=Vector2(viewport_size.x-148,14);toolbar.visible=game_started
	location.position=Vector2(330,12);location.visible=game_started and viewport_size.x>=1200
	time_label.position=Vector2(330,12);time_label.visible=game_started and not location.visible
	quest.position=Vector2(20,48);quest.custom_minimum_size.x=272;quest.size=Vector2(272,0)
	intro_body.position=Vector2((viewport_size.x-480)/2,viewport_size.y*0.24);intro_body.size=Vector2(480,0)
	intro_title.add_theme_font_size_override("font_size",48)
	caption.position=Vector2((viewport_size.x-caption.get_minimum_size().x)/2,viewport_size.y-40)
	bottom_player.position=Vector2(24,viewport_size.y-80);bottom_player.visible=game_started
	stamina.size=Vector2(124,6)
	controls.visible=false
	hotbar.visible=game_started;hotbar.position=Vector2((viewport_size.x-480)/2,viewport_size.y-110);hotbar.size=Vector2(480,96)
	minimap.custom_minimum_size=Vector2(156,100);map_panel.reset_size();map_panel.position=Vector2(viewport_size.x-map_panel.size.x-20,64)
	touch_controls.hide()
	toast_label.custom_minimum_size.x=minf(520,viewport_size.x-70);toast_panel.reset_size();call_deferred("_position_toast")
	if modal!=null:_layout_modal()

func set_started(resume: bool = false) -> void:
	if resume:
		play_button.text = "CONTINUAR AVENTURA"

func show_game() -> void:
	game_started = true
	intro.hide()
	caption.hide()
	quest.show()
	map_panel.show()
	_layout()

func update_quest(_collected:Dictionary,_complete:bool,_peace:bool=false)->void:
	pass

func update_rpg(state:RPGState)->void:
	quest_title.text="Viajante · Nível %d"%state.level()
	seed_counter.text="%d moedas"%state.gold
	life_bar.value=state.health
	quest_description.text="VIDA %d/100  XP %d\nMADEIRA %d  PEDRA %d"%[state.health,state.xp,state.wood,state.stone]
	hotbar.rpg=state;hotbar.queue_redraw()
	var home:Dictionary=state.houses.get("home_player",{})
	quest_note.text="I · Inventário   B · Construir\n"+("E · Usar estruturas" if state.construction.queues.is_empty() else "Produção: %d estações ativas"%state.construction.queues.size())
	minimap.home_position=Vector2(home.x,home.y) if not home.is_empty() else Vector2(-1,-1)
	if state.construction.pieces.has(state.construction.player_bed):minimap.home_position=ConstructionCatalog.footprint(state.construction.pieces[state.construction.player_bed]).get_center()

func update_status(player: ForestPlayer, data: Dictionary, clock: WorldClock = null) -> void:
	var realm: Dictionary = KingdomData.REALMS[KingdomData.realm_at(player.position)]
	var time := clock.label() if clock != null else "Dia 1 · 08:30 · Manhã"
	var district:=WorldData.location_name(player.position)
	location.text = "%s  |  %s" % [realm.name if district==String(realm.name).trim_prefix("Reino de ") else realm.name+" · "+district,time]
	location.tooltip_text = WorldData.location_name(player.position)
	time_label.text = time
	stamina.value = player.stamina * 100
	controls.text = "W A S D / setas  nadar     Shift  acelerar     E  interagir" if player.swimming else "WASD mover   Shift correr   E interagir   I inventário   B construir   Espaço atacar"
	minimap.world_data = data
	minimap.player_position = player.position
	minimap.queue_redraw()
	portrait.texture = player.sprite.sprite_frames.get_frame_texture("idle_down", 0)
	portrait.material = player.sprite.material

func show_interaction(value: String, screen_point: Vector2) -> void:
	interaction_panel.visible = not value.is_empty() and modal == null
	interaction_label.text = "E  " + value
	interaction_panel.reset_size()
	var width := get_viewport().get_visible_rect().size.x
	interaction_panel.position = Vector2(clampf(screen_point.x - interaction_panel.size.x / 2.0, 12, width - interaction_panel.size.x - 12), screen_point.y + 27)

func toast(value: String, seconds: float = 4.0) -> void:
	toast_label.text = "✦  " + value
	toast_label.custom_minimum_size.x = minf(460, get_viewport().get_visible_rect().size.x - 70)
	toast_panel.show()
	toast_panel.reset_size()
	toast_time = seconds
	call_deferred("_position_toast")

func _position_toast() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	toast_panel.position = Vector2((viewport_size.x - toast_panel.size.x) / 2.0, viewport_size.y - 178)

func _process(delta: float) -> void:
	if toast_time > 0:
		toast_time -= delta
		if toast_time <= 0:
			toast_panel.hide()

func show_dialog(eyebrow: String, title: String, body: String, actions: Array[Dictionary], kind: String = "dialog", map_view: ForestMinimap = null) -> void:
	close_dialog()
	modal_kind = kind
	interaction_panel.hide()
	joystick.reset()
	modal = Control.new()
	modal.name = "Modal"
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(modal)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.04, 0.1, 0.07, 0.78)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.add_child(backdrop)
	modal_panel = _panel(modal, PAPER, 28)
	modal_scroll=ScrollContainer.new()
	modal_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	modal_scroll.follow_focus=true
	modal_panel.add_child(modal_scroll)
	var box := VBoxContainer.new()
	modal_content=box
	box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 16)
	modal_scroll.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var kicker := _text(eyebrow, 9, Color("d6b57b"))
	kicker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(kicker)
	var close := _button("×", dialog_closed.emit)
	close.custom_minimum_size = Vector2(28, 28)
	close.add_theme_color_override("font_color", INK)
	header.add_child(close)
	var heading := _text(title, 28, INK, true)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.custom_minimum_size.x = minf(404, get_viewport().get_visible_rect().size.x - 96)
	box.add_child(heading)
	if map_view != null:
		map_view.custom_minimum_size = Vector2(0, minf(300, get_viewport().get_visible_rect().size.x * 0.65))
		box.add_child(map_view)
	var content := _text(body, 13, Color("c2c5c4"))
	content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.custom_minimum_size.x = heading.custom_minimum_size.x
	box.add_child(content)
	var focusable: Array[Button] = [close]
	for action in actions:
		var action_button := _button(action.label, action.callback, true, true)
		action_button.name = action.get("name", "Action")
		box.add_child(action_button)
		focusable.append(action_button)
	for i in focusable.size():
		focusable[i].focus_next = focusable[(i + 1) % focusable.size()].get_path()
		focusable[i].focus_previous = focusable[(i - 1 + focusable.size()) % focusable.size()].get_path()
	if focusable.size() > 1:
		focusable[1].grab_focus()
	call_deferred("_layout_modal")

func _layout_modal() -> void:
	if modal_panel == null:
		return
	var available:=get_viewport().get_visible_rect().size
	modal_scroll.custom_minimum_size=Vector2(minf(460,available.x-104),minf(modal_content.get_combined_minimum_size().y,available.y-104))
	modal_panel.reset_size()
	modal_panel.position=(available-modal_panel.size)/2.0

func close_dialog() -> void:
	if modal != null:
		modal.hide()
		modal.queue_free()
		modal = null
		modal_panel = null
	modal_kind = ""

func set_sound(enabled: bool) -> void:
	sound_button.text = "♫" if enabled else "♪"
	sound_button.modulate = Color("e5d59e") if enabled else Color.WHITE
