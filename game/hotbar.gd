class_name RPGHotbar
extends Control

signal selected(index:int)
const ITEMS:=["sword","axe","pickaxe","hammer","bread","map","journal","lantern"]
const NAMES:=["ESPADA","MACHADO","PICARETA","MARTELO","PROVISÃO","MAPA","DIÁRIO","LANTERNA"]
var slot:=0
var rpg:RPGState
var lantern:=false
var hover:=-1
func _ready()->void:
	custom_minimum_size=Vector2(480,90)
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	tooltip_text="1-4: equipar · 5: comer · 6: mapa · 7: diário · 8: lanterna"
func available(index:int)->bool:
	return rpg!=null and (rpg.tools.has(ITEMS[index]) if index<4 else (rpg.food>0 if index==4 else true))
func _gui_input(event:InputEvent)->void:
	if event is InputEventMouseMotion:hover=clampi(int(event.position.x/60),0,7);tooltip_text=NAMES[hover]+(" · Não adquirido" if not available(hover) else "");queue_redraw()
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		selected.emit(clampi(int(event.position.x/60),0,7));accept_event()
func _draw()->void:
	var font:Font=load(PixelArt.FONT)
	for i in 8:
		var rect:=Rect2(i*60,12,56,56)
		draw_rect(rect.grow(3),Color("10151f"))
		draw_rect(rect,Color("bda572") if i==slot else Color("75634c"))
		draw_rect(rect.grow(-2),Color("302f36") if i==slot else Color("1b232c"))
		draw_line(rect.position+Vector2(3,3),rect.position+Vector2(53,3),Color("dac38d") if i==slot else Color("948267"),2)
		draw_texture_rect(PixelArt.icon(ITEMS[i]),Rect2(rect.position+Vector2(12,10),Vector2(32,32)),false,Color.WHITE if available(i) else Color(0.36,0.37,0.40))
		draw_string(font,rect.position+Vector2(4,15),str(i+1),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("e0cf9f"))
		if i==4 and rpg!=null:draw_string(font,rect.end-Vector2(18,4),str(rpg.food),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("f1ddae"))
		if i==7 and lantern:draw_rect(Rect2(rect.end-Vector2(9,9),Vector2(5,5)),Color("ffe2a3"))
	var label:String=NAMES[slot]+(" · CLIQUE PARA USAR" if slot<5 else "")
	if slot==0 and not available(0):label="MÃOS LIVRES · ESPAÇO ATACAR"
	elif slot<4 and not available(slot):label=NAMES[slot]+" · COMPRE NA FERRARIA"
	draw_string(font,Vector2(240-font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x/2,89),label,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("e1cda3"))
