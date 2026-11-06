class_name ForestHUD
extends CanvasLayer

signal play_requested
signal pause_requested
signal help_requested
signal map_requested
signal sound_requested
signal character_requested
signal dialog_closed
signal interact_requested
signal touch_moved(value: Vector2)

const CREAM := Color("f4eedb")
const INK := Color("334132")
const MUTED := Color("cbd0b3")
const PAPER := Color("f1eedf")
const MOSS := Color("4b6041")

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
var serif: SystemFont
var game_started: bool = false
var portrait: TextureRect

func _ready() -> void:
	serif = SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia", "DejaVu Serif", "serif"])
	root = Control.new()
	root.name = "Interface"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
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
	style.set_corner_radius_all(radius)
	style.set_border_width_all(1)
	style.border_color = border
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _text(value: String, font_size: int = 12, color: Color = CREAM, display_font: bool = false) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
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
	button.add_theme_font_size_override("font_size", 12)
	var bg := MOSS if filled and dark else (CREAM if filled else Color(0.16, 0.23, 0.17, 0.65))
	var fg := INK if filled and not dark else CREAM
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
	var style := _style(color, 10)
	style.set_content_margin_all(padding)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel

func _build_atmosphere() -> void:
	var shade := ColorRect.new()
	shade.name = "ForestLight"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/atmosphere.gdshader")
	shade.material = material
	root.add_child(shade)

func _build_header() -> void:
	brand = Control.new()
	brand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(brand)
	brand_icon = TextureRect.new()
	brand_icon.texture = load("res://assets/icon.svg")
	brand_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	brand_icon.size = Vector2(36, 36)
	brand_icon.position.y = 4
	brand.add_child(brand_icon)
	brand_title = _text("entre folhas", 28, CREAM, true)
	brand_title.position = Vector2(48, 0)
	brand.add_child(brand_title)
	brand_subtitle = _text("UM PEQUENO MUNDO PARA EXPLORAR", 8, MUTED)
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

func _build_quest() -> void:
	quest = _panel(root, Color(0.945, 0.933, 0.875, 0.97), 20)
	quest.name = "QuestCard"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	quest.add_child(box)
	box.add_child(_text("❧  UM RECOMEÇO", 9, Color("6b7654")))
	quest_title = _text("Sementes de um novo bosque", 16, INK, true)
	quest_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_title.custom_minimum_size.x = 240
	box.add_child(quest_title)
	quest_description = _text("Encontre as sementes levadas pelo vento.", 10, Color("75806b"))
	quest_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_description.custom_minimum_size.x = 240
	box.add_child(quest_description)
	var progress := HBoxContainer.new()
	progress.add_theme_constant_override("separation", 7)
	box.add_child(progress)
	for i in 5:
		var slot := _panel(progress, Color.TRANSPARENT, 0)
		slot.custom_minimum_size = Vector2(27, 27)
		var label := _text("❧", 17, Color("a3ab8c"))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.add_child(label)
		seed_slots.append(slot)
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress.add_child(space)
	seed_counter = _text("0 / 5", 20, Color("4c5943"), true)
	progress.add_child(seed_counter)
	var divider := HSeparator.new()
	divider.modulate = Color(0.55, 0.6, 0.45, 0.35)
	box.add_child(divider)
	quest_note = _text("◇ Procure por pequenos brilhos dourados", 9, Color("7a8267"))
	quest_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_note.custom_minimum_size.x = 240
	box.add_child(quest_note)
	quest.hide()

