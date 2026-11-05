class_name TreeAtlasTests
extends RefCounted

static func run(runner, world: ForestWorld) -> void:
	var texture: Texture2D = load(TreeAtlas.PATH)
	var image := texture.get_image()
	runner.verify(image.get_size() == TreeAtlas.ATLAS_SIZE and FileAccess.get_sha256(TreeAtlas.PATH) == "14f0f89537bfe301046738cee58d3a8f1c540a857a85cd53a8e5b6106bde3585", "atlas de árvores mantém os bytes originais do ZIP")
	var used_rows: Dictionary = {}
	var only_original := true
	var roots_aligned := true
	var valid_regions := true
	for row in TreeAtlas.ROWS:
		var frames: SpriteFrames = world.libraries["tree" + str(row)]
		var columns: Dictionary = {}
		for index in frames.get_frame_count("default"):
			var atlas: AtlasTexture = frames.get_frame_texture("default", index)
			var column: int = TreeAtlas.SEQUENCE[index]
			columns[column] = true
			only_original = only_original and atlas.atlas.resource_path == TreeAtlas.PATH
			valid_regions = valid_regions and atlas.region == TreeAtlas.cell_region(row, column) and atlas.get_size() == TreeAtlas.FRAME_SIZE
			var root := _trunk_center(image, atlas.region)
			roots_aligned = roots_aligned and absf(root + atlas.margin.position.x - TreeAtlas.ANCHOR.x) <= 1.5
		runner.verify(columns.size() == 5, "cinco poses originais preservadas na variação de balanço " + str(row + 1))
	for tree in world.trees:
		var sprite: AnimatedSprite2D = tree.sprite
		used_rows[sprite.get_meta("atlas_row", -1)] = true
		only_original = only_original and sprite.sprite_frames in world.libraries.values()
		roots_aligned = roots_aligned and not sprite.centered and sprite.offset == -TreeAtlas.ANCHOR and absf(sprite.position.y - 3.0) < 0.01
	runner.verify(only_original and used_rows.size() == 8 and not used_rows.has(-1), "todas as árvores, inclusive a árvore-mãe, usam o atlas novo e suas oito variações")
	runner.verify(valid_regions, "recortes inteiros evitam vizinhos e mantêm o mesmo tamanho entre quadros")
	runner.verify(roots_aligned, "centro dos troncos permanece fixo durante o balanço")
	var mother_frames := world.mother_sprite.sprite_frames
	world.apply_progress({}, false)
	runner.verify(is_equal_approx(world.mother_material.get_shader_parameter("vitality"), 0.15), "árvore-mãe debilitada usa dessaturação discreta em runtime")
	world.apply_progress({}, true)
	runner.verify(is_equal_approx(world.mother_material.get_shader_parameter("vitality"), 1.0) and world.mother_sprite.sprite_frames == mother_frames, "restauração devolve as cores originais sem trocar ou deslocar a árvore-mãe")
	world.apply_progress({}, false)

static func _trunk_center(image: Image, region: Rect2) -> float:
	var pixels: Array[int] = []
	for y in range(155, 172):
		for x in int(region.size.x):
			if image.get_pixel(int(region.position.x) + x, int(region.position.y) + y).a > 0.64:
				pixels.append(x)
	if pixels.is_empty():
		return INF
	pixels.sort()
	return float(pixels[pixels.size() / 2])
