class_name PixelArt
extends RefCounted

const FONT:="res://assets/ui/rpg_pixel.fnt"
static var textures:Dictionary={}

static func icon(kind:String)->Texture2D:
	if textures.has(kind):return textures[kind]
	var image:=Image.create(16,16,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var wood:=Color("a37746");var metal:=Color("cbd9db");var gold:=Color("e3bb66")
	match kind:
		"torch_post","torch_0","torch_1","torch_2":
			for y in range(8,16):image.set_pixel(7,y,wood);image.set_pixel(8,y,Color("64432b"))
			for x in range(5,11):image.set_pixel(x,9,Color("49413a"))
			if kind!="torch_post":
				var phase:=int(kind.right(1))
				for y in range(2,9):
					var half:=1 if y<4 else (3 if y>5 else 2)
					for x in range(8-half,8+half):image.set_pixel(x+(phase-1 if y<5 else 0),y,Color("ffb44f") if x%3 else Color("e96932"))
				for y in range(5,9):image.set_pixel(7,y,Color("ffe9a3"));image.set_pixel(8,y,Color("ffe9a3"))
		"sword":
			for i in 10:
				for j in 3:image.set_pixel(11-i,1+i+j,metal if j<2 else Color("7d919d"))
			for i in 5:image.set_pixel(2+i,9+i,gold)
			for i in 4:image.set_pixel(2+i,13-i,wood)
		"axe","pickaxe":
			for i in range(3,14):image.set_pixel(7,i,wood);image.set_pixel(8,i,Color("775237"))
			for y in range(2,6):
				for x in range(3,13):
					if kind=="axe" and x>8 or kind=="pickaxe" and y<4 or x in [3,4]:image.set_pixel(x,y,metal)
		"hammer":
			for y in range(5,14):image.set_pixel(7,y,wood);image.set_pixel(8,y,wood)
			for y in range(2,7):
				for x in range(3,13):image.set_pixel(x,y,metal if y<5 else Color("6e7b8b"))
		"bread":
			for y in range(4,13):
				for x in range(2,14):
					if (Vector2(x,y)-Vector2(7.5,8)).length()<6:image.set_pixel(x,y,Color("dca75d") if y<10 else wood)
			for i in [4,7,10]:image.set_pixel(i,6,Color("f2d793"));image.set_pixel(i,7,Color("f2d793"))
		"map","journal":
			for y in range(2,14):
				for x in range(3,13):image.set_pixel(x,y,Color("d8ca9f") if kind=="map" else Color("80614b"))
			for y in range(4,12,3):
				for x in range(5,11):image.set_pixel(x,y,Color("7d9165") if kind=="map" else gold)
		"lantern":
			for y in range(4,13):
				for x in range(4,12):image.set_pixel(x,y,gold if x in [4,11] or y in [4,12] else Color("ffe4a1"))
			for x in range(6,10):image.set_pixel(x,2,wood);image.set_pixel(x,3,wood)
		"heart":
			for y in range(3,13):
				for x in range(2,14):
					if y<8 and (Vector2(x,y)-Vector2(5,5)).length()<3.5 or y<8 and (Vector2(x,y)-Vector2(10,5)).length()<3.5 or y>=7 and absf(x-7.5)<(13-y):image.set_pixel(x,y,Color("d66a68"))
	textures[kind]=ImageTexture.create_from_image(image)
	return textures[kind]
