class_name HybridWorld
extends Node3D

# Render the existing XY simulation on the XZ ground plane. Collision,
# schedules and saved positions retain their original world coordinates.
const UNIT := 64.0
const BILLBOARD_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;
uniform sampler2D art : source_color, filter_nearest;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 frame_uv = vec4(0.0,0.0,1.0,1.0);
uniform vec2 tex_size = vec2(1.0);
uniform float wind = 0.0;
uniform float phase = 0.0;
uniform float vitality = 1.0;
uniform vec4 clothing_tint : source_color = vec4(1.0);
uniform vec3 day_color : source_color = vec3(1.0);
uniform bool face_camera = true;
void vertex() {
 if(face_camera) MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
 vec2 local = (UV-frame_uv.xy)/frame_uv.zw;
 vec2 uv=UV;
 uv.x -= sin(TIME*0.68+phase)*wind*(1.0-smoothstep(0.43,0.77,local.y))/tex_size.x;
 uv=clamp(uv,frame_uv.xy+0.5/tex_size,frame_uv.xy+frame_uv.zw-0.5/tex_size);
 vec4 c=texture(art,uv);
 float key=min(c.r,c.b)-c.g;
 c.a*=1.0-smoothstep(0.08,0.3,key);
 if(c.a*tint.a<0.12) discard;
 float gray=dot(c.rgb,vec3(0.299,0.587,0.114));
 float cloth=step(0.44,local.y)*step(local.y,0.68)*step(0.08,c.r)*step(c.r,0.68)*smoothstep(0.06,0.18,c.r-c.g);
 c.rgb=mix(c.rgb,c.rgb*clothing_tint.rgb,cloth*0.55);
 ALBEDO=mix(vec3(gray)*vec3(0.86,0.87,0.81),c.rgb,vitality)*tint.rgb*day_color;
 ALPHA=c.a*tint.a;
}
"""
var game: ForestGame
var camera: Camera3D
var ground_view: SubViewport
var actors: Array[Dictionary] = []
var tree_cards: Array[Dictionary] = []
var sunlight: DirectionalLight3D
var atmosphere: WorldEnvironment
var baked: Dictionary = {}
var pickups: Array[Dictionary] = []
var shader: Shader
var river_material: StandardMaterial3D
var facade_materials: Array[ShaderMaterial] = []

func setup(source: ForestGame) -> void:
	game=source
	shader=Shader.new()
	shader.code=BILLBOARD_SHADER
	_ground()
	_lighting()
	_buildings()
	_bridge()
	_water()
	_landmarks()
	for tree in game.world.trees:
		var card:=_card(tree.sprite)
		card.position=_point(tree.body.position)
		tree_cards.append({"card":card,"source":tree})
	for body in [game.player]+game.world.npcs.values():
		var card:=_card(body.sprite)
		actors.append({"card":card,"body":body})
		if body is ForestNPC:
			var label:=Label3D.new()
			label.text=body.definition.name
			label.font_size=32
			label.pixel_size=0.007
			label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
			label.no_depth_test=true
			add_child(label)
			actors.append({"label":label,"body":body})
		_shadow(body)
	camera=Camera3D.new()
	camera.name="HybridCamera"
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=13.0
	camera.far=120.0
	add_child(camera)
	camera.current=true
	_follow(true)
	game.camera.enabled=false
	game.world.visible=false
	get_viewport().canvas_transform=Transform2D.IDENTITY

func _point(p:Vector2)->Vector3:
	return Vector3(p.x/UNIT,0,p.y/UNIT)

func _ground()->void:
	ground_view=SubViewport.new()
	ground_view.name="GroundTexture"
	ground_view.size=Vector2i(3200,2560)
	ground_view.disable_3d=true
	ground_view.world_2d=World2D.new()
	ground_view.render_target_update_mode=SubViewport.UPDATE_ONCE
	add_child(ground_view)
	var tiles:=game.world.get_node("GrassTiles").duplicate() as TileMapLayer
	ground_view.add_child(tiles)
	var paths:=ForestTerrain.new()
	paths.build()
	ground_view.add_child(paths)
	var plane:=PlaneMesh.new()
	plane.size=Vector2(50,40)
	var material:=StandardMaterial3D.new()
	material.albedo_texture=ground_view.get_texture()
	material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness=1.0
	var mesh:=MeshInstance3D.new()
	mesh.name="Ground3D"
	mesh.mesh=plane
	mesh.material_override=material
	mesh.position=Vector3(25,-0.025,20)
	add_child(mesh)
	_box(Vector3(25,-0.3,20),Vector3(50,0.5,40),Color("574532"))

func _lighting()->void:
	atmosphere=WorldEnvironment.new()
	atmosphere.environment=Environment.new()
	atmosphere.environment.background_mode=Environment.BG_COLOR
	atmosphere.environment.background_color=Color("263b38")
	atmosphere.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	atmosphere.environment.ambient_light_color=Color("d6dfcf")
	atmosphere.environment.ambient_light_energy=0.4
	add_child(atmosphere)
	sunlight=DirectionalLight3D.new()
	sunlight.rotation_degrees=Vector3(-55,-28,0)
	sunlight.light_energy=0.65
	sunlight.shadow_enabled=true
	add_child(sunlight)

func _box(at:Vector3,size:Vector3,color:Color)->MeshInstance3D:
	var node:=MeshInstance3D.new()
	var mesh:=BoxMesh.new()
	mesh.size=size
	node.mesh=mesh
	var material:=StandardMaterial3D.new()
	material.albedo_color=color
	material.roughness=1.0
	node.material_override=material
	node.position=at
	add_child(node)
	return node

func _buildings()->void:
	var texture:Texture2D=load("res://assets/tomate/villages.png")
	var regions: Array=load("res://game/settlements.gd").REGIONS
	for index in KingdomData.BUILDINGS.size():
		var data:Dictionary=KingdomData.BUILDINGS[index]
		var rect:=KingdomData.building_rect(data)
		var center:=_point(rect.get_center())
		var width:=rect.size.x/UNIT
		var depth:=rect.size.y/UNIT
		var height:=width*0.6
		var color:=Color("bba88c") if data.realm=="aurelia" else Color("9ba9a5")
		var style:=0 if data.realm=="aurelia" else 1
		if data.kind in ["home","market"] and index%2==0: style=2
		_box(center+Vector3(0,height/2,0),Vector3(width,height,depth),color)
		var roof:=MeshInstance3D.new()
		var prism:=PrismMesh.new()
		prism.size=Vector3(width*1.14,height*0.55,depth*1.15)
		roof.mesh=prism
		roof.position=center+Vector3(0,height+height*0.275,0)
		var mat:=StandardMaterial3D.new()
		var roof_art:=AtlasTexture.new()
		roof_art.atlas=texture
		var roof_region:Rect2=regions[style]
		roof_art.region=Rect2(roof_region.position+roof_region.size*Vector2(0.3,0.2),roof_region.size*Vector2(0.4,0.12))
		mat.albedo_texture=_bake(roof_art)
		mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.uv1_scale=Vector3(4,4,1)
		mat.roughness=1.0
		roof.material_override=mat
		add_child(roof)
		var atlas:=AtlasTexture.new()
		atlas.atlas=texture
		# Use the supplied house's wall/door artwork on a solid 3D facade.
		# The roof is geometry, so perspective never reveals a second painted roof.
		var region:Rect2=regions[style]
		atlas.region=Rect2(region.position+region.size*Vector2(0.12,0.55),region.size*Vector2(0.76,0.45))
		var face:=Sprite3D.new()
		face.texture=_bake(atlas)
		face.centered=false
		face.offset=Vector2(-face.texture.get_width()/2.0,0)
		face.pixel_size=width/face.texture.get_width()
		face.position=_point(Vector2(rect.get_center().x,rect.end.y))+Vector3(0,0.02,0.025)
		var facade_material:=_material(face.texture)
		facade_material.set_shader_parameter("face_camera",false)
		facade_materials.append(facade_material)
		face.material_override=facade_material
		add_child(face)

func _bridge()->void:
	var left:=35.7*WorldData.TILE/UNIT
	var right:=41.2*WorldData.TILE/UNIT
	var z:=20.0*WorldData.TILE/UNIT
	_box(Vector3((left+right)/2,0.015,z),Vector3(right-left,0.12,1.0),Color("8d6e45"))
	for i in 23:
		var x:=lerpf(left,right,float(i)/22)
		_box(Vector3(x,0.09,z),Vector3(0.21,0.04,1.02),Color("b59a67"))
	for side in [-1,1]:
		_box(Vector3((left+right)/2,0.45,z+side*0.55),Vector3(right-left,0.1,0.08),Color("80623d"))
		for i in 5:
			_box(Vector3(lerpf(left,right,i/4.0),0.25,z+side*0.55),Vector3(0.1,0.55,0.1),Color("705234"))

func _water()->void:
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 80:
		var y0:=i*WorldData.SIZE.y/80
		var y1:=(i+1)*WorldData.SIZE.y/80
		var a:=_point(Vector2(WorldData.river_x(y0)-80,y0))
		var b:=_point(Vector2(WorldData.river_x(y0)+80,y0))
		var c:=_point(Vector2(WorldData.river_x(y1)-80,y1))
		var d:=_point(Vector2(WorldData.river_x(y1)+80,y1))
		for v in [a,c,b,b,c,d]:
			surface.set_uv(Vector2(v.x,v.z))
			surface.add_vertex(v+Vector3(0,-0.005,0))
	surface.generate_normals()
	var node:=MeshInstance3D.new()
	node.mesh=surface.commit()
	var mat:=StandardMaterial3D.new()
	mat.albedo_texture=GroundAtlas.water_frames()[0]
	mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.roughness=0.35
	mat.uv1_scale=Vector3.ONE
	node.material_override=mat
	node.name="River3D"
	river_material=mat
	add_child(node)

func _material(texture:Texture2D)->ShaderMaterial:
	var mat:=ShaderMaterial.new()
	mat.shader=shader
	var source:=texture
	var region:=Rect2(Vector2.ZERO,texture.get_size())
	if texture is AtlasTexture:
		source=texture.atlas
		region=texture.region
	mat.set_shader_parameter("art",source)
	mat.set_shader_parameter("tex_size",source.get_size())
	mat.set_shader_parameter("frame_uv",Vector4(region.position.x/source.get_width(),region.position.y/source.get_height(),region.size.x/source.get_width(),region.size.y/source.get_height()))
	return mat

func _card(source:AnimatedSprite2D)->Sprite3D:
	var card:=Sprite3D.new()
	card.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	card.texture=_bake(source.sprite_frames.get_frame_texture(source.animation,source.frame))
	card.material_override=_material(card.texture)
	add_child(card)
	_sync(card,source)
	return card

func _sync(card:Sprite3D,source:AnimatedSprite2D)->void:
	var tex:=_bake(source.sprite_frames.get_frame_texture(source.animation,source.frame))
	if card.texture!=tex:
		card.texture=tex
		card.material_override=_material(tex)
	card.pixel_size=source.scale.x/UNIT
	card.offset=source.position/source.scale+source.offset
	card.offset.y=-card.offset.y
	if not source.centered:
		card.offset.y-=tex.get_height()
	card.centered=source.centered
	card.flip_h=source.flip_h
	var mat:=card.material_override as ShaderMaterial
	mat.set_shader_parameter("tint",source.modulate)
	mat.set_shader_parameter("day_color",Vector3(game.world.daylight.color.r,game.world.daylight.color.g,game.world.daylight.color.b))
	if source.material is ShaderMaterial and TomateCharacterSheet.is_sheet(source.sprite_frames):
		mat.set_shader_parameter("clothing_tint",source.material.get_shader_parameter("clothing_tint"))

func _shadow(body:Node2D)->void:
	var shadow:=MeshInstance3D.new()
	var mesh:=PlaneMesh.new()
	mesh.size=Vector2(0.45,0.24)
	shadow.mesh=mesh
	var mat:=StandardMaterial3D.new()
	mat.albedo_color=Color(0.08,0.12,0.08,0.3)
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow.material_override=mat
	add_child(shadow)
	actors.append({"shadow":shadow,"body":body})

func _process(delta:float)->void:
	if game==null: return
	for actor in actors:
		if actor.has("label"):
			actor.label.position=_point(actor.body.position)+Vector3(0,1.5,0)
			actor.label.visible=actor.body.visible
		elif actor.has("shadow"):
			actor.shadow.position=_point(actor.body.position)+Vector3(0,0.005,0)
			actor.shadow.visible=actor.body.visible
		else:
			_sync(actor.card,actor.body.sprite)
			actor.card.position=_point(actor.body.position)
			actor.card.visible=actor.body.visible
	for entry in tree_cards:
		_sync(entry.card,entry.source.sprite)
		entry.card.material_override.set_shader_parameter("wind",8.0)
		entry.card.material_override.set_shader_parameter("phase",entry.card.position.x*0.17+entry.card.position.z*0.11)
		entry.card.material_override.set_shader_parameter("vitality",game.world.mother_material.get_shader_parameter("vitality") if entry.source.sprite==game.world.mother_sprite else 1.0)
		var distance:Vector3=entry.card.position-_point(game.player.position)
		var height:float=entry.card.texture.get_height()*entry.source.sprite.scale.y/UNIT
		var obscures:=distance.z>0.0 and distance.z<height*1.5 and absf(distance.x)<height*0.4
		var color:Color=entry.source.sprite.modulate
		color.a=lerpf(entry.get("opacity",1.0),0.25 if obscures else 1.0,1.0-exp(-8.0*delta))
		entry.opacity=color.a
		entry.card.material_override.set_shader_parameter("tint",color)
	for item in pickups:
		item.node.visible=not game.collected.has(item.id)
		item.node.position.y=0.25+sin(Time.get_ticks_msec()*0.002+item.phase)*0.07
	sunlight.light_color=game.world.daylight.color
	atmosphere.environment.ambient_light_color=game.world.daylight.color
	for material in facade_materials:
		material.set_shader_parameter("day_color",Vector3(game.world.daylight.color.r,game.world.daylight.color.g,game.world.daylight.color.b))
	river_material.uv1_offset.y+=delta*0.018
	_follow(false,delta)

func _follow(snap:bool,delta:float=0.016)->void:
	var target:=_point(game.player.position)
	var desired:=target+Vector3(0,12,14)
	camera.position=desired if snap else camera.position.lerp(desired,1.0-exp(-9.0*delta))
	camera.look_at(target+Vector3(0,0.3,0))

func snap_camera()->void:
	_follow(true)

func screen_position(point:Vector2)->Vector2:
	return camera.unproject_position(_point(point)+Vector3(0,0.7,0))

func _bake(texture:Texture2D)->Texture2D:
	# Sprite3D needs a real texture: retain each atlas frame's padded pivot
	# instead of sampling neighboring poses from the source sheet.
	if not texture is AtlasTexture: return texture
	var key:=texture.get_instance_id()
	if not baked.has(key):
		var image:=Image.create(int(texture.get_width()),int(texture.get_height()),false,Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		var source_image:Image=texture.atlas.get_image()
		source_image.convert(Image.FORMAT_RGBA8)
		image.blit_rect(source_image,Rect2i(texture.region),Vector2i(texture.margin.position))
		baked[key]=ImageTexture.create_from_image(image)
	return baked[key]

func _landmarks()->void:
	for data in WorldData.SEEDS:
		var node:=MeshInstance3D.new()
		var mesh:=SphereMesh.new()
		mesh.radius=0.1
		mesh.height=0.23
		node.mesh=mesh
		var mat:=StandardMaterial3D.new()
		mat.albedo_color=Color("ffe388")
		mat.emission_enabled=true
		mat.emission=Color("d8a642")
		node.material_override=mat
		node.position=_point(data.position)+Vector3(0,0.25,0)
		add_child(node)
		pickups.append({"node":node,"id":data.id,"phase":pickups.size()})
	var camp:=_point(WorldData.CAMP)
	var tent:=MeshInstance3D.new()
	var prism:=PrismMesh.new()
	prism.size=Vector3(1.8,1.3,1.5)
	tent.mesh=prism
	tent.position=camp+Vector3(0,0.65,0)
	var cloth:=StandardMaterial3D.new()
	cloth.albedo_color=Color("bba878")
	tent.material_override=cloth
	add_child(tent)
	var sign:=_point(WorldData.SIGN)
	_box(sign+Vector3(0,0.35,0),Vector3(0.08,0.7,0.08),Color("735636"))
	_box(sign+Vector3(0,0.62,0),Vector3(0.65,0.22,0.08),Color("ad8b56"))
	var mother:=Label3D.new()
	mother.text="ÁRVORE-MÃE"
	mother.position=_point(WorldData.MOTHER)+Vector3(0,3.5,0)
	mother.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	mother.no_depth_test=true
	mother.font_size=40
	mother.pixel_size=0.008
	add_child(mother)
