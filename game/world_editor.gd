class_name WorldEditor
extends CanvasLayer

const LABELS := {"grass":"Grama","dirt":"Estrada de terra","sand":"Areia","stone":"Calçamento","moss":"Pedra com musgo","water":"Rio / lago","cottage":"Casa de campo","timber":"Casa de madeira","stone_house":"Casa de pedra","tavern":"Estalagem","forge":"Ferraria / loja","tower":"Torre","castle":"Castelo","tree":"Árvore verde","autumn_tree":"Árvore de outono","rock":"Rocha","cow":"Vaca","chicken":"Galinha","deer":"Cervo","rabbit":"Coelho","boar":"Javali","bridge":"Ponte sobre o rio","npc":"Morador","select":"Selecionar / mover","erase":"Apagar objeto / pintura","spawn":"Início do jogador"}
var game: ForestGame
var draft: Dictionary = {}
var base_npcs: Dictionary = {}
var tool := "grass"
var appearance := "bento"
var chosen_style := 0
var brush_size := 1
var selection := ""
var canvas: MapCanvas
var root_control: Control
var palette: VBoxContainer
var coordinates: Label
var status: Label
var title: LineEdit
var inspector: VBoxContainer
var undo_button: Button
var redo_button: Button
var file_dialog: FileDialog
var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []
var terrain_before: Dictionary = {}
var terrain_after: Dictionary = {}
var gesture_snapshot: Dictionary = {}
var dirty := false
var previous_mode := "playing"

func setup(source: ForestGame) -> void:
	game=source;layer=40
	_build_ui()
	visible=false

func open() -> void:
	previous_mode=game.mode if game.mode in ["playing","intro"] else "playing"
	game.save_journey()
	game.cancel_building();game.hud.close_dialog()
	game.mode="editor";game.player.active=false;game.world.set_population_active(false)
	game.world.set_process(false)
	game.hud.root.hide()
	if game.hybrid!=null:
		game.hybrid.hide();game.hybrid.set_process(false);game.hybrid.grade.hide()
	if draft.is_empty():
		draft=MapDocument.current.duplicate(true)
		_collect_base_npcs()
	title.text=draft.name
	canvas.center=game.player.position
	visible=true
	canvas.grab_focus()
	canvas.queue_redraw()
	message("Escolha um pincel e desenhe. Use Testar mapa para entrar no seu mundo.")

func close() -> void:
	canvas.finish_stroke()
	if dirty:save_draft(false)
	visible=false
	game.mode=previous_mode
	game.player.active=game.mode=="playing"
	game.world.set_population_active(game.mode=="playing");game.world.set_process(true)
	game.hud.root.show()
	if game.hybrid!=null:
		game.hybrid.show();game.hybrid.set_process(true);game.hybrid.grade.visible=game.shaders_enabled

func _collect_base_npcs() -> void:
	base_npcs.clear()
	for profile in KingdomData.PEOPLE:
		var position: Vector2=KingdomData.point(profile.routine[1].points[0])
		var home: Vector2=KingdomData.point(profile.routine[0].points[0])
		var social: Vector2=KingdomData.point(profile.routine[2].points[0])
		base_npcs[profile.id]={"id":profile.id,"kind":"npc","x":position.x,"y":position.y,"name":profile.name,"appearance":NPCAppearance.identity(profile),"realm":profile.realm,"style":0,"size":130,"home_x":home.x,"home_y":home.y,"work_x":position.x,"work_y":position.y,"social_x":social.x,"social_y":social.y}

func _button(text_value: String, callback: Callable) -> Button:
	var button:=game.hud._button(text_value,callback,true,true)
	button.custom_minimum_size.y=34
	return button

