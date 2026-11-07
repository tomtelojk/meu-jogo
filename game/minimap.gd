class_name ForestMinimap
extends Control

var world_data:Dictionary={}
var collected:Dictionary={}
var player_position:=WorldData.SPAWN
var restored:=false
var local_mode:=false
var home_position:=Vector2(-1,-1)
var rpg_state:RPGState

func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	clip_contents=true
	if custom_minimum_size==Vector2.ZERO:custom_minimum_size=Vector2(168,112)

func _draw()->void:
	var region:=Rect2(player_position-Vector2(1400,1000),Vector2(2800,2000)) if local_mode else Rect2(Vector2.ZERO,WorldData.SIZE)
	var factor:=size/region.size
	var columns:=8 if local_mode else 24
	var rows:=6 if local_mode else 18
	for y in rows:
		for x in columns:
			var point:=region.position+Vector2(x+0.5,y+0.5)*region.size/Vector2(columns,rows)
			var color:=Color("8d9862") if point.x<WorldData.river_x(point.y) else Color("668e69")
			match WorldData.biome(point):
				"woodland":color=Color("476c4a")
				"mountains":color=Color("94978b")
				"coast":color=Color("c3b486")
			draw_rect(Rect2(Vector2(x,y)*size/Vector2(columns,rows),size/Vector2(columns,rows)+Vector2.ONE),color)
	for path in WorldData.paths():
		var bounds:=Rect2(path[0],Vector2.ZERO)
		for point in path:bounds=bounds.expand(point)
		if not bounds.grow(100).intersects(region):continue
		var points:=PackedVector2Array()
		for point in path:points.append((point-region.position)*factor)
		draw_polyline(points,Color("d1c28f"),1.3 if local_mode else 1.0)
	var stream:=PackedVector2Array()
	for i in 90:
		var y:=region.position.y+i/89.0*region.size.y
		stream.append((Vector2(WorldData.river_x(y),y)-region.position)*factor)
	if MapDocument.base_enabled():draw_polyline(stream,Color("5d9dac"),maxf(2,WorldData.river_width(player_position.y)*2*factor.x))
	for key in MapDocument.current.terrain:
		var at:=Vector2(MapDocument.parse_cell(key))*64
		if not region.grow(64).has_point(at):continue
		var color:Color=MapCanvas.COLORS[MapDocument.current.terrain[key]]
		draw_rect(Rect2((at-region.position)*factor,Vector2.ONE*64*factor+Vector2.ONE*0.25),color)
	for building in KingdomData.buildings():
		var rect:=KingdomData.building_rect(building)
		if not region.intersects(rect):continue
		draw_rect(Rect2((rect.position-region.position)*factor,(rect.size*factor).max(Vector2.ONE)),Color("645740"))
	if rpg_state!=null and MapDocument.base_enabled():
		FactionCatalog.load_data()
		for id in FactionCatalog.data.territories:
			var town:=FactionCatalog.town(id)
			if town.is_empty():continue
			var rect:=Rect2(town.position-Vector2.ONE*1150,Vector2.ONE*2300)
			if not rect.intersects(region):continue
			var color:=Color(FactionCatalog.faction(rpg_state.politics.control(id)).color)
			var view:=Rect2((rect.position-region.position)*factor,rect.size*factor)
			draw_rect(view,Color(color,0.16));draw_rect(view,Color(color,0.75),false,1)
		for id in FactionCatalog.data.guilds:
			if not rpg_state.politics.guild_available(id):continue
			var point:Vector2=(FactionCatalog.headquarters(id)-region.position)*factor
			var diamond:=PackedVector2Array([point+Vector2(0,-4),point+Vector2(4,0),point+Vector2(0,4),point+Vector2(-4,0)])
			draw_colored_polygon(diamond,Color(FactionCatalog.guild(id).color))
	for town in KingdomData.towns():
		var at:Vector2=(town.position-region.position)*factor
		if not Rect2(Vector2.ZERO,size).grow(20).has_point(at):continue
		var color:Color=KingdomData.REALMS[town.realm].color
		if rpg_state!=null and not FactionCatalog.territory(town.id).is_empty():color=Color(FactionCatalog.faction(rpg_state.politics.control(town.id)).color)
		draw_rect(Rect2(at-Vector2(3,3),Vector2(6,6)),color)
		if not local_mode:
			draw_string(ThemeDB.fallback_font,at+Vector2(7,-5),town.name,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("fff5d9"))
	if home_position.x>=0:
		var at:Vector2=(home_position-region.position)*factor
		draw_circle(at,4,Color("e3cd7b"))
	var hero:Vector2=(player_position-region.position)*factor
	draw_circle(hero,5,Color(1,1,0.8,0.25))
	draw_circle(hero,2.5,Color("ffffe6"))
