class_name ForestMinimap
extends Control

var world_data:Dictionary={}
var collected:Dictionary={}
var player_position:=WorldData.SPAWN
var restored:=false
var local_mode:=false
var home_position:=Vector2(-1,-1)

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
	draw_polyline(stream,Color("5d9dac"),maxf(2,WorldData.river_width(player_position.y)*2*factor.x))
	for town in KingdomData.SETTLEMENTS:
		var at:Vector2=(town.position-region.position)*factor
		if not Rect2(Vector2.ZERO,size).grow(20).has_point(at):continue
		draw_rect(Rect2(at-Vector2(3,3),Vector2(6,6)),KingdomData.REALMS[town.realm].color)
		if not local_mode:
			draw_string(ThemeDB.fallback_font,at+Vector2(7,-5),town.name,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("fff5d9"))
	if home_position.x>=0:
		var at:Vector2=(home_position-region.position)*factor
		draw_circle(at,4,Color("e3cd7b"))
	var hero:Vector2=(player_position-region.position)*factor
	draw_circle(hero,5,Color(1,1,0.8,0.25))
	draw_circle(hero,2.5,Color("ffffe6"))
