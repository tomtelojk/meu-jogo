class_name TreeAtlas
extends RefCounted

const PATH := "res://assets/tomate/trees.png"
const ATLAS_SIZE := Vector2i(1983, 793)
const ROWS := 4
const COLUMNS := 1
const FRAME_SIZE := Vector2(600, 800)
const ANCHOR := Vector2(300, 720)
const REFERENCE_SIZE := 660.0
const CALM_ROW := 0
const DRY_ROW := 2
const REST_COLUMN := 0
const WIND_SHADER := "res://assets/environment/tree_wind.gdshader"
# Complete silhouettes, original outlines and ground details. The renderer
# removes the magenta key and purple baked shadows without changing the PNG.
const REGIONS := [Rect2(11, 64, 480, 633), Rect2(528, 27, 427, 669), Rect2(1003, 82, 462, 614), Rect2(1497, 70, 481, 626)]
const SOURCE_ROOTS := [Vector2(243, 693), Vector2(744, 692), Vector2(1229, 692), Vector2(1738, 692)]

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
	material.set_shader_parameter("wind_strength", 0.15 if row == DRY_ROW else 1.0)
	return material

static func cell_region(row: int, _column: int = 0) -> Rect2:
	return REGIONS[clampi(row, 0, ROWS - 1)]

static func source_anchor(row: int, _column: int = 0) -> Vector2:
	return SOURCE_ROOTS[row] - REGIONS[row].position

static func variant(point: Vector2) -> int:
	return posmod(roundi(point.x * 0.07 + point.y * 0.11), ROWS)
