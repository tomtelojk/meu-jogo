class_name HD2DAtmosphere
extends Node3D

var hybrid:HybridWorld
var state:Dictionary={}
var rain:CPUParticles3D
var splash:CPUParticles3D
var rain_material:ShaderMaterial
var rain_amount:=0.0
var cloud:=0.0
var mist:=0.0
var wind:=0.55
var timer:=0.0
var shelter_timer:=0.0
func setup(renderer:HybridWorld)->void:
	hybrid=renderer;name="Weather"
	state=WeatherState.sample(renderer.game.world.clock.day,renderer.game.world.clock.minute,renderer.game.weather_mode)
	rain_amount=state.rain;cloud=state.cloud;mist=state.mist;wind=state.wind
	rain=CPUParticles3D.new();rain.name="Rain";rain.layers=16;rain.amount=160;rain.lifetime=1.0;rain.emitting=false;rain.local_coords=false
	rain.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX;rain.emission_box_extents=Vector3(12,0.1,10);rain.direction=Vector3(-0.12,-1,0.02);rain.spread=4;rain.initial_velocity_min=8;rain.initial_velocity_max=11;rain.gravity=Vector3(0,-2,0)
	var streak:=BoxMesh.new();streak.size=Vector3(0.012,0.24,0.012);rain.mesh=streak
	rain_material=ShaderMaterial.new();rain_material.shader=load("res://game/shaders/rain.gdshader");rain.material_override=rain_material;rain.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(rain)
	splash=CPUParticles3D.new();splash.name="RainSplashes";splash.layers=16;splash.amount=72;splash.lifetime=0.22;splash.emitting=false;splash.local_coords=false;splash.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX;splash.emission_box_extents=Vector3(10,0,8);splash.direction=Vector3.UP;splash.initial_velocity_min=0.1;splash.initial_velocity_max=0.3;splash.gravity=Vector3(0,-1,0)
	var drop:=BoxMesh.new();drop.size=Vector3(0.045,0.012,0.045);splash.mesh=drop;splash.material_override=rain_material;splash.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(splash)
func update(delta:float)->void:
	var game:ForestGame=hybrid.game
	state=WeatherState.sample(game.world.clock.day,game.world.clock.minute,game.weather_mode)
	var blend:=1.0-exp(-delta*0.7)
	rain_amount=lerpf(rain_amount,state.rain,blend);cloud=lerpf(cloud,state.cloud,blend);mist=lerpf(mist,state.mist,blend);wind=lerpf(wind,state.wind,blend)
	var enabled:bool=hybrid.shaders_enabled and game.mode=="playing"
	rain.visible=enabled;rain.emitting=enabled and rain_amount>0.05;splash.visible=enabled;splash.emitting=rain.emitting
	rain_material.set_shader_parameter("rain_strength",rain_amount)
	rain.position=hybrid._point(game.player.position)+Vector3(0,6,0);splash.position=hybrid._point(game.player.position)+Vector3(0,0.035,0)
	timer+=delta;shelter_timer+=delta
	if timer>=0.2:
		timer=0;hybrid._update_light()
		for material in hybrid.foliage_materials:material.set_shader_parameter("wind_strength",wind if hybrid.shaders_enabled else 0.0)
		hybrid.grass.material.set_shader_parameter("wind_strength",wind if hybrid.shaders_enabled else 0.0)
		hybrid.grass.material.set_shader_parameter("wetness",rain_amount)
		hybrid.river_material.set_shader_parameter("rain",rain_amount if hybrid.shaders_enabled else 0.0)
	if shelter_timer>=0.5:
		shelter_timer=0;_shelters()
func _shelters()->void:
	var rows:Array=[]
	for building in hybrid.architecture.get_children():
		if building.global_position.distance_squared_to(hybrid._point(hybrid.game.player.position))<20*20:rows.append(building)
	for parent in hybrid.landscape.house_models.values():
		for child in parent.get_children():
			if child is BuildingVisual and child.global_position.distance_squared_to(hybrid._point(hybrid.game.player.position))<20*20:rows.append(child)
	for piece in hybrid.landscape.piece_models.values():
		if piece.kind=="roof" and piece.global_position.distance_squared_to(hybrid._point(hybrid.game.player.position))<20*20:rows.append(piece)
	rows.sort_custom(func(a:Node3D,b:Node3D):return a.global_position.distance_squared_to(hybrid.camera.position)<b.global_position.distance_squared_to(hybrid.camera.position))
	var rectangles:=PackedVector4Array();var heights:=PackedFloat32Array()
	for i in 16:
		if i<rows.size():
			var rect:Rect2=rows[i].get_meta("footprint");rect=rect.grow(16)
			rectangles.append(Vector4(rect.position.x/64,rect.position.y/64,rect.size.x/64,rect.size.y/64));heights.append(rows[i].get_meta("height"))
		else:rectangles.append(Vector4.ZERO);heights.append(-100.0)
	rain_material.set_shader_parameter("shelters",rectangles);rain_material.set_shader_parameter("shelter_heights",heights)
