class_name GroundAtlas
extends RefCounted

const TERRAIN_PATH := "res://assets/tomate/terrain.png"
const TRANSITIONS_PATH := "res://assets/tomate/transitions.png"
const WATER_PATH := "res://assets/tomate/water.png"
const TILE_PIXELS := 176
const CELL_WORLD_SIZE := 64.0
const UV_SCALE := TILE_PIXELS / CELL_WORLD_SIZE
# Measured interiors exclude the sheet's black dividers and magenta surround.
const COLUMN_START := [24, 213, 400, 586, 772, 957, 1143, 1330]
const COLUMN_END := [206, 393, 579, 764, 950, 1136, 1324, 1512]
const ROW_START := [24, 217, 410, 602, 796]
const ROW_END := [210, 402, 595, 788, 995]
const WATER_COLUMN_START := [16, 211, 400, 586, 772, 959, 1148, 1336]
const WATER_COLUMN_END := [202, 391, 578, 764, 951, 1139, 1328, 1520]
const WATER_ROW_START := [108, 312, 516, 720]
const WATER_ROW_END := [303, 507, 711, 915]
const TRANSITION_STRIP := Rect2i(269, 112, 238, 36)

static var _images: Dictionary = {}
static var _textures: Dictionary = {}

static func source_image(path: String) -> Image:
	if not _images.has(path):
		var texture := load(path) as Texture2D
		_images[path] = texture.get_image()
	return _images[path]

static func region(row: int, column: int) -> Rect2i:
	return Rect2i(
		COLUMN_START[column] + (COLUMN_END[column] - COLUMN_START[column] - TILE_PIXELS) / 2,
		ROW_START[row] + (ROW_END[row] - ROW_START[row] - TILE_PIXELS) / 2,
		TILE_PIXELS, TILE_PIXELS)

static func tile(row: int, column: int) -> Texture2D:
	var key := "terrain_%d_%d" % [row, column]
	if not _textures.has(key):
		_textures[key] = ImageTexture.create_from_image(source_image(TERRAIN_PATH).get_region(region(row, column)))
	return _textures[key]

static func create_grass_tiles() -> TileSet:
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(TILE_PIXELS, TILE_PIXELS)
	for column in 8:
		var source := TileSetAtlasSource.new()
		source.texture = tile(0, column)
		source.texture_region_size = Vector2i(TILE_PIXELS, TILE_PIXELS)
		source.create_tile(Vector2i.ZERO)
		tiles.add_source(source, column)
	return tiles

static func grass_variant(x: int, y: int) -> int:
	# Mostly plain tufts, with occasional flowers and stones from the same sheet.
	var value := posmod((x * 73856093) ^ (y * 19349663) ^ 442, 100)
	if value < 28: return 0
	if value < 56: return 1
	if value < 78: return 3
	if value < 85: return 2
	if value < 89: return 5
	if value < 91: return 4
	if value < 96: return 6
	return 7

static func transition_strip() -> Texture2D:
	if not _textures.has("transition"):
		_textures.transition = ImageTexture.create_from_image(source_image(TRANSITIONS_PATH).get_region(TRANSITION_STRIP))
	return _textures.transition

static func water_region(phase: int, column: int = 0) -> Rect2i:
	return Rect2i(
		WATER_COLUMN_START[column] + (WATER_COLUMN_END[column] - WATER_COLUMN_START[column] - TILE_PIXELS) / 2,
		WATER_ROW_START[phase] + (WATER_ROW_END[phase] - WATER_ROW_START[phase] - TILE_PIXELS) / 2,
		TILE_PIXELS, TILE_PIXELS)

static func water_frames() -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	for phase in 4:
		var key := "water_" + str(phase)
		if not _textures.has(key):
			_textures[key] = ImageTexture.create_from_image(source_image(WATER_PATH).get_region(water_region(phase)))
		frames.append(_textures[key])
	return frames

static func bank_texture(left: bool) -> Texture2D:
	var key := "bank_left" if left else "bank_right"
	if not _textures.has(key):
		var channel := source_image(WATER_PATH).get_region(water_region(0, 2))
		var bank := Rect2i(18, 0, 44, TILE_PIXELS) if left else Rect2i(112, 0, 58, TILE_PIXELS)
		_textures[key] = ImageTexture.create_from_image(channel.get_region(bank))
	return _textures[key]

static var _tile_sets:Dictionary={}
static func biome_tiles(row:int)->TileSet:
	if _tile_sets.has(row):return _tile_sets[row]
	var tiles:=TileSet.new()
	tiles.tile_size=Vector2i(TILE_PIXELS,TILE_PIXELS)
	for column in 8:
		var source:=TileSetAtlasSource.new()
		source.texture=tile(row,column)
		source.texture_region_size=Vector2i(TILE_PIXELS,TILE_PIXELS)
		source.create_tile(Vector2i.ZERO)
		tiles.add_source(source,column)
	_tile_sets[row]=tiles
	return tiles