func _build_ui() -> void:
	root_control=Control.new();root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(root_control)
	var background:=ColorRect.new();background.color=Color("18282c");background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root_control.add_child(background)
	var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","top","right","bottom"]:margin.add_theme_constant_override("margin_"+edge,12)
	root_control.add_child(margin)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",10);margin.add_child(column)
	var top:=HBoxContainer.new();top.add_theme_constant_override("separation",8);column.add_child(top)
	var brand:=game.hud._text("ATELIÊ DE MUNDOS",15,Color("f0d69f"));top.add_child(brand)
	title=LineEdit.new();title.placeholder_text="Nome do mapa";title.max_length=80;title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;title.custom_minimum_size.x=150;top.add_child(title)
	title.text_changed.connect(func(value:String):_fork();draft.name=value;dirty=true)
	top.add_child(_button("Salvar",save_draft.bind(true)))
	top.add_child(_button("Importar",choose_import))
	top.add_child(_button("Exportar",choose_export))
	top.add_child(_button("▶ Testar mapa",test_map))
	top.add_child(_button("Fechar · F2",close))
	var body:=HBoxContainer.new();body.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",12);column.add_child(body)
	var sidebar:=ScrollContainer.new();sidebar.custom_minimum_size.x=230;sidebar.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;body.add_child(sidebar)
	var left:=VBoxContainer.new();left.custom_minimum_size.x=220;left.add_theme_constant_override("separation",7);sidebar.add_child(left)
	left.add_child(game.hud._text("CRIE DO SEU JEITO",11,Color("d5c598")))
	var category:=OptionButton.new();category.custom_minimum_size.y=36
	for text_value in ["Terreno e água","Construções","Natureza","Animais","NPCs"]:category.add_item(text_value)
	left.add_child(category);category.item_selected.connect(_category)
	palette=VBoxContainer.new();left.add_child(palette)
	var style:=OptionButton.new()
	for value in ["Terracota e creme","Madeira e verde","Pedra e ardósia","Argila e marrom","Oliva e ameixa","Rústico"]:style.add_item(value)
	style.item_selected.connect(func(value:int):chosen_style=value);left.add_child(style)
	var brush:=OptionButton.new()
	for value in ["Pincel · 1 célula","Pincel · 3 células","Pincel · 5 células","Pincel · 9 células"]:brush.add_item(value)
	brush.item_selected.connect(func(value:int):brush_size=[1,3,5,9][value]);left.add_child(brush)
	for value in ["select","erase","spawn"]:left.add_child(_button(LABELS[value],select_tool.bind(value)))
	var history:=HBoxContainer.new();left.add_child(history)
	undo_button=_button("↶ Desfazer",undo);redo_button=_button("↷ Refazer",redo);history.add_child(undo_button);history.add_child(redo_button)
	left.add_child(HSeparator.new())
	left.add_child(_button("Novo mapa vazio",confirm_new.bind("vazio")))
	left.add_child(_button("Abrir base dos reinos",confirm_new.bind("reinos")))
	left.add_child(_button("Recuperar rascunho",recover_draft))
	left.add_child(_button("Voltar à aventura original",restore_original))
	left.add_child(_button("Ver continente",func():canvas.center=MapDocument.LIMIT/2;canvas.zoom=0.04;canvas.queue_redraw()))
	left.add_child(_button("Ir ao início",func():canvas.center=Vector2(draft.spawn[0],draft.spawn[1]);canvas.zoom=0.30;canvas.queue_redraw()))
	inspector=VBoxContainer.new();left.add_child(inspector)
	canvas=MapCanvas.new();canvas.editor=self;canvas.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_child(canvas)
	var footer:=HBoxContainer.new();column.add_child(footer)
	status=game.hud._text("",11,Color("e8d9b7"));status.size_flags_horizontal=Control.SIZE_EXPAND_FILL;status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;footer.add_child(status)
	coordinates=game.hud._text("",11,Color("c5d2c0"));footer.add_child(coordinates)
	column.add_child(game.hud._text("Clique / arraste: pintar · Botão direito ou meio: mover visão · Roda: zoom · WASD: navegar · Ctrl+Z / Ctrl+Y: histórico · Delete: apagar seleção",11,Color("b4c5bd")))
	_category(0);_history_buttons()

func _category(index:int) -> void:
	for node in palette.get_children():node.queue_free()
	var choices:Array=[MapDocument.TERRAIN,MapDocument.STRUCTURES,MapDocument.NATURE,MapDocument.ANIMALS,MapDocument.FACES][index]
	for value:String in choices:
		var button:=_button(LABELS.get(value,value.capitalize()),func():appearance=value if index==4 else appearance;select_tool("npc" if index==4 else value))
		if index==4:
			button.text={"bento":"Ferreiro","lia":"Comerciante","tomas":"Guarda","iris":"Herbalista","eron":"Sábio","aurel":"Rei loiro","caio":"Rei moreno","mila":"Camponesa","farmer":"Agricultor"}[value]
			var sheet:=NPCAppearance.sheet(value)
			if not sheet.is_empty():
				button.icon=sheet.frames.get_frame_texture("idle_down",0);button.expand_icon=true;button.add_theme_constant_override("icon_max_width",27)
		palette.add_child(button)
	if index<4:select_tool(choices[0])
	else:appearance=choices[0];select_tool("npc")

