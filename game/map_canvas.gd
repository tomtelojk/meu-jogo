class_name MapCanvas
extends Control

var editor: WorldEditor
var center:=Vector2(4608,4480)
var zoom:=0.30
var panning:=false
var drawing:=false
var hover_world:=Vector2.ZERO
var last_cell:=Vector2i(-1,-1)
const COLORS := {"grass":Color("6b9450"),"dirt":Color("b68d64"),"sand":Color("d9c28b"),"stone":Color("929b99"),"moss":Color("747f6a"),"water":Color("4c9fa9")}

func _ready()->void:
	mouse_default_cursor_shape=Control.CURSOR_CROSS
	focus_mode=Control.FOCUS_ALL
	clip_contents=true

func to_screen(point:Vector2)->Vector2:
	return (point-center)*zoom+size/2

func to_world(point:Vector2)->Vector2:
	return (point-size/2)/zoom+center

func _process(delta:float)->void:
	if not editor.visible:return
	if has_focus() and not panning:
		var direction:=Input.get_vector("move_left","move_right","move_up","move_down")
		if direction!=Vector2.ZERO:
			center=(center+direction*delta*650/zoom).clamp(Vector2.ZERO,MapDocument.LIMIT)
			queue_redraw()
	if drawing and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):finish_stroke()

func _gui_input(event:InputEvent)->void:
	if event is InputEventMouseButton:
		grab_focus()
		if event.button_index in [MOUSE_BUTTON_MIDDLE,MOUSE_BUTTON_RIGHT]:panning=event.pressed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var anchor:=to_world(event.position)
			zoom=clampf(zoom*(1.2 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1/1.2),0.025,1.5)
			center+=anchor-to_world(event.position)
			queue_redraw()
		elif event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed:
				editor.begin_stroke()
				drawing=true
				last_cell=Vector2i(-1,-1)
				_paint(to_world(event.position))
			else:finish_stroke()
		accept_event()
	elif event is InputEventMouseMotion:
		if panning:center=(center-event.relative/zoom).clamp(Vector2.ZERO,MapDocument.LIMIT)
		hover_world=to_world(event.position)
		editor.coordinates.text="X %d  ·  Y %d   |   Zoom %d%%"%[hover_world.x,hover_world.y,zoom*100]
		if drawing:_paint(hover_world)
		queue_redraw()

func _paint(point:Vector2)->void:
	var cell:=MapDocument.cell_at(point)
	if cell==last_cell:return
	if last_cell.x>=0 and editor.tool in MapDocument.TERRAIN:
		var distance:=maxi(absi(cell.x-last_cell.x),absi(cell.y-last_cell.y))
		for i in range(1,distance):editor.paint_at(Vector2(last_cell).lerp(Vector2(cell),float(i)/distance)*64+Vector2.ONE*32)
	last_cell=cell
	editor.paint_at(point)
	if not editor.tool in MapDocument.TERRAIN:drawing=false;editor.end_stroke()
	queue_redraw()

func finish_stroke()->void:
	if drawing:editor.end_stroke()
	drawing=false
	last_cell=Vector2i(-1,-1)

func _draw()->void:
	if editor==null:return
	draw_rect(Rect2(Vector2.ZERO,size),Color("192b2d"))
	var region:=Rect2(to_world(Vector2.ZERO),size/zoom)
	var map_rect:=Rect2(to_screen(Vector2.ZERO),MapDocument.LIMIT*zoom)
	draw_rect(map_rect,Color("77945b"))
	if editor.draft.base=="reinos":
		for town in KingdomData.SETTLEMENTS:
			draw_circle(to_screen(town.position),1400*zoom,Color(0.80,0.78,0.48,0.16))
		for path in KingdomData.paths():
			var points:=PackedVector2Array()
			for p in path:points.append(to_screen(p))
			draw_polyline(points,Color("b99b6b"),maxf(1.0,88*zoom),true)
		var river:=PackedVector2Array()
		for i in 201:
			var y:=i*64.0
			river.append(to_screen(Vector2(WorldData.river_x(y),y)))
		draw_polyline(river,COLORS.water,maxf(1.0,360*zoom),true)
	# Cull tile work to the visible rectangle; zooming out samples a coarse grid.
	var start:=MapDocument.cell_at(region.position).clamp(Vector2i.ZERO,Vector2i(249,199))
	var end:=MapDocument.cell_at(region.end).clamp(Vector2i.ZERO,Vector2i(249,199))
	for y in range(start.y,end.y+1):
		for x in range(start.x,end.x+1):
			var cell:=Vector2i(x,y)
			var kind:String=editor.draft.terrain.get(MapDocument.cell_key(cell),"")
			if kind.is_empty():continue
			draw_rect(Rect2(to_screen(Vector2(cell)*64),Vector2.ONE*(64*zoom+0.5)),COLORS[kind])
	if editor.draft.base=="reinos":
		for i in KingdomData.BUILDINGS.size():
			if editor.draft.removed.has("base_building_"+str(i)):continue
			var data:Dictionary=KingdomData.BUILDINGS[i]
			var rect:=KingdomData.building_rect(data)
			_building(rect,data.kind,posmod(String(data.name).hash(),6),"base_building_"+str(i))
		for id in editor.base_npcs:
			if editor.draft.removed.has(id):continue
			var obj:Dictionary=editor.draft.npcs.get(id,editor.base_npcs[id])
			_object(obj)
	for obj in editor.draft.objects:_object(obj)
	if zoom>0.18:
		for x in range(start.x,end.x+2):draw_line(to_screen(Vector2(x*64,start.y*64)),to_screen(Vector2(x*64,(end.y+1)*64)),Color(0.05,0.15,0.12,0.18))
		for y in range(start.y,end.y+2):draw_line(to_screen(Vector2(start.x*64,y*64)),to_screen(Vector2((end.x+1)*64,y*64)),Color(0.05,0.15,0.12,0.18))
	draw_rect(map_rect,Color("d7cda8"),false,2)
	var spawn:=to_screen(Vector2(editor.draft.spawn[0],editor.draft.spawn[1]))
	draw_circle(spawn,8,Color("f5df99"));draw_line(spawn-Vector2(13,0),spawn+Vector2(13,0),Color.WHITE,2);draw_line(spawn-Vector2(0,13),spawn+Vector2(0,13),Color.WHITE,2)
	if Rect2(Vector2.ZERO,size).has_point(get_local_mouse_position()):
		var cell:=MapDocument.cell_at(hover_world)
		var radius:=editor.brush_size/2
		var rect:=Rect2(to_screen(Vector2(cell-Vector2i(radius,radius))*64),Vector2.ONE*editor.brush_size*64*zoom)
		if editor.tool in MapDocument.STRUCTURES:
			var at:=hover_world.snapped(Vector2.ONE*32)
			var dim:=MapDocument.building_size(editor.tool)
			rect=Rect2(to_screen(at-Vector2(dim.x/2,dim.y)),dim*zoom)
			if editor.tool=="bridge":rect.position=to_screen(at-dim/2)
		var valid:=editor.valid_at(hover_world)
		var color:=Color("e9d19a") if valid else Color("ef8274")
		draw_rect(rect,Color(color,0.15));draw_rect(rect,color,false,2)
	# Selected NPC's home/work/social anchors are visible and editable.
	var selected:=editor.selected_object()
	if selected.get("kind")=="npc":
		for place in ["home","work","social"]:
			var at:=to_screen(Vector2(selected.get(place+"_x",selected.x),selected.get(place+"_y",selected.y)))
			draw_circle(at,5,Color("f4d795"))
			draw_string(ThemeDB.fallback_font,at+Vector2(8,-5),{"home":"Casa","work":"Trabalho","social":"Passeio"}[place],HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("fff0c2"))

