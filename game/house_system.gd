class_name HouseSystem
extends Node

var game: ForestGame
var room: HouseInterior
var active_id := ""
var return_point := Vector2.ZERO
var outside_camera: Camera3D
var outside_environment: Environment
var pending_location: Dictionary = {}
var chosen_style := "common"
var chosen_seed := 42
var chosen_turn := 0
var plan_enabled := false
var portal_root: Node2D
var fade_layer:CanvasLayer
var fade:ColorRect
var fade_tween:Tween

func setup(source: ForestGame) -> void:
	game=source;bind_world()
	fade_layer=CanvasLayer.new();fade_layer.layer=35;add_child(fade_layer)
	fade=ColorRect.new();fade.color=Color.TRANSPARENT;fade.mouse_filter=Control.MOUSE_FILTER_IGNORE;fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);fade_layer.add_child(fade)
	fade.hide()

func transition() -> void:
	if fade==null:return
	if fade_tween!=null:fade_tween.kill()
	fade.show()
	fade.color=Color(0.04,0.05,0.06,0.85)
	fade_tween=create_tween();fade_tween.tween_property(fade,"color:a",0.0,0.28)
	fade_tween.tween_callback(fade.hide)

func update_hud() -> void:
	if not inside():return
	game.hud.location.text=room.data.name+" · Interior  |  "+game.world.clock.label()
	game.hud.location.tooltip_text="E na porta para retornar ao continente"
	game.hud.controls.text="WASD mover   E usar porta, cama ou balcão   I inventário"
	game.hud.minimap.player_position=return_point;game.hud.minimap.queue_redraw()

func inside() -> bool:
	return is_instance_valid(room)

func bind_world() -> void:
	if is_instance_valid(portal_root):portal_root.queue_free()
	portal_root=Node2D.new();portal_root.name="HouseDoors";game.world.add_child(portal_root)
	for data in KingdomData.buildings():
		if not data.kind in HouseKit.KINDS or data.kind in ["forge","tavern"]:continue
		var area:=game.world._interaction_area(HouseKit.approach(data),65)
		area.set_meta("interaction",{"kind":"house_door","id":data.id,"name":"Entrar · "+data.name,"range":65.0})
		portal_root.add_child(area)

func building(id: String) -> Dictionary:
	if game.rpg.houses.has(id):
		var home:Dictionary=game.rpg.houses[id]
		return HouseKit.from_home(id,home,game.rpg) if home.stage==3 else {}
	for data in KingdomData.buildings():
		if data.id==id and data.kind in HouseKit.KINDS:return data
	return {}

func service_building(service: String, kind: String) -> String:
	if inside():return ""
	var entry:=KingdomData.service_building(service,kind)
	if not entry.is_empty():return entry.id
	for data in KingdomData.buildings():
		if data.kind==("forge" if kind=="shop" else "tavern") and data.id==service:return data.id
	return ""

func service_for(data: Dictionary) -> String:
	var town:=KingdomData.service_town(data.get("id",""))
	if not town.is_empty():return town
	return data.get("id", "")

func enter(id: String, restored: bool = false) -> bool:
	if inside():return false
	var data:=building(id)
	if data.is_empty():return false
	var entry:=HouseKit.approach(data)
	# The service area includes the original marketplace approach.
	if not restored and game.player.position.distance_to(entry)>190:
		game.hud.toast("Aproxime-se da porta para entrar.");return false
	if data.kind in ["forge","tavern"] and game.politics!=null and not game.politics.trade_allowed(service_for(data)):return false
	game.cancel_building()
	if game.mode=="dialog":game.close_dialog()
	return_point=game.world.safe_position(game.player.position)
	active_id=id
	game.world.set_population_active(false)
	game.world.process_mode=Node.PROCESS_MODE_DISABLED
	game.player.process_mode=Node.PROCESS_MODE_ALWAYS;game.world.clock.process_mode=Node.PROCESS_MODE_ALWAYS
	game.player.indoors=true;game.player.restore_surface()
	room=HouseInterior.new();room.name="HouseInterior";game.add_child(room);room.setup(self,data)
	game.player.reparent(room,false);game.player.visible=game.hybrid==null
	game.player.position=room.spawn_point;game.player.velocity=Vector2.ZERO;game.player.view_yaw=0
	game.world.clock.active=true
	if game.hybrid!=null:
		outside_camera=game.hybrid.camera;outside_camera.current=false
		outside_environment=game.hybrid.atmosphere.environment
		game.hybrid.atmosphere.environment=room.environment
		game.hybrid.hide();game.hybrid.set_process(false);game.hybrid.grade.hide()
		game.hybrid.process_mode=Node.PROCESS_MODE_DISABLED
		game.hybrid.camera=room.camera;room.camera.make_current()
		room.create_actor()
	else:
		game.world.hide();game.camera.enabled=true;game.camera.limit_left=-10000;game.camera.limit_top=-10000
		game.camera.reset_smoothing()
	game.mode="playing";game.player.active=true;game.hud.close_dialog();game.hud.toast(data.name+" · E na porta para sair",4)
	transition();update_hud()
	game.save_journey()
	return true

