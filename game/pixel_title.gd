class_name PixelTitle
extends Control

var tick:=0.0
func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
func _process(delta:float)->void:
	tick+=delta
	if tick>0.4:tick=0;queue_redraw()
func _draw()->void:
	draw_set_transform(Vector2.ZERO,0,size/Vector2(320,200))
	draw_rect(Rect2(0,0,320,200),Color("111824"))
	for y in range(70,171):draw_rect(Rect2(0,y,320,1),Color("283744").lerp(Color("695a52"),(y-70)/100.0))
	for i in 45:
		var x:=posmod(i*73+17,320);var y:=posmod(i*47+11,85)
		draw_rect(Rect2(x,y,1,1),Color("b8b4aa") if i%3 else Color("747d91"))
	draw_rect(Rect2(253,22,12,12),Color("d8d0aa"));draw_rect(Rect2(258,20,5,3),Color("d8d0aa"))
	for layer in 3:
		for x in range(0,321,2):
			var y:=110+layer*22+roundi(sin(x*0.022+layer*2)*11+sin(x*.047+layer)*7)
			draw_rect(Rect2(x,y,2,200-y),[Color("333f4c"),Color("252e3a"),Color("18212b")][layer])
	# Two tiny silhouettes, deliberately sparse so the menu remains the focus.
	for town in [Vector2(42,126),Vector2(255,140)]:
		draw_rect(Rect2(town-Vector2(20,14),Vector2(40,14)),Color("121c29"))
		for side in [-1,1]:
			draw_rect(Rect2(town+Vector2(side*17-4,-28),Vector2(8,28)),Color("121c29"))
			for i in 3:draw_rect(Rect2(town+Vector2(side*17-4+i*3,-30),Vector2(2,3)),Color("121c29"))
		for i in 4:draw_rect(Rect2(town+Vector2(-13+i*8,-10),Vector2(1,2)),Color("c49a62"))
	for i in 17:
		var x:=i*23-12;var y:=172+posmod(i*13,19)
		draw_rect(Rect2(x,y-14,2,16),Color("101820"))
		for row in range(0,20,2):
			var half:=1+row/4
			draw_rect(Rect2(x+1-half,y-24+row,half*2,2),Color("101820"))
	draw_set_transform(Vector2.ZERO)
