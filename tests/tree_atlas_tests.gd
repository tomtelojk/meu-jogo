class_name TreeAtlasTests
extends RefCounted

static func run(runner, world: ForestWorld) -> void:
	var texture: Texture2D = load(TreeAtlas.PATH)
	var image := texture.get_image()
	runner.verify(image.get_size() == Vector2i(1983, 793) and FileAccess.get_sha256(TreeAtlas.PATH) == "2e01a9ef7473d9744836cbeb2be3887309f1ec5db29bc4980f404128efa5210c", "árvores mantêm os bytes originais de tomate.zip")
	var used_rows: Dictionary = {}
	var only_original := true
	var roots_aligned := true
	var valid_regions := true
	var continuous_wind := true
	for row in TreeAtlas.ROWS:
		var frames: SpriteFrames = world.libraries["tree" + str(row)]
		var atlas: AtlasTexture = frames.get_frame_texture("default", 0)
		only_original = only_original and atlas.atlas.resource_path == TreeAtlas.PATH
		valid_regions = valid_regions and atlas.region == TreeAtlas.cell_region(row, TreeAtlas.REST_COLUMN) and atlas.get_size() == TreeAtlas.FRAME_SIZE
		var anchor := TreeAtlas.source_anchor(row, TreeAtlas.REST_COLUMN) + atlas.margin.position
		roots_aligned = roots_aligned and anchor.is_equal_approx(TreeAtlas.ANCHOR)
		valid_regions = valid_regions and Rect2(Vector2.ZERO, Vector2(image.get_size())).encloses(atlas.region)
		valid_regions = valid_regions and atlas.margin.position.x >= 0 and atlas.margin.position.y >= 0
		valid_regions = valid_regions and (atlas.margin.position + atlas.region.size).x <= TreeAtlas.FRAME_SIZE.x and (atlas.margin.position + atlas.region.size).y <= TreeAtlas.FRAME_SIZE.y
		runner.verify(frames.get_frame_count("default") == 1 and not frames.get_animation_loop("default"), "árvore usa uma pose completa do pacote com vento contínuo: " + str(row + 1))
	for tree in world.trees:
		var sprite: AnimatedSprite2D = tree.sprite
		used_rows[sprite.get_meta("atlas_row", -1)] = true
		var displayed := sprite.sprite_frames.get_frame_texture("default", 0) as AtlasTexture
		only_original = only_original and displayed != null and displayed.atlas.resource_path == TreeAtlas.PATH
		roots_aligned = roots_aligned and not sprite.centered and sprite.offset == -TreeAtlas.ANCHOR and absf(sprite.position.y - 3.0) < 0.01
		continuous_wind = continuous_wind and not sprite.is_playing() and sprite.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR and sprite.material is ShaderMaterial and sprite.material.shader.resource_path == TreeAtlas.WIND_SHADER
	runner.verify(only_original and used_rows.size() == 4 and not used_rows.has(-1), "bosque usa carvalho, pinheiro, árvore seca e macieira de tomate.zip")
	runner.verify(valid_regions, "recortes inteiros evitam vizinhos e mantêm o mesmo tamanho entre quadros")
	runner.verify(roots_aligned, "centro dos troncos permanece fixo durante o balanço")
	runner.verify(continuous_wind and world.tree_materials.size() == TreeAtlas.ROWS, "árvores compartilham vento contínuo na copa sem executar flipbook")
	world.apply_progress({}, false)
	var dry: AtlasTexture = world.mother_sprite.sprite_frames.get_frame_texture("default", 0)
	runner.verify(dry.atlas.resource_path == TreeAtlas.PATH and dry.region == TreeAtlas.cell_region(TreeAtlas.DRY_ROW, TreeAtlas.REST_COLUMN), "árvore-mãe usa o desenho seco do novo pacote antes da restauração")
	world.apply_progress({}, true)
	var green: AtlasTexture = world.mother_sprite.sprite_frames.get_frame_texture("default", 0)
	runner.verify(green.atlas.resource_path == TreeAtlas.PATH and green.region == TreeAtlas.cell_region(TreeAtlas.CALM_ROW, TreeAtlas.REST_COLUMN) and world.mother_sprite.offset == -TreeAtlas.ANCHOR and is_equal_approx(world.mother_material.get_shader_parameter("vitality"), 1.0), "restauração troca a árvore-mãe seca pelo carvalho vivo mantendo a mesma raiz")
	world.apply_progress({}, false)
