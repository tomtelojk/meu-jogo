extends RefCounted

static func run(runner, world: ForestWorld) -> void:
	var identities:Dictionary={}
	var named:Dictionary={}
	for profile in KingdomData.people():
		var npc:ForestNPC=world.npcs.get(profile.id)
		var face:=NPCAppearance.identity(profile)
		identities[face]=true
		if profile.id in MapDocument.FACES:named[face]=true
		runner.verify(npc!=null and npc.custom_sprite and npc.sprite.get_meta("appearance","")==face,"morador recebe aparência própria: "+profile.name)
		if npc==null:continue
		var frames:=npc.sprite.sprite_frames
		var valid:=frames.get_animation_names().size()==12
		for direction in CharacterSheet.DIRECTIONS:
			for mode in ["idle","walk","run"]:
				var animation:String=mode+"_"+direction
				var count:=1 if mode=="idle" else 4
				valid=valid and frames.get_frame_count(animation)==count
				for index in count:
					var atlas:=frames.get_frame_texture(animation,index) as AtlasTexture
					valid=valid and atlas!=null and Rect2(Vector2.ZERO,atlas.atlas.get_size()).encloses(atlas.region)
					if atlas==null:continue
					valid=valid and atlas.region.position==atlas.region.position.round() and atlas.region.size==atlas.region.size.round()
		runner.verify(valid,"repouso, caminhada e corrida usam quatro direções recortadas corretamente: "+profile.name)
		var feet:float
		if TomateCharacterSheet.is_sheet(frames):feet=npc.sprite.position.y+(TomateCharacterSheet.SOLE_Y-TomateCharacterSheet.CELL.y/2)*npc.sprite.scale.y
		else:
			var height:=frames.get_frame_texture("idle_down",0).get_height()
			feet=npc.sprite.position.y+(height*0.95-1-height/2.0)*npc.sprite.scale.y
		runner.verify(is_equal_approx(feet,2.0) and not npc.sprite.flip_h,"trocas de direção preservam o pivô dos pés: "+profile.name)
		var previous:=npc.position
		npc._animate_movement(Vector2.RIGHT*80,false,10)
		var moving_frame:=npc.sprite.frame
		npc._animate_movement(Vector2.RIGHT*80,false,0)
		runner.verify(npc.sprite.frame==moving_frame and npc.position==previous,"animação acompanha distância, sem avançar quando parado: "+profile.name)
	runner.verify(identities.size()==9 and named.size()==8,"população inclui nove silhuetas; os oito personagens nomeados são distintos")
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/npcs/sources.json"))
	var intact:=true
	for entry in manifest.files:intact=intact and FileAccess.get_sha256("res://"+entry.path)==entry.sha256
	runner.verify(intact,"sprites de abc.zip e protagonista original mantêm seus bytes")
	runner.verify(TomateCharacterSheet.is_sheet(world.player.sprite.sprite_frames),"protagonista continua usando o pacote tomate.zip")