func leave(save: bool = true) -> void:
	if not inside():return
	if game.mode=="dialog":game.close_dialog()
	game.player.indoors=false
	game.player.reparent(game.world.entities,false);game.player.visible=true
	game.player.position=return_point;game.player.velocity=Vector2.ZERO
	game.player.process_mode=Node.PROCESS_MODE_INHERIT;game.world.clock.process_mode=Node.PROCESS_MODE_INHERIT
	game.world.process_mode=Node.PROCESS_MODE_INHERIT
	if game.hybrid!=null:
		game.hybrid.camera=outside_camera;outside_camera.make_current()
		game.hybrid.process_mode=Node.PROCESS_MODE_INHERIT
		game.hybrid.atmosphere.environment=outside_environment
		game.hybrid.show();game.hybrid.set_process(true);game.hybrid.grade.visible=game.shaders_enabled
		game.hybrid.snap_camera();game.hybrid.last_daylight=Color(-1,-1,-1)
	else:game.world.show();game.camera.limit_left=0;game.camera.limit_top=0;game.camera.reset_smoothing()
	room.free();room=null;active_id=""
	game.player.restore_surface();game.world.ensure_region(game.player.position,true)
	game.world.set_population_active(game.mode=="playing");game.player.active=game.mode=="playing"
	transition()
	if save:game.save_journey()

func location_data() -> Dictionary:
	return {"house":active_id,"x":game.player.position.x,"y":game.player.position.y} if inside() else pending_location.duplicate()

func restore_location(data: Variant) -> void:
	pending_location.clear()
	if data is Dictionary and data.get("house") is String and ResourceProgress.number(data.get("x")) and ResourceProgress.number(data.get("y")):
		pending_location={"house":data.house,"x":float(data.x),"y":float(data.y)}

func resume() -> void:
	if pending_location.is_empty():return
	var saved:=pending_location.duplicate();pending_location.clear()
	if enter(saved.house,true):
		var position:=Vector2(saved.x,saved.y)
		game.player.position=position if room.walkable(position) else room.spawn_point

func interaction() -> Dictionary:
	if not inside():return {}
	return room.interaction(game.player.position)

func interact(item: Dictionary) -> void:
	match item.get("kind", ""):
		"house_exit":leave()
		"house_bed":
			if game.rpg.houses.has(active_id) and game.rpg.houses[active_id].owner=="player":game.rest_until_morning()
			elif room.data.kind=="tavern":game.open_inn(service_for(room.data))
			else:game.hud.toast("Esta cama pertence aos moradores.")
		"house_counter":
			if room.data.kind=="forge":game.open_shop(service_for(room.data))
			elif room.data.kind=="tavern":game.open_inn(service_for(room.data))
			else:game.hud.toast("Um lar acolhedor, protegido do clima lá fora.")

func show_catalog() -> void:
	if inside():game.hud.toast("Saia da casa para construir no continente.");return
	if game.rpg.houses.has("home_player"):game.open_house("home_player");return
	var actions:Array[Dictionary]=[]
	for id in HouseKit.IDS:
		var kit:=HouseKit.definition(id)
		actions.append({"label":kit.title+" · "+kit.description,"name":"house_style_"+id,"callback":select_style.bind(id)})
	actions.append({"label":"Voltar ao catálogo","callback":game.construction.show_catalog})
	game._open_dialog("KITS MODULARES","Escolha seu lar","Cada kit combina fundação, fachadas, janelas, porta, telhado, chaminé e varanda. A prévia mostra o tamanho e a orientação antes de reservar. O terreno custa 20 moedas; a obra usa as três etapas de materiais já conhecidas.",actions,"house_kits")

func select_style(id: String) -> void:
	chosen_style=id;chosen_seed=posmod((MapDocument.current.id+id).hash(),2147483647);chosen_turn=0;plan_enabled=true
	game.start_building()

func options() -> Dictionary:
	return {"house_style":chosen_style,"house_seed":chosen_seed,"house_turn":chosen_turn} if plan_enabled else {}

func footprint_at(point: Vector2) -> Rect2:
	var size:=HouseKit.size_for(chosen_style,chosen_seed,chosen_turn) if plan_enabled else Vector2(192,128)
	var corner:=(point-Vector2(size.x/2,size.y)).snapped(Vector2.ONE*WorldGrid.CELL)
	return Rect2(corner,size)

func snap(point: Vector2) -> Vector2:
	var rect:=footprint_at(point)
	return Vector2(rect.get_center().x,rect.end.y)

func preview_data(point: Vector2) -> Dictionary:
	var rect:=footprint_at(point)
	return {"id":"house_preview","name":"Meu lar","kind":"timber","tile":Vector2(rect.get_center().x,rect.end.y)/WorldGrid.CELL,"size":rect.size,"realm":"aurelia"}.merged(options())
