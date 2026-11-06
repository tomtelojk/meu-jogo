class_name NPCAppearance
extends RefCounted

const FACES := ["bento","lia","tomas","iris","eron","mila","farmer"]
const PALETTES := [Color("a5c4aa"),Color("b89ecb"),Color("d1a16e"),Color("80a9c0"),Color("c38b88"),Color("c5c294")]
static var _sheets: Dictionary = {}

static func identity(profile: Dictionary) -> String:
	if profile.has("appearance"):return profile.appearance
	if profile.id in MapDocument.FACES:return profile.id
	var number: int = posmod(String(profile.id).hash(),FACES.size())
	return FACES[number]

static func sheet(face: String) -> Dictionary:
	if face=="farmer":return TomateCharacterSheet.read()
	if not _sheets.has(face):_sheets[face]=CharacterSheet.read("res://assets/npcs/"+face+".png",true)
	return _sheets[face]

static func apply(sprite: AnimatedSprite2D, profile: Dictionary) -> bool:
	var face := identity(profile)
	var data := sheet(face)
	if data.is_empty():return false
	sprite.sprite_frames=data.frames
	var palette: Color = Color.WHITE if profile.id in MapDocument.FACES else PALETTES[posmod(String(profile.id).hash()/7,PALETTES.size())]
	sprite.material=TomateCharacterSheet.make_material(palette)
	sprite.set_meta("appearance",face)
	sprite.set_meta("body_height",64.0+posmod(String(profile.id).hash(),9))
	sprite.modulate=Color.WHITE
	geometry(sprite)
	return true

static func geometry(sprite: AnimatedSprite2D) -> void:
	if TomateCharacterSheet.is_sheet(sprite.sprite_frames):
		TomateCharacterSheet.apply_geometry(sprite)
		return
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation,0)
	if texture==null:return
	var height: float = sprite.get_meta("body_height",72.0)
	sprite.scale=Vector2.ONE*height/texture.get_height()
	# CharacterSheet aligns soles at 95% of the padded cell.
	sprite.position=Vector2(0,2-(texture.get_height()*0.95-1-texture.get_height()/2.0)*sprite.scale.y)
