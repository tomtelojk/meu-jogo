extends RefCounted

# Run before the individual import test changes Bento's appearance.
static func run(runner, world: ForestWorld) -> void:
	for profile in KingdomData.PEOPLE:
		var npc: ForestNPC = world.npcs.get(profile.id)
		runner.verify(npc != null and npc.custom_sprite and TomateCharacterSheet.is_sheet(npc.sprite.sprite_frames),
			"NPC usa o agricultor de tomate.zip: " + profile.name)
		if npc == null or not TomateCharacterSheet.is_sheet(npc.sprite.sprite_frames):
			continue
		var frames := npc.sprite.sprite_frames
		var idle := frames.get_frame_texture("idle_down", 0) as AtlasTexture
		runner.verify(idle != null and idle.atlas.resource_path == TomateCharacterSheet.BASE + "farmer_pixel.png",
			"repouso usa as direções da prancha recebida: " + profile.name)
		var valid := frames.get_animation_names().size() == 12
		for direction in CharacterSheet.DIRECTIONS:
			for mode in ["idle", "walk", "run"]:
				var animation: String = mode + "_" + direction
				var count := 1 if mode == "idle" else 4
				valid = valid and frames.get_frame_count(animation) == count
				var file_name: String = "farmer_pixel" if mode == "idle" else TomateCharacterSheet.WALK_FILES[direction]
				for index in count:
					var atlas := frames.get_frame_texture(animation, index) as AtlasTexture
					valid = valid and atlas != null
					if atlas == null:
						continue
					valid = valid and atlas.atlas.resource_path == TomateCharacterSheet.BASE + file_name + ".png"
					valid = valid and atlas.get_size() == TomateCharacterSheet.CELL
					valid = valid and Rect2(Vector2.ZERO, atlas.atlas.get_size()).encloses(atlas.region)
					valid = valid and atlas.region.position == atlas.region.position.round() and atlas.region.size == atlas.region.size.round()
		runner.verify(valid, "cinco folhas complementares mantêm repouso e quatro direções sem espelhamento: " + profile.name)
		var foot := npc.sprite.position.y + (TomateCharacterSheet.SOLE_Y - TomateCharacterSheet.CELL.y / 2.0) * npc.sprite.scale.y
		runner.verify(npc.sprite.modulate == Color.WHITE and not npc.sprite.flip_h and not npc.sprite.flip_v
			and npc.sprite.material is ShaderMaterial and is_equal_approx(foot, 2.0),
			"fundo magenta é removido no render e a base do NPC fica ancorada: " + profile.name)
	runner.verify(TomateCharacterSheet.is_sheet(world.player.sprite.sprite_frames), "protagonista usa a nova arte do agricultor por padrão")
	runner.verify(world.player.sprite.material is ShaderMaterial, "protagonista remove o fundo magenta por material compartilhado")
