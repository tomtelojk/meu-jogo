extends Node2D

const PATH := "res://assets/tomate/villages.png"
const SIZE := Vector2(2172, 724)
const REGIONS := [Rect2(31, 21, 652, 659), Rect2(755, 21, 652, 658), Rect2(1466, 40, 689, 640)]
const DOORS := [Vector2(360, 676), Vector2(1085, 675), Vector2(1807, 676)]

func _ready() -> void:
	var texture: Texture2D = load(PATH)
	var entities := get_parent().get_node("Entities")
	for index in KingdomData.BUILDINGS.size():
		var building: Dictionary = KingdomData.BUILDINGS[index]
		var style := 0 if building.realm == "aurelia" else 1
		if building.kind in ["home", "market"]:
			style = 2 if index % 2 == 0 else style
		var rect := KingdomData.building_rect(building)
		var node := Node2D.new()
		node.name = "TomateBuilding_" + str(index)
		node.position = Vector2(rect.get_center().x, rect.end.y)
		node.set_meta("building", building.name)
		node.set_meta("tomate_style", style)
		var sprite := Sprite2D.new()
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = REGIONS[style]
		atlas.filter_clip = true
		sprite.texture = atlas
		sprite.centered = false
		sprite.offset = -(DOORS[style] - REGIONS[style].position)
		sprite.scale = Vector2.ONE * rect.size.x * 1.25 / REGIONS[style].size.x
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var material := ShaderMaterial.new()
		material.shader = load("res://assets/tomate/building_key.gdshader")
		var region: Rect2 = REGIONS[style]
		material.set_shader_parameter("frame_uv", Vector4(region.position.x / SIZE.x, region.position.y / SIZE.y, region.size.x / SIZE.x, region.size.y / SIZE.y))
		sprite.material = material
		node.add_child(sprite)
		entities.add_child(node)

func _draw() -> void:
	for building in KingdomData.BUILDINGS:
		var rect := KingdomData.building_rect(building)
		var font := ThemeDB.fallback_font
		var label_size := font.get_string_size(building.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 9)
		draw_string(font, Vector2(rect.get_center().x - label_size.x / 2, rect.end.y + 17), building.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("eee4c3"))
	for realm in KingdomData.REALMS.values():
		var point: Vector2 = realm.capital + Vector2(-85, 35)
		_banner(point, realm.color, 64)
		draw_string(ThemeDB.fallback_font, point + Vector2(25, 7), realm.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("eee4c3"))

func _banner(point: Vector2, color: Color, height: float) -> void:
	draw_line(point, point - Vector2(0, height), Color("554d36"), 3)
	draw_colored_polygon(PackedVector2Array([point - Vector2(0, height), point + Vector2(28, -height + 5), point + Vector2(20, -height + 18), point + Vector2(0, -height + 14)]), color)
