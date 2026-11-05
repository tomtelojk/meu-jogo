extends Node2D

func _ready() -> void:
	var river := ForestRiver.new()
	river.build()
	add_child(river)

func _draw() -> void:
	_draw_bridge()
	_draw_camp()
	_draw_sign()

func _draw_bridge() -> void:
	var left := 35.7 * WorldData.TILE
	var right := 41.2 * WorldData.TILE
	var y := 20 * WorldData.TILE
	draw_rect(Rect2(left - 6, y - 31, right - left + 12, 75), Color(0.14, 0.24, 0.2, 0.5))
	var x := left
	while x < right:
		draw_rect(Rect2(x, y - 30, 16, 61), Color("a39060") if int(x) % 3 else Color("93815a"))
		draw_rect(Rect2(x, y - 29, 15, 3), Color("c7b47b"))
		draw_rect(Rect2(x + 8, y - 17, 1, 28), Color("6e6145"))
		x += 17
	for side in [-1, 1]:
		draw_rect(Rect2(left, y + side * 31, right - left + 4, 7), Color("61523a"))
		draw_rect(Rect2(left, y + side * 31, right - left + 4, 3), Color("c3a678"))
		x = left
		while x < right + 10:
			draw_rect(Rect2(x - 1, y + side * 34 - 14, 9, 20), Color("443e2b"))
			draw_rect(Rect2(x, y + side * 34 - 14, 7, 4), Color("c1a574"))
			x += 68

func _draw_camp() -> void:
	var p := WorldData.CAMP
	draw_set_transform(p, 0, Vector2(1, 0.3))
	draw_circle(Vector2.ZERO, 65, Color(0.16, 0.21, 0.16, 0.33))
	draw_set_transform(p)
	draw_colored_polygon(PackedVector2Array([Vector2(-49, 0), Vector2(-10, -77), Vector2(60, -62), Vector2(76, 4)]), Color("4a4734"))
	draw_colored_polygon(PackedVector2Array([Vector2(-10, -77), Vector2(60, -62), Vector2(76, 0), Vector2(20, 4)]), Color("c6b482"))
	draw_colored_polygon(PackedVector2Array([Vector2(-10, -77), Vector2(20, 4), Vector2(-49, 0)]), Color("9a8d62"))
	draw_colored_polygon(PackedVector2Array([Vector2(-10, -61), Vector2(10, 0), Vector2(-32, 0)]), Color("313e2d"))
	draw_line(Vector2(-10, -77), Vector2(20, 4), Color("ddd1a0"), 2)
	draw_line(Vector2(-10, -77), Vector2(-66, 7), Color("ddd1a0"), 1)
	draw_line(Vector2(60, -62), Vector2(89, 9), Color("ddd1a0"), 1)
	draw_rect(Rect2(-46, 18, 32, 13), Color("344b41"))
	draw_rect(Rect2(-45, 19, 31, 3), Color("78876b"))
	draw_rect(Rect2(2, 23, 22, 16), Color("81603c"))
	draw_rect(Rect2(4, 24, 19, 12), Color("d6c899"))
	draw_rect(Rect2(13, 24, 1, 12), Color("8d8b63"))
	var fire := Vector2(79, 57)
	for i in 8:
		var angle := i / 8.0 * TAU
		draw_circle(fire + Vector2(cos(angle) * 19, sin(angle) * 10), 5, Color("88826a") if i % 2 else Color("615f4b"))
	draw_rect(Rect2(fire + Vector2(-12, -2), Vector2(25, 5)), Color("6b4b30"))
	draw_colored_polygon(PackedVector2Array([fire + Vector2(-9, 0), fire + Vector2(-4, -19), fire + Vector2(0, -9), fire + Vector2(7, -24), fire + Vector2(11, 0)]), Color("d98f43"))
	draw_rect(Rect2(fire + Vector2(-2, -11), Vector2(6, 12)), Color("e6c46b"))
	draw_set_transform(Vector2.ZERO)

func _draw_sign() -> void:
	draw_set_transform(WorldData.SIGN)
	draw_rect(Rect2(-3, -45, 7, 45), Color("55472f"))
	draw_rect(Rect2(-22, -43, 46, 15), Color("9a8458"))
	draw_rect(Rect2(-18, -25, 40, 13), Color("9a8458"))
	draw_rect(Rect2(-22, -43, 46, 3), Color("c0a46d"))
	draw_rect(Rect2(-18, -25, 40, 2), Color("c0a46d"))
	draw_line(Vector2(-12, -36), Vector2(1, -36), Color("4c4e32"), 2)
	draw_line(Vector2(-12, -36), Vector2(-7, -40), Color("4c4e32"), 2)
	draw_line(Vector2(-12, -36), Vector2(-7, -32), Color("4c4e32"), 2)
	draw_line(Vector2(10, -19), Vector2(-3, -19), Color("4c4e32"), 2)
	draw_line(Vector2(10, -19), Vector2(5, -23), Color("4c4e32"), 2)
	draw_line(Vector2(10, -19), Vector2(5, -15), Color("4c4e32"), 2)
	draw_set_transform(Vector2.ZERO)