func _building(rect:Rect2,kind:String,style:int,id:String)->void:
	var draw_at:=Rect2(to_screen(rect.position),rect.size*zoom)
	if not draw_at.grow(15).intersects(Rect2(Vector2.ZERO,size)):return
	var roof_color:Color=BuildingVisual.PALETTES[style][1]
	draw_rect(draw_at.grow(2),Color("3e4938"))
	draw_rect(draw_at,roof_color)
	draw_line(Vector2(draw_at.get_center().x,draw_at.position.y),Vector2(draw_at.get_center().x,draw_at.end.y),roof_color.lightened(0.22),maxf(1,zoom*6))
	if id==editor.selection:draw_rect(draw_at.grow(4),Color("ffe0a4"),false,2)
	if kind in ["forge","tavern","castle","tower"] and zoom>0.15:
		draw_string(ThemeDB.fallback_font,draw_at.position-Vector2(0,5),{"forge":"Ferraria","tavern":"Estalagem","castle":"Castelo","tower":"Torre"}[kind],HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("fff0c2"))

func _object(obj:Dictionary)->void:
	var at:=to_screen(Vector2(obj.x,obj.y))
	if obj.kind=="bridge":
		var rect:=MapDocument.bridge_rect(obj)
		draw_rect(Rect2(to_screen(rect.position),rect.size*zoom),Color("c0a375"))
		for i in 17:draw_line(to_screen(rect.position+Vector2(i*32,0)),to_screen(rect.position+Vector2(i*32,96)),Color("796743"),maxf(1,zoom*2))
		if obj.id==editor.selection:draw_rect(Rect2(to_screen(rect.position),rect.size*zoom).grow(3),Color("ffe0a4"),false,2)
		return
	if obj.kind in MapDocument.BUILDINGS:
		var dim:=MapDocument.building_size(obj.kind)
		_building(Rect2(Vector2(obj.x,obj.y)-Vector2(dim.x/2,dim.y),dim),obj.kind,obj.style,obj.id)
		return
	if not Rect2(Vector2.ZERO,size).grow(40).has_point(at):return
	if obj.kind=="npc":
		var sheet:=NPCAppearance.sheet(obj.appearance)
		if not sheet.is_empty() and zoom>0.15:
			var texture:Texture2D=sheet.frames.get_frame_texture("idle_down",0)
			var h:=maxf(24,90*zoom)
			var w:=h*texture.get_width()/texture.get_height()
			draw_texture_rect(texture,Rect2(at-Vector2(w/2,h),Vector2(w,h)),false)
		else:draw_circle(at,4,Color("f1d5a0"))
		if zoom>0.2:draw_string(ThemeDB.fallback_font,at+Vector2(8,8),obj.name,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("fff0c2"))
	elif obj.kind in ["tree","autumn_tree"]:
		draw_circle(at+Vector2(2,2),maxf(3,33*zoom),Color("44573b"))
		draw_circle(at,maxf(3,29*zoom),Color("b68b4b") if obj.kind=="autumn_tree" else Color("416f48"))
	elif obj.kind=="rock":draw_circle(at,maxf(3,18*zoom),Color("a6a79b"))
	else:
		draw_circle(at,maxf(4,18*zoom),Color("e2d5b2"))
		if zoom>0.25:draw_string(ThemeDB.fallback_font,at+Vector2(8,0),WorldEditor.LABELS.get(obj.kind,obj.kind),HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("fff0c2"))
	if obj.id==editor.selection:draw_circle(at,11,Color("ffe0a4"),false,2)