func _build_intro() -> void:
	intro = Control.new()
	intro.name = "Introduction"
	intro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(intro)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.05, 0.12, 0.09, 0.25)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro.add_child(shade)
	intro_body = VBoxContainer.new()
	intro_body.add_theme_constant_override("separation", 20)
	intro.add_child(intro_body)
	intro_body.add_child(_text("—   CAPÍTULO 01 · O DESPERTAR", 10, Color("e0d39c")))
	intro_title = _text("Toda floresta começa\ncom uma semente.", 48, CREAM, true)
	intro_body.add_child(intro_title)
	var description := _text("Dois reinos. Oito histórias. Um bosque para cuidar.\nEncontre as sementes, conheça os moradores e una os dois povos.", 13, Color("e0e1ce"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro_body.add_child(description)
	play_button = _button("Explorar o bosque     ↗", play_requested.emit, true)
	play_button.name = "PlayButton"
	play_button.custom_minimum_size = Vector2(220, 50)
	play_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	intro_body.add_child(play_button)
	var character_button := _button("Escolher personagem  +", character_requested.emit)
	character_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	intro_body.add_child(character_button)
	intro_body.add_child(_text("W A S D  ou setas   caminhar      E   interagir", 10, MUTED))
	caption = _text("—   Respire. O bosque está vivo.", 11, Color("e2e2c9"))
	root.add_child(caption)

func _build_bottom() -> void:
	bottom_player = Control.new()
	bottom_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom_player)
	portrait = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.size = Vector2(40, 52)
	bottom_player.add_child(portrait)
	var name_label := _text("Viajante", 17, CREAM, true)
	name_label.position = Vector2(55, 0)
	bottom_player.add_child(name_label)
	var role := _text("Um passo de cada vez", 9, MUTED)
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
	controls = _text("W A S D / setas  caminhar     Shift  correr     E  interagir", 10, Color("e0e3cd"))
	root.add_child(controls)
	map_panel = _panel(root, Color(0.145, 0.22, 0.17, 0.93), 10)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	map_panel.add_child(box)
	var heading := HBoxContainer.new()
	box.add_child(heading)
	var map_title := _text("BOSQUE DO VENTO", 8, Color("dee2bf"))
	map_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(map_title)
	var map_button := _button("M", map_requested.emit)
	map_button.custom_minimum_size = Vector2(24, 24)
	map_button.tooltip_text = "Ampliar mapa (M)"
	map_button.add_theme_font_size_override("font_size", 9)
	heading.add_child(map_button)
	minimap = ForestMinimap.new()
	box.add_child(minimap)
	box.add_child(_text("● você     • sementes     ○ árvore-mãe", 8, Color("bec8a1")))
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

func _layout() -> void:
	if root == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var mobile := viewport_size.x < 700
	brand.position = Vector2(22 if mobile else 32, 23)
	brand_title.add_theme_font_size_override("font_size", 21 if mobile else 28)
	brand_title.position.x = 38 if mobile else 48
	brand_subtitle.position = Vector2(39 if mobile else 49, 31 if mobile else 38)
	brand_subtitle.add_theme_font_size_override("font_size", 6 if mobile else 8)
	brand_icon.size = Vector2(28, 28) if mobile else Vector2(36, 36)
	toolbar.position = Vector2(viewport_size.x - 155, 28)
	location.visible = viewport_size.x > 1050
	time_label.visible = not location.visible
	time_label.position = Vector2(22 if mobile else 32, 80)
	location.position = Vector2(viewport_size.x / 2.0 - location.size.x / 2.0, 42)
	quest.position = Vector2(20 if mobile else 32, 104)
	var quest_width := 230.0 if mobile else 280.0
	quest_title.custom_minimum_size.x = quest_width - 40
	quest_description.custom_minimum_size.x = quest_width - 40
	quest_note.custom_minimum_size.x = quest_width - 40
	quest.custom_minimum_size.x = quest_width
	quest.size = Vector2(quest_width, 0)
	intro_body.position = Vector2(26 if mobile else viewport_size.x * 0.08, viewport_size.y * (0.39 if mobile else 0.27))
	intro_body.size.x = minf(600, viewport_size.x - intro_body.position.x - 24)
	intro_title.add_theme_font_size_override("font_size", 32 if mobile else (42 if viewport_size.x < 1100 else 48))
	caption.position = Vector2((viewport_size.x - caption.size.x) / 2.0, viewport_size.y - 42)
	bottom_player.position = Vector2(32, viewport_size.y - 84)
	bottom_player.visible = game_started and not mobile
	stamina.size = Vector2(124, 4)
	controls.position = Vector2((viewport_size.x - controls.size.x) / 2.0, viewport_size.y - 42)
	controls.visible = game_started and viewport_size.x > 1050
	minimap.custom_minimum_size = Vector2(124, 82) if mobile else Vector2(168, 112)
	map_panel.reset_size()
	map_panel.position = Vector2(viewport_size.x - map_panel.size.x - (20 if mobile else 32), viewport_size.y - map_panel.size.y - (155 if mobile else 24))
	touch_controls.position = Vector2(24, viewport_size.y - 135)
	touch_controls.size = Vector2(viewport_size.x - 48, 108)
	touch_action.position = Vector2(viewport_size.x - 48 - 64, 25)
	touch_controls.visible = game_started and (mobile or DisplayServer.is_touchscreen_available())
	toast_label.custom_minimum_size.x = minf(460, viewport_size.x - 70)
	toast_panel.reset_size()
	call_deferred("_position_toast")
	if modal != null:
		_layout_modal()

func set_started(resume: bool = false) -> void:
	if resume:
		play_button.text = "Continuar a jornada     ↗"

func show_game() -> void:
	game_started = true
	intro.hide()
	caption.hide()
	quest.show()
	map_panel.show()
	_layout()

func update_quest(collected: Dictionary, complete: bool, peace: bool = false) -> void:
	var count := collected.size()
	seed_counter.text = "%d / 5" % count
	quest_description.text = "A primavera encontrou o caminho de volta." if complete else ("Leve as sementes de volta à árvore-mãe." if count == 5 else "Encontre as sementes levadas pelo vento.")
	quest_note.text = "✦ Bosque restaurado · os reinos estão unidos" if peace else ("✦ Fale com os dois reis para selar a paz" if complete else ("◇ A árvore-mãe é o ponto claro no mapa" if count == 5 else "◇ Procure por pequenos brilhos dourados"))
	for i in 5:
		var filled := collected.has(WorldData.SEEDS[i].id)
		var slot_style := _style(Color("75804e") if filled else Color(0.66, 0.7, 0.55, 0.12), 20, Color(0.6, 0.65, 0.5, 0.3))
		slot_style.set_content_margin_all(0)
		seed_slots[i].add_theme_stylebox_override("panel", slot_style)
		seed_slots[i].get_child(0).add_theme_color_override("font_color", PAPER if filled else Color("a3ab8c"))
	minimap.collected = collected
	minimap.restored = complete
	minimap.queue_redraw()

func update_status(player: ForestPlayer, data: Dictionary, clock: WorldClock = null) -> void:
	var realm: Dictionary = KingdomData.REALMS[KingdomData.realm_at(player.position)]
	var time := clock.label() if clock != null else "Dia 1 · 08:30 · Manhã"
	location.text = "%s     |     %s" % [realm.name, time]
	location.tooltip_text = WorldData.location_name(player.position)
	time_label.text = time
	stamina.value = player.stamina * 100
	controls.text = "W A S D / setas  nadar     Shift  acelerar     E  interagir" if player.swimming else "W A S D / setas  caminhar     Shift  correr     E  interagir"
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
	toast_panel.position = Vector2((viewport_size.x - toast_panel.size.x) / 2.0, viewport_size.y - (210 if viewport_size.x < 700 else 140))

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
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	modal_panel.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var kicker := _text(eyebrow, 9, Color("6b7654"))
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
	var content := _text(body, 13, Color("768068"))
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
	modal_panel.reset_size()
	modal_panel.position = (get_viewport().get_visible_rect().size - modal_panel.size) / 2.0

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
