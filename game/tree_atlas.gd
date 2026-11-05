class_name TreeAtlas
extends RefCounted

const PATH := "res://assets/environment/medieval_tree_atlas.png"
const ATLAS_SIZE := Vector2i(1024, 1536)
const ROWS := 8
const COLUMNS := 5
const COLUMN_EDGES := [0, 205, 410, 614, 819, 1024]
const ROW_HEIGHT := 192
const FRAME_SIZE := Vector2(240, 208)
const ANCHOR := Vector2(120, 184)
const SOURCE_BASELINE := 179.0
const REFERENCE_SIZE := 160.0
const CALM_ROW := 3
const REST_COLUMN := 0
const WIND_SHADER := "res://assets/environment/tree_wind.gdshader"
# Lower-trunk centers measured in the original cells. The supplied poses move
# their trunks as well as their crowns; padding anchors each to the same root.
const TRUNK_X := [
	[108.0, 106.0, 102.0, 99.0, 94.0],
	[95.0, 94.0, 91.0, 90.0, 88.0],
	[90.0, 92.0, 95.0, 100.0, 101.0],
	[107.0, 106.0, 104.0, 104.0, 104.0],
	[108.0, 107.0, 103.0, 105.0, 103.0],
	[108.0, 106.0, 103.0, 105.0, 103.0],
	[105.0, 105.0, 101.0, 101.0, 101.0],
	[106.0, 105.0, 103.0, 104.0, 102.5],
]
static func read() -> Array[SpriteFrames]:
	var texture: Texture2D = load(PATH)
	var result: Array[SpriteFrames] = []
	for row in ROWS:
		var frames := SpriteFrames.new()
		frames.set_animation_loop("default", false)
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = cell_region(row, REST_COLUMN)
		atlas.margin = Rect2(ANCHOR - source_anchor(row, REST_COLUMN), FRAME_SIZE - atlas.region.size)
		atlas.filter_clip = true
		frames.add_frame("default", atlas)
		result.append(frames)
	return result

static func make_wind_material(row: int, vitality: float = 1.0) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load(WIND_SHADER)
	var source := cell_region(row, REST_COLUMN)
	material.set_shader_parameter("frame_uv", Vector4(source.position.x / ATLAS_SIZE.x, source.position.y / ATLAS_SIZE.y, source.size.x / ATLAS_SIZE.x, source.size.y / ATLAS_SIZE.y))
	material.set_shader_parameter("vitality", vitality)
	return material

static func cell_region(row: int, column: int) -> Rect2:
	return Rect2(COLUMN_EDGES[column], row * ROW_HEIGHT, COLUMN_EDGES[column + 1] - COLUMN_EDGES[column], ROW_HEIGHT)

static func source_anchor(row: int, column: int) -> Vector2:
	return Vector2(TRUNK_X[row][column], SOURCE_BASELINE)

static func variant(point: Vector2) -> int:
	return posmod(roundi(point.x * 0.07 + point.y * 0.11), ROWS)
