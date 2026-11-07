class_name ModularSpriteSheet
extends RefCounted

const CELL:=Vector2i(48,64)
const SOLE_Y:=60.0
const ART_HEIGHT:=56.0
const BASE:="res://assets/modular_npcs/"
static var sheets:Dictionary={}
static var images:Dictionary={}

static func is_sheet(frames:SpriteFrames)->bool:return frames!=null and frames.get_meta("modular_character",false)

static func read(data:AppearanceData)->Dictionary:
	var key:=data.piece_key()
	if sheets.has(key):return sheets[key]
	var image:=Image.create(CELL.x*5,CELL.y*8,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	# Native image blits compose the indexed sheets once, not per frame/pixel
	# in GDScript. All poses share exactly the same canvas and foot anchor.
	for layer in ["body","clothing","hair","accessory","hat"]:
		var path:String=BASE+layer+"/"+String(data.get(layer))+".png"
		if not images.has(path):
			var texture:=load(path) as Texture2D
			if texture==null:return {}
			var source:=texture.get_image();source.convert(Image.FORMAT_RGBA8);images[path]=source
		var source:Image=images[path]
		image.blit_rect_mask(source,source,Rect2i(Vector2i.ZERO,source.get_size()),Vector2i.ZERO)
	var texture:=ImageTexture.create_from_image(image)
	var frames:=SpriteFrames.new();frames.remove_animation("default");frames.set_meta("modular_character",true)
	for row in 4:
		for mode in ["idle","walk","run"]:
			var animation:String=mode+"_"+CharacterSheet.DIRECTIONS[row]
			frames.add_animation(animation);frames.set_animation_speed(animation,8.0 if mode=="run" else 6.0)
			for col in ([0] if mode=="idle" else [1,2,3,4]):
				var atlas:=AtlasTexture.new();atlas.atlas=texture
				atlas.region=Rect2(Vector2i(col,row+(4 if mode=="run" else 0))*CELL,CELL);atlas.filter_clip=true
				frames.add_frame(animation,atlas)
	sheets[key]={"frames":frames,"texture":texture,"cell":Vector2(CELL)}
	return sheets[key]

static func apply_geometry(sprite:AnimatedSprite2D)->void:
	var data:AppearanceData=sprite.get_meta("appearance_data")
	sprite.scale=Vector2.ONE*(68.0*data.stature/ART_HEIGHT)
	sprite.position=Vector2(0,2.0-(SOLE_Y-CELL.y/2.0)*sprite.scale.y)
