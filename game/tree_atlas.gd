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
const SEQUENCE := [0, 1, 2, 3, 4, 3, 2, 1]

static func read(fps: float = 2.0) -> Array[SpriteFrames]:
	var texture: Texture2D = load(PATH)
	var result: Array[SpriteFrames] = []
	for row in ROWS:
		var frames := SpriteFrames.new()
		frames.set_animation_speed("default", fps)
		for column in SEQUENCE:
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = cell_region(row, column)
			atlas.margin = Rect2(ANCHOR - source_anchor(row, column), FRAME_SIZE - atlas.region.size)
			atlas.filter_clip = true
			frames.add_frame("default", atlas, 1.4 if column == 0 or column == COLUMNS - 1 else 1.0)
		result.append(frames)
	return result

static func cell_region(row: int, column: int) -> Rect2:
	return Rect2(COLUMN_EDGES[column], row * ROW_HEIGHT, COLUMN_EDGES[column + 1] - COLUMN_EDGES[column], ROW_HEIGHT)

static func source_anchor(row: int, column: int) -> Vector2:
	return Vector2(TRUNK_X[row][column], SOURCE_BASELINE)

static func variant(point: Vector2) -> int:
	return posmod(roundi(point.x * 0.07 + point.y * 0.11), ROWS)
