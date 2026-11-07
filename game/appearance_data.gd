class_name AppearanceData
extends Resource

## A role template exposes choices; a generated instance stores the chosen kit.
@export var body_options:=PackedStringArray(["regular","round","angular"])
@export var hair_options:=PackedStringArray(["cropped","wavy","long","braid","bun","beard","bald"])
@export var clothing_options:=PackedStringArray(["tunic","workshirt","dress"])
@export var accessory_options:=PackedStringArray(["none","pouch","scarf","satchel"])
@export var hat_options:=PackedStringArray(["none","cap","straw","headscarf"])
@export var body:="regular"
@export var hair:="cropped"
@export var clothing:="tunic"
@export var accessory:="none"
@export var hat:="none"
@export_color_no_alpha var skin:=Color("cb956c")
@export_color_no_alpha var hair_color:=Color("69452e")
@export_color_no_alpha var clothing_color:=Color("607557")
@export_color_no_alpha var accent_color:=Color("bb9859")
@export_color_no_alpha var leather_color:=Color("76523b")
@export_color_no_alpha var metal_color:=Color("9da4aa")
@export_color_no_alpha var eye_color:=Color("354839")
@export_range(0.94,1.06) var stature:=1.0
@export_range(0.8,1.3) var voice_pitch:=1.0
@export_range(0,4) var voice_timbre:=0
@export_range(0.07,0.14) var voice_cadence:=0.1
@export var speech_style:=0
@export var seed:int=0
@export var variant:int=0
@export var role:="peasant"
@export var faction:=""
@export var display_name:=""

func piece_key()->String:
	return "|".join([body,hair,clothing,accessory,hat])

func visual_key()->String:
	return piece_key()+"|"+skin.to_html(false)+"|"+hair_color.to_html(false)+"|"+clothing_color.to_html(false)+"|"+accent_color.to_html(false)

func palette()->PackedColorArray:
	var colors:=PackedColorArray();colors.resize(32);colors.fill(Color.TRANSPARENT)
	colors[1]=Color("211d22")
	for entry in [[2,skin],[5,hair_color],[8,clothing_color],[11,accent_color],[14,leather_color],[17,metal_color]]:
		var at:int=entry[0];var base:Color=entry[1]
		colors[at]=base.darkened(0.32);colors[at+1]=base;colors[at+2]=base.lightened(0.24)
	colors[20]=Color("f5e7d0");colors[21]=eye_color;colors[22]=Color("fff7df")
	colors[24]=skin.lerp(Color("ab6152"),0.28)
	return colors

func palette_texture()->ImageTexture:
	var image:=Image.create(32,1,false,Image.FORMAT_RGBA8)
	var colors:=palette()
	for i in colors.size():image.set_pixel(i,0,colors[i])
	return ImageTexture.create_from_image(image)
