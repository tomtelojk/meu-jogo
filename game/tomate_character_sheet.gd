class_name TomateCharacterSheet
extends RefCounted

const BASE := "res://assets/tomate/"
const SHADER := "res://assets/tomate/character_key.gdshader"
const CELL := Vector2(600, 680)
const SOLE_Y := 650.0
const HEIGHT := 64.0
const DIRECTIONS := ["down", "up", "right", "left"]
const WALK_FILES := {"down": "farmer_walk", "up": "explorer_walk", "right": "adventurer", "left": "farmer_retro"}
const IDLE_COLUMNS := {"down": 0, "left": 1, "right": 2, "up": 3}
# Native RGB source bounds, head centroid and sole, measured without modifying
# the sheets. Padding and a shared pivot compensate for their uneven spacing.
const POSES := {
	"farmer_walk": [[121,60,359,580,300.18,639],[640,60,362,581,820.43,640],[1167,60,361,580,1347.14,639],[1688,60,362,581,1868.74,640]],
	"farmer_pixel": [[123,56,369,597,306.83,652],[651,56,349,605,822.94,660],[1172,56,350,605,1348.05,660],[1677,56,364,597,1858.34,652]],
	"farmer_retro": [[116,47,354,614,291.89,660],[634,53,358,592,809.76,644],[1174,50,353,611,1347.66,660],[1702,50,360,600,1879.20,649]],
	"explorer_walk": [[122,64,349,583,296.47,646],[647,64,351,583,822.18,646],[1172,64,344,583,1343.63,646],[1690,64,347,583,1863.44,646]],
	"adventurer": [[92,56,369,631,276.34,686],[603,57,370,620,787.93,676],[1116,57,368,630,1300.23,686],[1626,57,371,626,1812.00,682]],
}
const WALK_HEIGHTS := {"down": 581.0, "up": 583.0, "right": 631.0, "left": 614.0}
const IDLE_HEIGHTS := {"down": 597.0, "left": 605.0, "right": 605.0, "up": 597.0}
static var _cache: Dictionary = {}

static func read() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	var textures: Dictionary = {}
	for name in POSES:
		var path := BASE + String(name) + ".png"
		if not ResourceLoader.exists(path):
			return {}
		textures[name] = load(path) as Texture2D
		if textures[name] == null:
			return {}
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.set_meta("tomate_character", true)
	for direction in DIRECTIONS:
		for mode in ["idle", "walk", "run"]:
			var animation: String = mode + "_" + direction
			frames.add_animation(animation)
			frames.set_animation_speed(animation, 12.0 if mode == "run" else 8.0)
			var file_name: String = "farmer_pixel" if mode == "idle" else WALK_FILES[direction]
			var columns: Array = [IDLE_COLUMNS[direction]] if mode == "idle" else [0, 1, 2, 3]
			for column in columns:
				var pose: Array = POSES[file_name][column]
				var region := Rect2(pose[0] - 2, pose[1] - 2, pose[2] + 4, pose[3] + 4)
				var atlas := AtlasTexture.new()
				atlas.atlas = textures[file_name]
				atlas.region = region
				atlas.margin = Rect2(Vector2(roundf(CELL.x / 2.0 - (pose[4] - region.position.x)), SOLE_Y - (pose[5] - region.position.y)), CELL - region.size)
				atlas.filter_clip = true
				frames.add_frame(animation, atlas)
	_cache = {"frames": frames, "cell": CELL}
	return _cache

static func make_material(clothing: Color = Color.WHITE) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load(SHADER)
	material.set_shader_parameter("clothing_tint", clothing)
	return material

static func is_sheet(frames: SpriteFrames) -> bool:
	return frames != null and frames.get_meta("tomate_character", false) == true

static func apply_geometry(sprite: AnimatedSprite2D) -> void:
	if not is_sheet(sprite.sprite_frames):
		return
	var animation := String(sprite.animation)
	var direction := animation.get_slice("_", 1)
	if not WALK_HEIGHTS.has(direction):
		return
	# The right-facing sheet has a different source resolution. Normalize by
	# direction while retaining the small height changes within the gait itself.
	var source_height: float = IDLE_HEIGHTS[direction] if animation.begins_with("idle_") else WALK_HEIGHTS[direction]
	var scale := HEIGHT / source_height
	sprite.scale = Vector2.ONE * scale
	sprite.position = Vector2(0, 2.0 - (SOLE_Y - CELL.y / 2.0) * scale)

static func is_key(color: Color) -> bool:
	return minf(color.r, color.b) - color.g > 0.5