func select_tool(value:String) -> void:
	tool=value
	message("Ferramenta: "+LABELS.get(value,value)+(" · Clique em um objeto para selecionar; clique no destino para mover." if value=="select" else ""))
	if canvas!=null:canvas.queue_redraw()

func message(value:String) -> void:
	if status!=null:status.text=value

func _fork() -> void:
	if draft.id=="reinos":draft.id=MapDocument.new_id()

func begin_stroke() -> void:
	terrain_before.clear();terrain_after.clear()
	gesture_snapshot={}

func end_stroke() -> void:
	if not terrain_after.is_empty():
		_commit({"type":"terrain","before":terrain_before.duplicate(),"after":terrain_after.duplicate()})
	elif not gesture_snapshot.is_empty() and gesture_snapshot!=draft:
		_commit({"type":"document","before":gesture_snapshot,"after":draft.duplicate(true)})
	terrain_before.clear();terrain_after.clear();gesture_snapshot={}

func _snapshot() -> void:
	if gesture_snapshot.is_empty():gesture_snapshot=draft.duplicate(true)
	_fork()

func paint_at(point:Vector2) -> bool:
	if point.x<64 or point.y<64 or point.x>MapDocument.LIMIT.x-64 or point.y>MapDocument.LIMIT.y-64:return false
	if tool in MapDocument.TERRAIN:
		_fork()
		var center:=MapDocument.cell_at(point)
		var half:=brush_size/2
		for y in range(-half,half+1):
			for x in range(-half,half+1):
				var cell:=center+Vector2i(x,y)
				if cell.x<1 or cell.y<1 or cell.x>=249 or cell.y>=199:continue
				var key:=MapDocument.cell_key(cell)
				if not terrain_before.has(key):terrain_before[key]=draft.terrain.get(key)
				draft.terrain[key]=tool;terrain_after[key]=tool
		dirty=true
		return true
	if tool=="select":
		var hit:=hit_test(point)
		if not hit.is_empty():selection=hit;_show_inspector();return true
		if not selection.is_empty():return move_selected(point)
		return false
	if tool=="erase":
		var hit:=hit_test(point)
		if not hit.is_empty():selection=hit;delete_selected();return true
		var key:=MapDocument.cell_key(MapDocument.cell_at(point))
		if draft.terrain.has(key):
			_snapshot();draft.terrain.erase(key);dirty=true;return true
		return false
	if tool=="spawn":
		if not valid_at(point):message("Escolha um ponto livre e seco para começar.");return false
		_snapshot();draft.spawn=[point.x,point.y];dirty=true;return true
	if tool.begins_with("anchor_"):
		var obj:=selected_object()
		if obj.get("kind")!="npc":return false
		_snapshot()
		obj=editable_selected()
		var place:=tool.trim_prefix("anchor_")
		obj[place+"_x"]=point.x;obj[place+"_y"]=point.y
		dirty=true;message("Ponto de "+{"home":"casa","work":"trabalho","social":"passeio"}[place]+" definido.");return true
	if not valid_at(point):message("Esse objeto precisa de espaço livre em terra firme.");return false
	if draft.objects.size()>=5000:message("Este mapa já tem 5.000 objetos. Apague alguns antes de colocar mais.");return false
	_snapshot()
	var at:=point.snapped(Vector2.ONE*32)
	var obj:=MapDocument.clean_object({"id":"obj_"+str(Time.get_ticks_usec()),"kind":tool,"x":at.x,"y":at.y,"name":LABELS.get(tool,"Morador"),"style":chosen_style,"appearance":appearance,"realm":KingdomData.realm_at(at),"home_x":at.x,"home_y":clampf(at.y+128,64,12736),"work_x":at.x,"work_y":at.y,"social_x":clampf(at.x+192,64,15936),"social_y":at.y})
	if tool=="npc":obj.name={"bento":"Ferreiro","lia":"Comerciante","tomas":"Guarda","iris":"Herbalista","eron":"Sábio","aurel":"Rei Aurel","caio":"Rei Caio","mila":"Camponesa","farmer":"Agricultor"}[appearance]
	draft.objects.append(obj);selection=obj.id;dirty=true;_show_inspector()
	return true

