extends RefCounted

# Run before the individual import test changes Bento's appearance.
static func run(runner, world: ForestWorld) -> void:
	var cell := Vector2(1024.0 / 5.0, 1536.0 / 8.0)
	for profile in KingdomData.PEOPLE:
		var path := "res://assets/npcs/" + String(profile.id) + ".png"
		var original := load(path) as Texture2D
		var npc: ForestNPC = world.npcs.get(profile.id)
		runner.verify(original != null and npc != null and npc.custom_sprite,
			"NPC carrega a prancha original incluída no jogo: " + profile.name)
		if original == null or npc == null or not npc.custom_sprite:
			continue
		var library := npc.sprite.sprite_frames
		var first := library.get_frame_texture("idle_down", 0) as AtlasTexture
		var matches_original := original.get_size() == Vector2(1024, 1536) and first != null
		if matches_original:
			matches_original = first.atlas.get_image().get_data() == original.get_image().get_data()
		runner.verify(matches_original,
			"animação usa os pixels da prancha correta: " + profile.name)
		var directions_match := library.get_animation_names().size() == 12
		for row in 4:
			for mode in ["idle", "walk", "run"]:
				var animation: String = mode + "_" + CharacterSheet.DIRECTIONS[row]
				var columns := [0] if mode == "idle" else [1, 2, 3, 4]
				var source_row := row + (4 if mode == "run" else 0)
				if not library.has_animation(animation) or library.get_frame_count(animation) != columns.size():
					directions_match = false
					continue
				for frame in columns.size():
					var atlas := library.get_frame_texture(animation, frame) as AtlasTexture
					var expected := Rect2(Vector2(columns[frame], source_row) * cell, cell)
					if atlas == null or not atlas.region.is_equal_approx(expected):
						directions_match = false
		runner.verify(directions_match,
			"prancha 5×8 mantém os quadros e as quatro direções: " + profile.name)
		runner.verify(npc.sprite.modulate == Color.WHITE and not npc.sprite.flip_h and not npc.sprite.flip_v
			and npc.sprite.scale.is_equal_approx(Vector2.ONE * 72.0 / cell.y),
			"NPC preserva cores, direção e escala da arte original: " + profile.name)
