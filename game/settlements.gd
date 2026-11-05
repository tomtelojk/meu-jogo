extends Node2D

func _draw() -> void:
	for building in KingdomData.BUILDINGS:
		_building(building)
	var farm := KingdomData.point("mila_farm") + Vector2(80, 50)
	draw_rect(Rect2(farm - Vector2(80, 32), Vector2(180, 100)), Color("74563c"))
	for row in 4:
		for col in 9:
			var point := farm + Vector2(col * 18 - 65, row * 22 - 20)
			draw_line(point, point + Vector2(0, -8), Color("83934a"), 2)
			draw_line(point + Vector2(0, -3), point + Vector2(-5, -7), Color("a2b561"), 2)
			draw_line(point + Vector2(0, -4), point + Vector2(5, -9), Color("a2b561"), 2)
	for realm in KingdomData.REALMS.values():
		var point: Vector2 = realm.capital + Vector2(-85, 35)
		_banner(point, realm.color, 64)
		var font := ThemeDB.fallback_font
		draw_string(font, point + Vector2(25, 7), realm.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("eee4c3"))

func _building(building: Dictionary) -> void:
	var rect := KingdomData.building_rect(building)
	var p := rect.position
	var width := rect.size.x
	var height := rect.size.y
	var realm: Dictionary = KingdomData.REALMS[building.realm]
	var stone := Color("89836c") if building.realm == "aurelia" else Color("75877d")
	var roof := Color("70513d") if building.realm == "aurelia" else Color("475f50")
	draw_rect(Rect2(p + Vector2(8, 20), rect.size + Vector2(10, 4)), Color(0.12, 0.19, 0.13, 0.35))
	if building.kind == "market":
		draw_rect(Rect2(p + Vector2(8, 28), Vector2(width - 16, height - 28)), Color("766044"))
		for i in 6:
			draw_rect(Rect2(p + Vector2(i * width / 6, 0), Vector2(width / 6, 32)), realm.color if i % 2 else Color("ddd2ab"))
		draw_line(p + Vector2(2, 25), p + Vector2(2, height), Color("4b4732"), 4)
		draw_line(p + Vector2(width - 2, 25), p + Vector2(width - 2, height), Color("4b4732"), 4)
		for i in 4:
			draw_rect(Rect2(p + Vector2(15 + i * 18, height - 16), Vector2(12, 9)), Color("b19b5b") if i % 2 else Color("8e9d57"))
	else:
		draw_rect(rect, stone.darkened(0.18))
		draw_rect(Rect2(p + Vector2(4, 4), rect.size - Vector2(8, 8)), stone)
		if building.kind == "castle":
			for side in [0.0, width - 32]:
				draw_rect(Rect2(p + Vector2(side, -30), Vector2(32, height + 30)), stone.darkened(0.12))
				for x in 3:
					draw_rect(Rect2(p + Vector2(side + x * 12 - 2, -39), Vector2(10, 14)), stone.lightened(0.16))
			_banner(p + Vector2(width / 2, -14), realm.color, 43)
		else:
			draw_colored_polygon(PackedVector2Array([p + Vector2(-9, 10), p + Vector2(width / 2, -32), p + Vector2(width + 9, 10), p + Vector2(width, 24), p + Vector2(0, 24)]), roof)
			draw_line(p + Vector2(-9, 10), p + Vector2(width / 2, -32), roof.lightened(0.25), 3)
			draw_line(p + Vector2(width / 2, -32), p + Vector2(width + 9, 10), roof.lightened(0.1), 3)
		for side in [18, int(width) - 30]:
			draw_rect(Rect2(p + Vector2(side, height - 48), Vector2(14, 18)), Color("364334"))
			draw_rect(Rect2(p + Vector2(side + 2, height - 46), Vector2(10, 13)), Color("c6be8c"))
			draw_line(p + Vector2(side + 7, height - 47), p + Vector2(side + 7, height - 32), stone.darkened(0.4), 2)
		draw_rect(Rect2(p + Vector2(width / 2 - 11, height - 30), Vector2(22, 30)), Color("554631"))
		draw_rect(Rect2(p + Vector2(width / 2 - 8, height - 27), Vector2(16, 26)), Color("715a3c"))
		draw_circle(p + Vector2(width / 2 + 5, height - 13), 1.7, Color("cbb574"))
		if building.kind == "forge":
			draw_rect(Rect2(p + Vector2(width - 20, -26), Vector2(15, 37)), Color("66614e"))
			draw_rect(Rect2(p + Vector2(8, height - 16), Vector2(22, 9)), Color("3c4944"))
			draw_rect(Rect2(p + Vector2(14, height - 8), Vector2(10, 8)), Color("4e5c55"))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(rect.position.x + width / 2, rect.end.y + 17) - Vector2(font.get_string_size(building.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x / 2, 0), building.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("eee4c3"))

func _banner(point: Vector2, color: Color, height: float) -> void:
	draw_line(point, point - Vector2(0, height), Color("554d36"), 3)
	draw_colored_polygon(PackedVector2Array([point - Vector2(0, height), point + Vector2(28, -height + 5), point + Vector2(20, -height + 18), point + Vector2(0, -height + 14)]), color)