func valid_at(point:Vector2,ignore_id:String="") -> bool:
	var at:=point.snapped(Vector2.ONE*32)
	if at.x<64 or at.y<64 or at.x>15936 or at.y>12736:return false
	if tool in MapDocument.TERRAIN or tool in ["select","erase"]:return true
	var kind: String=draft.terrain.get(MapDocument.cell_key(MapDocument.cell_at(at)),"")
	if tool!="bridge" and (kind=="water" or kind.is_empty() and draft.base=="reinos" and absf(at.x-WorldData.river_x(at.y))<180):return false
	if tool in MapDocument.STRUCTURES or tool=="spawn":
		var dim:=MapDocument.building_size(tool) if tool in MapDocument.STRUCTURES else Vector2(24,24)
		var rect:=Rect2(at-Vector2(dim.x/2,dim.y),dim)
		if tool=="bridge":rect=Rect2(at-dim/2,dim)
		if not Rect2(Vector2.ONE*32,MapDocument.LIMIT-Vector2.ONE*64).encloses(rect):return false
		for sample in [rect.position,rect.end,Vector2(rect.position.x,rect.end.y),Vector2(rect.end.x,rect.position.y),rect.get_center()]:
			var ground:String=draft.terrain.get(MapDocument.cell_key(MapDocument.cell_at(sample)),"")
			if tool!="bridge" and (ground=="water" or ground.is_empty() and draft.base=="reinos" and absf(sample.x-WorldData.river_x(sample.y))<180):return false
		for building in _buildings_in_draft():
			if building.id==ignore_id:continue
			if rect.grow(8).intersects(KingdomData.building_rect(building)):return false
	else:
		for building in _buildings_in_draft():
			if building.id!=ignore_id and KingdomData.building_rect(building).grow(16).has_point(at):return false
	return true

func _buildings_in_draft() -> Array[Dictionary]:
	var result:Array[Dictionary]=[]
	if draft.base=="reinos":
		for i in KingdomData.BUILDINGS.size():
			var id:="base_building_"+str(i)
			if not draft.removed.has(id):result.append(KingdomData.BUILDINGS[i].merged({"id":id}))
	for obj in draft.objects:
		if obj.kind in MapDocument.BUILDINGS:result.append({"id":obj.id,"tile":Vector2(obj.x,obj.y)/64,"size":MapDocument.building_size(obj.kind)})
	return result

func hit_test(point:Vector2) -> String:
	for i in range(draft.objects.size()-1,-1,-1):
		var obj:Dictionary=draft.objects[i]
		if obj.kind=="bridge" and MapDocument.bridge_rect(obj).has_point(point):return obj.id
		if obj.kind in MapDocument.BUILDINGS:
			var dim:=MapDocument.building_size(obj.kind)
			if Rect2(Vector2(obj.x,obj.y)-Vector2(dim.x/2,dim.y),dim).has_point(point):return obj.id
		elif point.distance_to(Vector2(obj.x,obj.y))<maxf(24,14/canvas.zoom):return obj.id
	if draft.base=="reinos":
		for id in base_npcs:
			var obj:Dictionary=draft.npcs.get(id,base_npcs[id])
			if not draft.removed.has(id) and point.distance_to(Vector2(obj.x,obj.y))<maxf(24,14/canvas.zoom):return id
		for building in _buildings_in_draft():
			if KingdomData.building_rect(building).has_point(point):return building.id
	return ""

func selected_object() -> Dictionary:
	for obj in draft.objects:
		if obj.id==selection:return obj
	if draft.npcs.has(selection):return draft.npcs[selection]
	return base_npcs.get(selection,{}) if draft.base=="reinos" and not draft.removed.has(selection) else {}

