class_name ConstructionGridGuide
extends Node2D

var entry:Dictionary={}
var valid:=true

func update_preview(candidate:Dictionary,allowed:bool)->void:
	entry=candidate;valid=allowed;show();queue_redraw()

func _draw()->void:
	if entry.is_empty():return
	var anchor:=ConstructionCatalog.pivot(entry);var center:=WorldGrid.vertex_at(anchor)
	for i in range(-7,8):
		var x:float=(center.x+i)*WorldGrid.CELL;var y:float=(center.y+i)*WorldGrid.CELL
		var color:=Color(0.9,0.85,0.63,0.6) if posmod(center.x+i,4)==0 else Color(0.82,0.93,0.81,0.32)
		draw_line(Vector2(x,anchor.y-7*WorldGrid.CELL),Vector2(x,anchor.y+7*WorldGrid.CELL),color,1)
		color=Color(0.9,0.85,0.63,0.6) if posmod(center.y+i,4)==0 else Color(0.82,0.93,0.81,0.32)
		draw_line(Vector2(anchor.x-7*WorldGrid.CELL,y),Vector2(anchor.x+7*WorldGrid.CELL,y),color,1)
	var color:=Color(0.35,0.95,0.48,0.75) if valid else Color(1,0.2,0.15,0.8)
	draw_rect(ConstructionCatalog.footprint(entry),color,false,2);draw_circle(anchor,4,Color("f1cf79"))
