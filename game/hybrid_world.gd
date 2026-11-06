class_name HybridWorld
extends Node3D

# Render the existing XY simulation on the XZ ground plane. Collision,
# schedules and saved positions retain their original world coordinates.
const UNIT := 64.0
const BILLBOARD_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;
#include "res://game/shaders/pixel_lighting.gdshaderinc"
uniform sampler2D art : source_color, filter_nearest;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 frame_uv = vec4(0.0,0.0,1.0,1.0);
uniform vec2 tex_size = vec2(1.0);
uniform vec4 clothing_tint : source_color = vec4(1.0);
uniform vec3 day_color : source_color = vec3(1.0);
uniform bool face_camera = true;
uniform float swim_amount = 0.0;
void vertex() {
 pixel_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 if(face_camera) MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
 vec2 local = (UV-frame_uv.xy)/frame_uv.zw;
 vec2 uv = clamp(UV,frame_uv.xy+0.5/tex_size,frame_uv.xy+frame_uv.zw-0.5/tex_size);
 vec4 c=texture(art,uv);
 float key=min(c.r,c.b)-c.g;
 c.a*=1.0-smoothstep(0.08,0.3,key);
 c.a*=mix(1.0,1.0-smoothstep(0.57,0.61,local.y),swim_amount);
 if(c.a*tint.a<0.12) discard;
 float cloth=step(0.44,local.y)*step(local.y,0.68)*step(0.08,c.r)*step(c.r,0.68)*smoothstep(0.06,0.18,c.r-c.g);
 c.rgb=mix(c.rgb,c.rgb*clothing_tint.rgb,cloth*0.55);
 ALBEDO=c.rgb*tint.rgb*(day_color+pixel_local_light(pixel_world));
 ALPHA=c.a*tint.a;
}
"""
# Cutout foliage writes depth in one pass. Alpha blending and repeated
# per-pixel chroma/tint calculations made the dense forest fill-rate bound.
const FOLIAGE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;
#include "res://game/shaders/pixel_lighting.gdshaderinc"
uniform sampler2D art : source_color, filter_nearest;
uniform vec2 tex_size = vec2(600.0,800.0);
uniform vec4 tint : source_color = vec4(1.0);
uniform vec3 day_color : source_color = vec3(1.0);
uniform vec2 hero_position = vec2(-100.0);
uniform float wind = 0.125;
uniform float vitality = 1.0;
uniform float foliage_height = 0.0;
varying float opacity;
void vertex() {
 pixel_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 vec3 root = MODEL_MATRIX[3].xyz;
 vec3 scale = vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
 float height = foliage_height > 0.0 ? foliage_height : tex_size.y/64.0*scale.y;
 vec2 d = root.xz-hero_position;
 float side = 1.0-smoothstep(height*0.3,height*0.42,abs(d.x));
 float front = smoothstep(0.0,0.25,d.y)*(1.0-smoothstep(height*1.25,height*1.5,d.y));
 opacity = mix(1.0,0.25,side*front);
 VERTEX.x += sin(TIME*0.68+root.x*0.17+root.z*0.11)*wind*(1.0-smoothstep(0.43,0.77,UV.y));
 MODELVIEW_MATRIX = VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*scale.x,INV_VIEW_MATRIX[1]*scale.y,INV_VIEW_MATRIX[2]*scale.z,MODEL_MATRIX[3]);
}
void fragment() {
 vec4 c = texture(art,UV);
 if(c.a<0.5 || min(c.r,c.b)-c.g>0.18) discard;
 // A four-pixel screen-door fade keeps early depth testing available and
 // lets the hero remain visible without sorting hundreds of alpha cards.
 float pattern = fract(dot(floor(FRAGCOORD.xy),vec2(0.5,0.25)))+0.125;
 if(pattern>opacity) discard;
 if(vitality<0.99) {
  float gray = dot(c.rgb,vec3(0.299,0.587,0.114));
  c.rgb = mix(vec3(gray)*vec3(0.86,0.87,0.81),c.rgb,vitality);
 }
 ALBEDO = c.rgb*(day_color+pixel_local_light(pixel_world));
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
var foliage_shader: Shader
var river_material: ShaderMaterial
var facade_materials: Array[ShaderMaterial] = []
var foliage_materials: Array[ShaderMaterial] = []
var tree_batches: Array[MultiMeshInstance3D] = []
var mother_card: Sprite3D
var swim_ripple: MeshInstance3D
var last_daylight := Color(-1,-1,-1)
var landscape:StreamedLandscape
var build_ghost:MeshInstance3D
var grade:CanvasLayer
var grade_rect:ColorRect
var shaders_enabled:=true
var architecture:Node3D
var lantern:OmniLight3D
var street_lamps:Array[OmniLight3D]=[]
var lamp_posts:Array[Sprite3D]=[]
var held_tool:Sprite3D
var light_timer:=0.0
var pixel_light_timer:=0.0
var resource_fx:ResourceEffects

func setup(source: ForestGame) -> void:
	game=source
	shader=Shader.new()
	shader.code=BILLBOARD_SHADER
	foliage_shader=Shader.new()
	foliage_shader.code=FOLIAGE_SHADER
	_water()
	_ground()
	_lighting()
	_local_lights()
	_buildings()
	_bridge()
	_landmarks()
	_build_forest()
	resource_fx=ResourceEffects.new();add_child(resource_fx);resource_fx.setup(self)
	_settlement_labels()
	for body in [game.player]+game.world.npcs.values():
		var card:=_card(body.sprite)
		actors.append({"card":card,"body":body})
		if body is ForestNPC:
			var label:=Label3D.new()
			label.text=body.definition.name
			label.font_size=32
			label.font=load(PixelArt.FONT)
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
	game.world.hybrid_rendering=true
	get_viewport().canvas_transform=Transform2D.IDENTITY
	set_light_graphics(game.light_graphics)
	_color_grade()
	set_shaders(game.shaders_enabled)
	game.world.clock.minute_changed.connect(_update_light)

func set_light_graphics(enabled:bool)->void:
	# Scale only the 3D buffer. HUD, text, menus and input keep native resolution.
	get_viewport().scaling_3d_scale=0.65 if enabled else 1.0
	if grade_rect!=null:grade_rect.visible=shaders_enabled and not enabled
	if sunlight!=null:sunlight.shadow_enabled=not enabled and shaders_enabled

func _point(p:Vector2)->Vector3:
	return Vector3(p.x/UNIT,0,p.y/UNIT)

func _ground()->void:
	landscape=StreamedLandscape.new()
	landscape.name="Ground3D"
	add_child(landscape)
	landscape.setup(self)

func _lighting()->void:
	atmosphere=WorldEnvironment.new()
	atmosphere.environment=Environment.new()
	atmosphere.environment.background_mode=Environment.BG_COLOR
	atmosphere.environment.background_color=Color("263b38")
	atmosphere.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	atmosphere.environment.ambient_light_color=Color("d6dfcf")
	atmosphere.environment.ambient_light_energy=0.4
	atmosphere.environment.fog_enabled=true
	atmosphere.environment.fog_mode=Environment.FOG_MODE_DEPTH
	atmosphere.environment.fog_light_color=Color("889ba4")
	atmosphere.environment.fog_depth_begin=18
	atmosphere.environment.fog_depth_end=30
	atmosphere.environment.fog_density=0.32
	atmosphere.environment.fog_sun_scatter=0.15
	add_child(atmosphere)
	sunlight=DirectionalLight3D.new()
	sunlight.rotation_degrees=Vector3(-55,-28,0)
	sunlight.light_energy=0.65
	sunlight.shadow_enabled=false
	sunlight.directional_shadow_mode=DirectionalLight3D.SHADOW_ORTHOGONAL
	sunlight.directional_shadow_max_distance=35.0
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
	architecture=Node3D.new()
	architecture.name="Architecture"
	add_child(architecture)
	for data in KingdomData.buildings():
		var model:=BuildingVisual.new()
		model.setup(data)
		architecture.add_child(model)

func _bridge()->void:
	for rect in WorldData.bridges():_bridge_mesh(rect)

func _bridge_mesh(rect:Rect2)->void:
	# One instanced box mesh for all planks, sloping rails and supports.
	# Physics uses these same floor/rail dimensions in WorldData.
	var parts: Array[Dictionary]=[]
	var z:=rect.get_center().y/UNIT
	for i in 28:
		var x0:=lerpf(rect.position.x,rect.end.x,i/28.0)
		var x1:=lerpf(rect.position.x,rect.end.x,(i+1)/28.0)
		var h0:=WorldData.bridge_height(Vector2(x0,rect.get_center().y))
		var h1:=WorldData.bridge_height(Vector2(x1,rect.get_center().y))
		var angle:=atan2(h1-h0,x1-x0)
		var size:=Vector3(Vector2(x1-x0,h1-h0).length()/UNIT+0.008,0.075,rect.size.y/UNIT)
		parts.append({"at":Vector3((x0+x1)/2/UNIT,(h0+h1)/2/UNIT-0.0375,z),"size":size,"angle":angle,"color":Color("b59a67") if i%2==0 else Color("ac8d5c")})
	var stops: Array[float]=[rect.position.x,rect.position.x+WorldData.BRIDGE_RAMP,rect.get_center().x,rect.end.x-WorldData.BRIDGE_RAMP,rect.end.x]
	for rail in WorldData.rails_for_bridge(rect):
		var rail_z:=rail.get_center().y/UNIT
		for x in stops:
			var height:=WorldData.bridge_height(Vector2(x,rect.get_center().y))/UNIT
			parts.append({"at":Vector3(x/UNIT,height+0.25,rail_z),"size":Vector3(0.1,0.55,rail.size.y/UNIT),"angle":0.0,"color":Color("705234")})
		for i in range(1,stops.size()):
			var x0:=stops[i-1]/UNIT
			var x1:=stops[i]/UNIT
			var h0:=WorldData.bridge_height(Vector2(stops[i-1],rect.get_center().y))/UNIT+0.48
			var h1:=WorldData.bridge_height(Vector2(stops[i],rect.get_center().y))/UNIT+0.48
			parts.append({"at":Vector3((x0+x1)/2,(h0+h1)/2,rail_z),"size":Vector3(Vector2(x1-x0,h1-h0).length(),0.1,rail.size.y/UNIT),"angle":atan2(h1-h0,x1-x0),"color":Color("80623d")})
	var multi:=MultiMesh.new()
	multi.transform_format=MultiMesh.TRANSFORM_3D
	multi.use_colors=true
	multi.mesh=BoxMesh.new()
	multi.instance_count=parts.size()
	for i in parts.size():
		var part:Dictionary=parts[i]
		multi.set_instance_transform(i,Transform3D(Basis(Vector3.FORWARD,part.angle)*Basis.from_scale(part.size),part.at))
		multi.set_instance_color(i,part.color)
	var node:=MultiMeshInstance3D.new()
	node.name="Bridge3D"
	node.multimesh=multi
	var material:=StandardMaterial3D.new()
	material.vertex_color_use_as_albedo=true
	material.roughness=1.0
	node.material_override=material
	add_child(node)

func _water()->void:
	river_material=ShaderMaterial.new()
	river_material.shader=load("res://game/shaders/water.gdshader")
	river_material.set_shader_parameter("art",GroundAtlas.water_frames()[0])
	river_material.set_shader_parameter("edits",MapDocument.water_mask())
	if not MapDocument.base_enabled():return
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 400:
		var y0:=i*WorldData.SIZE.y/400
		var y1:=(i+1)*WorldData.SIZE.y/400
		var a:=_point(Vector2(WorldData.river_x(y0)-WorldData.river_width(y0),y0))
		var b:=_point(Vector2(WorldData.river_x(y0)+WorldData.river_width(y0),y0))
		var c:=_point(Vector2(WorldData.river_x(y1)-WorldData.river_width(y1),y1))
		var d:=_point(Vector2(WorldData.river_x(y1)+WorldData.river_width(y1),y1))
		var vertices:Array[Vector3]=[a,c,b,b,c,d]
		for index in 6:
			var v:Vector3=vertices[index]
			surface.set_uv(Vector2(v.x,v.z))
			surface.set_uv2(Vector2(-1 if index in [0,1,4] else 1,0))
			surface.add_vertex(v+Vector3(0,-0.005,0))
	surface.generate_normals()
	var node:=MeshInstance3D.new()
	node.mesh=surface.commit()
	node.material_override=river_material
	node.name="River3D"
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

func _forest_material(texture:Texture2D)->ShaderMaterial:
	var material:=ShaderMaterial.new()
	material.shader=foliage_shader
	material.set_shader_parameter("art",texture)
	material.set_shader_parameter("tex_size",texture.get_size())
	return material

func _build_forest()->void:
	var tree:Dictionary=game.world.mother_entry
	mother_card=_card(tree.sprite)
	mother_card.position=_point(tree.body.position)
	var material:=_forest_material(mother_card.texture)
	mother_card.material_override=material
	material.set_shader_parameter("foliage_height",TreeAtlas.FRAME_SIZE.y*tree.sprite.scale.y/UNIT)
	material.set_shader_parameter("wind",8.0*tree.sprite.scale.x/UNIT)
	foliage_materials.append(material)

func _card(source:AnimatedSprite2D)->Sprite3D:
	var card:=Sprite3D.new()
	card.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
		card.material_override.set_shader_parameter("art",tex)
		card.material_override.set_shader_parameter("tex_size",tex.get_size())
	card.pixel_size=source.scale.x/UNIT
	card.offset=source.position/source.scale+source.offset
	card.offset.y=-card.offset.y
	if not source.centered:
		card.offset.y-=tex.get_height()
	card.centered=source.centered
	card.flip_h=source.flip_h
	var mat:=card.material_override as ShaderMaterial
	mat.set_shader_parameter("tint",source.modulate)
	if source.material is ShaderMaterial:
		mat.set_shader_parameter("clothing_tint",source.material.get_shader_parameter("clothing_tint"))
	else:mat.set_shader_parameter("clothing_tint",Color.WHITE)

func _shadow(body:Node2D)->void:
	var shadow:=MeshInstance3D.new()
	shadow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
	_update_local_lights(delta)
	var interaction:=game.current_interaction()
	for actor in actors:
		var nearby:bool=actor.body.position.distance_squared_to(game.player.position)<1600.0*1600.0 and actor.body.visible
		if not nearby:
			if actor.has("card"):actor.card.visible=false
			elif actor.has("label"):actor.label.visible=false
			else:actor.shadow.visible=false
			continue
		if actor.has("label"):
			actor.label.text=actor.body.definition.name+("\n"+actor.body.emote() if actor.body.position.distance_to(game.player.position)<220 else "")
			actor.label.position=_point(actor.body.position)+Vector3(0,_body_height(actor.body)+1.5,0)
			actor.label.visible=actor.body.visible and interaction.get("kind")=="npc" and interaction.get("id")==actor.body.definition.id
		elif actor.has("shadow"):
			actor.shadow.position=_point(actor.body.position)+Vector3(0,_body_height(actor.body)+0.005,0)
			actor.shadow.visible=actor.body.visible and not (actor.body==game.player and game.player.swimming)
		else:
			_sync(actor.card,actor.body.sprite)
			actor.card.position=_point(actor.body.position)+Vector3(0,_body_height(actor.body),0)
			actor.card.visible=actor.body.visible
			if actor.body==game.player:
				actor.card.material_override.set_shader_parameter("swim_amount",1.0 if game.player.swimming else 0.0)
	mother_card.visible=MapDocument.base_enabled()
	_sync(mother_card,game.world.mother_sprite)
	mother_card.material_override.set_shader_parameter("vitality",game.world.mother_material.get_shader_parameter("vitality"))
	var hero:=Vector2(game.player.position.x,game.player.position.y)/UNIT
	for material in foliage_materials:
		material.set_shader_parameter("hero_position",hero)
	swim_ripple.visible=game.player.swimming
	swim_ripple.position=_point(game.player.position)+Vector3(0,0.015,-0.25)
	swim_ripple.scale=Vector3.ONE*(1.0+sin(game.player.swim_phase)*0.12)
	for item in pickups:
		item.node.visible=not game.collected.has(item.id)
		item.node.position.y=0.25+sin(Time.get_ticks_msec()*0.002+item.phase)*0.07
	if game.world.daylight.color!=last_daylight:
		_update_light()

	_follow(false,delta)

func _body_height(body:Node2D)->float:
	if body==game.player:
		return (-0.28+sin(game.player.swim_phase)*0.015) if game.player.swimming else game.player.surface_height()/UNIT
	return WorldData.bridge_height(body.position)/UNIT

func _update_light()->void:
	last_daylight=game.world.daylight.color
	light_timer=0
	_update_local_lights(0)
	sunlight.light_color=last_daylight
	atmosphere.environment.ambient_light_color=last_daylight
	var hour:=game.world.clock.minute/60.0
	var daylight:=smoothstep(5.0,8.0,hour)*(1.0-smoothstep(17.0,21.0,hour))
	sunlight.light_energy=lerpf(0.08,0.72,daylight)
	sunlight.rotation_degrees=Vector3(-25-sin(clampf((hour-6)/12,0,1)*PI)*40,-70+clampf((hour-6)/12,0,1)*115,0)
	atmosphere.environment.ambient_light_energy=lerpf(0.42,0.48,daylight)
	atmosphere.environment.fog_light_color=Color("24364d").lerp(Color("93a6ac"),daylight)
	atmosphere.environment.fog_density=lerpf(0.50,0.42,daylight)
	var color:=Vector3(last_daylight.r,last_daylight.g,last_daylight.b)
	for material in foliage_materials+facade_materials:
		material.set_shader_parameter("day_color",color)
	river_material.set_shader_parameter("day_color",color)
	if BuildingVisual.shared_material!=null:BuildingVisual.shared_material.set_shader_parameter("day_color",color)
	for actor in actors:
		if actor.has("card"):
			actor.card.material_override.set_shader_parameter("day_color",color)

func _follow(snap:bool,delta:float=0.016)->void:
	var target:=_point(game.player.position)
	target.y=game.player.surface_height()/UNIT
	var desired:=target+Vector3(0,12,14)
	if resource_fx!=null and resource_fx.shake>0:
		var phase:=Time.get_ticks_msec()*0.08
		desired+=Vector3(sin(phase),cos(phase*1.3),0)*resource_fx.shake
	camera.position=desired if snap else camera.position.lerp(desired,1.0-exp(-9.0*delta))
	camera.look_at(target+Vector3(0,0.3,0))

func snap_camera()->void:
	_follow(true)

func screen_position(point:Vector2)->Vector2:
	return camera.unproject_position(_point(point)+Vector3(0,0.7+_body_height(game.player),0))

func _bake(texture:Texture2D)->Texture2D:
	# Sprite3D needs a real texture: retain each atlas frame's padded pivot
	# instead of sampling neighboring poses from the source sheet.
	if not texture is AtlasTexture: return texture
	var key:="%s:%s:%s"%[texture.atlas.get_instance_id(),texture.region,texture.margin]
	if not baked.has(key):
		var image:=Image.create(int(texture.get_width()),int(texture.get_height()),false,Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		var source_image:Image=texture.atlas.get_image()
		source_image.convert(Image.FORMAT_RGBA8)
		image.blit_rect(source_image,Rect2i(texture.region),Vector2i(texture.margin.position))
		baked[key]=ImageTexture.create_from_image(image)
	return baked[key]

func _landmarks()->void:
	swim_ripple=MeshInstance3D.new()
	swim_ripple.name="SwimmingRipple"
	var ring:=TorusMesh.new()
	ring.inner_radius=0.19
	ring.outer_radius=0.23
	ring.rings=16
	ring.ring_segments=4
	swim_ripple.mesh=ring
	swim_ripple.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var foam:=StandardMaterial3D.new()
	foam.albedo_color=Color("b6dde0")
	foam.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	swim_ripple.material_override=foam
	add_child(swim_ripple)
	for data in WorldData.SEEDS:
		if not MapDocument.base_enabled():continue
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
	if not MapDocument.base_enabled():return
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
	mother.font=load(PixelArt.FONT)
	mother.text="ÁRVORE ANCESTRAL"
	mother.position=_point(WorldData.MOTHER)+Vector3(0,3.5,0)
	mother.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	mother.no_depth_test=true
	mother.font_size=40
	mother.pixel_size=0.008
	add_child(mother)

func world_position(screen:Vector2)->Vector2:
	var origin:=camera.project_ray_origin(screen)
	var direction:=camera.project_ray_normal(screen)
	var point:=origin+direction*(-origin.y/direction.y)
	return Vector2(point.x,point.z)*UNIT

func preview_house(point:Vector2,valid:bool)->void:
	if build_ghost==null:
		build_ghost=MeshInstance3D.new()
		var mesh:=BoxMesh.new()
		mesh.size=Vector3(3,0.07,2)
		build_ghost.mesh=mesh
		var material:=StandardMaterial3D.new()
		material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		build_ghost.material_override=material
		build_ghost.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(build_ghost)
	build_ghost.visible=true
	build_ghost.position=_point(point)+Vector3(0,0.045,-1)
	build_ghost.material_override.albedo_color=Color(0.35,0.8,0.45,0.5) if valid else Color(0.9,0.3,0.22,0.5)

func cancel_preview()->void:
	if build_ghost!=null:build_ghost.visible=false

func _settlement_labels()->void:
	for town in KingdomData.towns():
		for kind in ["shop","inn"]:
			if not KingdomData.service_exists(town,kind):continue
			var label:=Label3D.new()
			label.font=load(PixelArt.FONT)
			label.text="FERRARIA" if kind=="shop" else "ESTALAGEM"
			label.position=_point(KingdomData.point(town.id+"_"+kind))+Vector3(0,1.6,0)
			label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
			label.font_size=24
			label.pixel_size=0.006
			add_child(label)


func _color_grade()->void:
	grade=CanvasLayer.new()
	grade.layer=2
	add_child(grade)
	grade_rect=ColorRect.new()
	grade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grade_rect.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var material:=ShaderMaterial.new()
	material.shader=load("res://game/shaders/grade.gdshader")
	grade_rect.material=material
	grade.add_child(grade_rect)

func set_shaders(enabled:bool)->void:
	shaders_enabled=enabled
	if grade_rect!=null:grade_rect.visible=enabled and not game.light_graphics
	if river_material!=null:river_material.set_shader_parameter("effects",1.0 if enabled else 0.0)
	if BuildingVisual.shared_material!=null:BuildingVisual.shared_material.set_shader_parameter("effects",1.0 if enabled else 0.0)
	if atmosphere!=null:atmosphere.environment.fog_enabled=enabled
	if sunlight!=null:sunlight.shadow_enabled=enabled and not game.light_graphics

func _local_lights()->void:
	lantern=OmniLight3D.new();lantern.name="PlayerLantern";lantern.light_color=Color("ffd397");lantern.omni_range=4.5;lantern.light_energy=2.2;lantern.shadow_enabled=false;add_child(lantern)
	held_tool=Sprite3D.new();held_tool.pixel_size=0.022;held_tool.billboard=BaseMaterial3D.BILLBOARD_ENABLED;held_tool.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;add_child(held_tool)
	for i in 4:
		var light:=OmniLight3D.new();light.light_color=Color("ffbf7f");light.omni_range=4.2;light.light_energy=1.7;light.shadow_enabled=false;add_child(light);street_lamps.append(light)
		var post:=Sprite3D.new();post.texture=PixelArt.icon("lantern");post.pixel_size=0.018;post.billboard=BaseMaterial3D.BILLBOARD_ENABLED;post.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;add_child(post);lamp_posts.append(post)

func _update_local_lights(delta:float)->void:
	lantern.visible=game.lantern_enabled
	lantern.position=_point(game.player.position)+Vector3(0,0.9+_body_height(game.player),0.1)
	var item:String=RPGHotbar.ITEMS[game.equipped_slot]
	held_tool.visible=(game.equipped_slot<4 and game.rpg.tools.has(item) or game.equipped_slot==7 and game.lantern_enabled) and not game.player.swimming
	held_tool.texture=PixelArt.icon(item)
	held_tool.position=_point(game.player.position)+Vector3(0.27,0.5+_body_height(game.player),0.05)
	held_tool.offset=Vector2(sin(game.action_delay*12)*5,-cos(game.action_delay*12)*3) if game.action_delay>0 else Vector2.ZERO
	pixel_light_timer-=delta
	if pixel_light_timer<=0:
		pixel_light_timer=0.05
		var materials:Array=foliage_materials.duplicate()
		if BuildingVisual.shared_material!=null:materials.append(BuildingVisual.shared_material)
		for actor in actors:
			if actor.has("card") and actor.body.position.distance_squared_to(game.player.position)<1600*1600:materials.append(actor.card.material_override)
		var positions:=PackedVector3Array()
		var lit:=false
		for light in street_lamps:
			positions.append(light.position if light.visible else Vector3(-10000,-10000,-10000))
			lit=lit or light.visible
		for material in materials:
			material.set_shader_parameter("pixel_lantern",lantern.position)
			material.set_shader_parameter("pixel_lantern_strength",1.1 if game.lantern_enabled else 0.0)
			material.set_shader_parameter("pixel_streets",positions)
			material.set_shader_parameter("pixel_street_strength",0.9 if lit else 0.0)
	light_timer-=delta
	if light_timer>0:return
	light_timer=0.5
	var sites:Array[Vector2]=[]
	for building in KingdomData.buildings():
		if not building.kind in ["tavern","forge","castle","tower"]:continue
		var rect:=KingdomData.building_rect(building)
		var at:=Vector2(rect.position.x+24,rect.end.y+16)
		if at.distance_squared_to(game.player.position)<1300*1300:sites.append(at)
	sites.sort_custom(func(a:Vector2,b:Vector2):return a.distance_squared_to(game.player.position)<b.distance_squared_to(game.player.position))
	var night:bool=game.world.clock.minute<7*60 or game.world.clock.minute>17.5*60
	for i in 4:
		var present:=i<sites.size()
		street_lamps[i].visible=present and night
		lamp_posts[i].visible=present
		if present:
			street_lamps[i].position=_point(sites[i])+Vector3(0,1.1,0)
			lamp_posts[i].position=_point(sites[i])+Vector3(0,0.9,0)

func _exit_tree()->void:
	get_viewport().scaling_3d_scale=1.0