func editable_selected() -> Dictionary:
	if base_npcs.has(selection) and not draft.npcs.has(selection):draft.npcs[selection]=base_npcs[selection].duplicate(true)
	return selected_object()

func move_selected(point:Vector2) -> bool:
	var obj:=selected_object()
	if obj.is_empty():message("Para mover uma casa da base, apague-a e coloque um dos novos modelos.");return false
	_snapshot()
	obj=editable_selected()
	var at:=point.snapped(Vector2.ONE*32)
	var old_tool:=tool
	tool=obj.kind
	var valid:=valid_at(at,selection)
	tool=old_tool
	if not valid:return false
	var delta:=at-Vector2(obj.x,obj.y)
	obj.x=at.x;obj.y=at.y
	if obj.kind=="npc":
		for place in ["home","work","social"]:
			obj[place+"_x"]=clampf(obj.get(place+"_x",at.x)+delta.x,64,15936)
			obj[place+"_y"]=clampf(obj.get(place+"_y",at.y)+delta.y,64,12736)
	dirty=true;_show_inspector();return true

func delete_selected() -> void:
	if selection.is_empty():return
	_snapshot()
	for i in draft.objects.size():
		if draft.objects[i].id==selection:draft.objects.remove_at(i);selection="";dirty=true;_show_inspector();return
	draft.removed[selection]=true;draft.npcs.erase(selection);selection="";dirty=true;_show_inspector()

func _show_inspector() -> void:
	for node in inspector.get_children():node.queue_free()
	var obj:=selected_object()
	if obj.is_empty():return
	inspector.add_child(HSeparator.new());inspector.add_child(game.hud._text("OBJETO SELECIONADO",10,Color("e0c998")))
	var field:=LineEdit.new();field.text=obj.name;field.max_length=60;inspector.add_child(field)
	field.text_submitted.connect(func(value:String):begin_stroke();_snapshot();editable_selected().name=value;dirty=true;end_stroke();canvas.queue_redraw())
	inspector.add_child(game.hud._text("Renomeie e pressione Enter.",10,Color("c1c6b2")))
	inspector.add_child(_button("Mover: clique no destino",select_tool.bind("select")))
	inspector.add_child(_button("Apagar selecionado",func():begin_stroke();delete_selected();end_stroke();canvas.queue_redraw()))
	if obj.kind=="npc":
		for place in ["home","work","social"]:inspector.add_child(_button({"home":"Marcar casa / descanso","work":"Marcar trabalho","social":"Marcar passeio"}[place],select_tool.bind("anchor_"+place)))
		inspector.add_child(game.hud._text("Rotina: casa → trabalho → passeio.\nOs horários variam por morador.",10,Color("c1c6b2")))

func _commit(change:Dictionary) -> void:
	undo_stack.append(change);redo_stack.clear()
	if undo_stack.size()>30:undo_stack.pop_front()
	_history_buttons()

func _apply_change(change:Dictionary,field:String) -> void:
	if change.type=="terrain":
		for key in change[field]:
			if change[field][key]==null:draft.terrain.erase(key)
			else:draft.terrain[key]=change[field][key]
	else:draft=change[field].duplicate(true)
	selection="";dirty=true;title.text=draft.name;_show_inspector();canvas.queue_redraw()

func undo() -> void:
	canvas.finish_stroke()
	if undo_stack.is_empty():return
	var change:Dictionary=undo_stack.pop_back();_apply_change(change,"before");redo_stack.append(change);_history_buttons()

func redo() -> void:
	if redo_stack.is_empty():return
	var change:Dictionary=redo_stack.pop_back();_apply_change(change,"after");undo_stack.append(change);_history_buttons()

func _history_buttons() -> void:
	if undo_button!=null:undo_button.disabled=undo_stack.is_empty();redo_button.disabled=redo_stack.is_empty()

func save_draft(feedback:bool=true) -> bool:
	canvas.finish_stroke();_fork()
	var error:=MapDocument.write_file(MapDocument.DRAFT_PATH,draft)
	if error==OK:error=MapDocument.write_file("user://maps/"+draft.id+".json",draft)
	if error!=OK:message("Não foi possível salvar. Você pode exportar para outra pasta.");return false
	dirty=false
	if feedback:message("Mapa salvo neste computador. Use Exportar para criar um arquivo na pasta que você escolher.")
	return true

