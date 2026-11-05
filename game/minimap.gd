class_name ForestMinimap
extends Control

var world_data: Dictionary = {}
var collected: Dictionary = {}
var player_position := WorldData.SPAWN
var restored: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(168, 112)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("65714b"))
	draw_rect(Rect2(size.x * 0.76, 0, size.x * 0.24, size.y), Color("54725c"))
	var factor := size / WorldData.SIZE
	for path in WorldData.paths():
		var points := PackedVector2Array()
		for point in path:
			points.append(point * factor)
		draw_polyline(points, Color("c3b581"), maxf(1.0, size.x / 150.0))
	var stream := PackedVector2Array()
	for i in 60:
		var y := i / 59.0 * WorldData.SIZE.y
		stream.append(Vector2(WorldData.river_x(y), y) * factor)
	draw_polyline(stream, Color("7bada0"), size.x / 3200.0 * 140.0)
	for tree in world_data.get("trees", []):
		draw_circle(tree.position * factor, maxf(1.0, size.x / 150.0), Color("a28b50") if tree.kind == "autumn" else Color("405b3f"))
	draw_circle(WorldData.MOTHER * factor, maxf(3, size.x / 80), Color("d1df9a") if restored else Color("e2d6ab"))
	for seed_data in WorldData.SEEDS:
		if not collected.has(seed_data.id):
			draw_circle(seed_data.position * factor, maxf(2, size.x / 115), Color("f0d281"))
	for realm in KingdomData.REALMS.values():
		draw_rect(Rect2(realm.capital * factor - Vector2(3, 3), Vector2(6, 6)), realm.color)
	for npc in world_data.get("npc_markers", []):
		draw_circle(npc.position * factor, maxf(1.3, size.x / 200), KingdomData.REALMS[npc.realm].color.lightened(0.2))
	if size.x > 250:
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(8, 17), "AURÉLIA", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("f2ddb0"))
		draw_string(font, Vector2(size.x - 85, 17), "VALVERDE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("d1e7d9"))
	draw_circle(player_position * factor, maxf(4, size.x / 70), Color(0.95, 0.95, 0.78, 0.2))
	draw_circle(player_position * factor, maxf(2, size.x / 150), Color("ffffe6"))
