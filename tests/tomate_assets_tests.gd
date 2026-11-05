extends RefCounted

static func run(runner, world: ForestWorld) -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/tomate/sources.json"))
	var originals_match: bool = manifest.get("archive") == "tomate.zip" and manifest.get("files", []).size() == 10
	for entry in manifest.get("files", []):
		originals_match = originals_match and FileAccess.get_sha256("res://" + String(entry.path)) == entry.sha256
	runner.verify(originals_match, "os dez PNGs de tomate.zip mantêm os bytes e hashes originais")
	var buildings := world.entities.find_children("TomateBuilding_*", "Node2D", true, false)
	var styles: Dictionary = {}
	var all_new := true
	for building in buildings:
		styles[building.get_meta("tomate_style", -1)] = true
		for child in building.get_children():
			if child is Sprite2D:
				var atlas := child.texture as AtlasTexture
				all_new = all_new and atlas != null and atlas.atlas.resource_path == "res://assets/tomate/villages.png"
	runner.verify(buildings.size() == KingdomData.BUILDINGS.size() and all_new and styles.size() == 3 and not styles.has(-1),
		"os dois reinos usam as três casas do pacote em todos os edifícios")
	runner.verify(world.data.decor.is_empty() and world.data.colliders.size() == world.trees.size(),
		"detalhes do chão novo não deixam colisões invisíveis da decoração antiga")
	runner.verify(world.player.sprite.material != null,
		"o protagonista possui o material que remove o fundo rosa do pacote")