func confirm_new(base:String) -> void:
	var dialog:=ConfirmationDialog.new();dialog.title="Abrir outro mapa";dialog.dialog_text="Isso substitui o rascunho em edição. Salve ou exporte antes para guardá-lo. Sua aventura atual fica preservada."
	dialog.ok_button_text="Abrir mapa";dialog.cancel_button_text="Continuar editando";add_child(dialog)
	dialog.confirmed.connect(func():replace_document(MapDocument.blank() if base=="vazio" else MapDocument.original());dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free);dialog.popup_centered()

func replace_document(doc:Dictionary) -> void:
	draft=doc.duplicate(true);_fork();selection="";undo_stack.clear();redo_stack.clear();dirty=true
	title.text=draft.name;canvas.center=Vector2(draft.spawn[0],draft.spawn[1]);canvas.zoom=0.30;_collect_base_npcs();_history_buttons();_show_inspector();canvas.queue_redraw()
	message("Mapa aberto no ateliê. As mudanças entram no jogo quando você clicar em Testar mapa.")

func recover_draft() -> void:
	var result:=MapDocument.read_file(MapDocument.DRAFT_PATH)
	if result.ok:replace_document(result.document)
	else:message("Ainda não há um rascunho salvo válido neste computador.")

func _file_picker(mode:FileDialog.FileMode) -> FileDialog:
	if file_dialog!=null:file_dialog.queue_free()
	file_dialog=FileDialog.new();file_dialog.access=FileDialog.ACCESS_FILESYSTEM;file_dialog.file_mode=mode;file_dialog.filters=PackedStringArray(["*.json ; Mapas de Entre Reinos"]);file_dialog.title="Exportar mapa" if mode==FileDialog.FILE_MODE_SAVE_FILE else "Importar mapa"
	add_child(file_dialog);file_dialog.popup_centered_ratio(0.75)
	return file_dialog

func choose_import() -> void:
	_file_picker(FileDialog.FILE_MODE_OPEN_FILE).file_selected.connect(func(path:String):var result:=MapDocument.read_file(path);replace_document(result.document) if result.ok else message(result.message))

func choose_export() -> void:
	canvas.finish_stroke();_fork()
	_file_picker(FileDialog.FILE_MODE_SAVE_FILE).file_selected.connect(func(path:String):var error:=MapDocument.write_file(path if path.ends_with(".json") else path+".json",draft);message("Mapa exportado. Você pode compartilhar esse JSON e importá-lo em outro computador." if error==OK else "Não foi possível gravar nessa pasta."))
	file_dialog.current_file=draft.id+".json"

func test_map() -> void:
	canvas.finish_stroke()
	var checked:=MapDocument.validate(draft)
	if not checked.ok:message(checked.message);return
	if not valid_spawn():message("Marque o início do jogador em um ponto seco fora das construções.");return
	if not save_draft(false):return
	if game.persistence and MapDocument.write_file(MapDocument.ACTIVE_PATH,draft)!=OK:message("Não foi possível ativar o mapa salvo.");return
	visible=false
	game.apply_map(draft)

func restore_original() -> void:
	if dirty and not save_draft(false):return
	var doc:=MapDocument.original()
	if game.persistence and MapDocument.write_file(MapDocument.ACTIVE_PATH,doc)!=OK:message("Não foi possível ativar o mapa original.");return
	draft={};visible=false
	game.apply_map(doc)

func valid_spawn() -> bool:
	var previous:=tool;tool="spawn"
	var valid:=valid_at(Vector2(draft.spawn[0],draft.spawn[1]));tool=previous
	return valid

func _unhandled_key_input(event:InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo:return
	if get_viewport().gui_get_focus_owner() is LineEdit:return
	if event.physical_keycode==KEY_F2 or event.physical_keycode==KEY_ESCAPE:close()
	elif event.ctrl_pressed and event.physical_keycode==KEY_Z:undo()
	elif event.ctrl_pressed and event.physical_keycode==KEY_Y:redo()
	elif event.ctrl_pressed and event.physical_keycode==KEY_S:save_draft()
	elif event.physical_keycode==KEY_DELETE:begin_stroke();delete_selected();end_stroke();canvas.queue_redraw()
	else:return
	get_viewport().set_input_as_handled()
