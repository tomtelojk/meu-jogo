class_name NaturalLandscape
extends RefCounted

static var noise:FastNoiseLite
static var mask:Texture2D
static var _groves:Dictionary={}

static func river_center(y:float)->float:
	return 8000+(field(Vector2(28000,y),0.7)-0.5)*2000+sin(y*0.00095)*220

static func river_width(y:float)->float:
	return 115+field(Vector2(39000,y),1.1)*190

static func field(at:Vector2,scale:float=1.0)->float:
	if noise==null:
		noise=FastNoiseLite.new();noise.seed=88277;noise.noise_type=FastNoiseLite.TYPE_SIMPLEX_SMOOTH;noise.frequency=0.00075;noise.fractal_octaves=3
	return noise.get_noise_2d(at.x*scale,at.y*scale)*0.5+0.5

static func weights(at:Vector2)->Color:
	var broad:=field(at)
	var rock:=smoothstep(3100,1700,at.y+(broad-0.5)*1800)*smoothstep(2300,3600,at.x)
	var sand:=smoothstep(11000,12200,at.y+(field(at+Vector2(904,1230))-0.5)*1500)
	var dry:=clampf((0.62-field(at+Vector2(6900,0)))*2.4,0,0.85)
	return Color(rock,sand,dry,1)

static func texture()->Texture2D:
	if mask==null:
		var image:=Image.create(250,200,false,Image.FORMAT_RGBA8)
		for y in 200:
			for x in 250:image.set_pixel(x,y,weights(Vector2(x+0.5,y+0.5)*64))
		mask=ImageTexture.create_from_image(image)
	return mask

static func grove(center:Vector2,kind:String)->Array[Vector2]:
	var key:="%s:%s"%[center,kind]
	if not _groves.has(key):
		var rng:=RandomNumberGenerator.new();rng.seed=key.hash()^57207
		var points:Array[Vector2]=[]
		for i in 20:
			var p:=center
			for attempt in 80:
				p=center+Vector2.from_angle(rng.randf()*TAU)*sqrt(rng.randf())*190
				var free:=true
				for other in points:
					if other.distance_to(p)<35:free=false;break
				if free:break
			points.append(p)
		_groves[key]=points
	return _groves[key]
