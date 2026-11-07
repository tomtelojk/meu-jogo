class_name PlanarReflection
extends SubViewport

var hybrid:HybridWorld
var mirror:Camera3D
var elapsed:=0.0
var refreshes:=0
var active:=false
func setup(renderer:HybridWorld)->void:
	hybrid=renderer;name="WaterReflection";size=Vector2i(192,120);world_3d=renderer.get_viewport().world_3d
	world_2d=World2D.new();canvas_cull_mask=0
	gui_disable_input=true;render_target_update_mode=SubViewport.UPDATE_DISABLED
	mirror=Camera3D.new();mirror.projection=Camera3D.PROJECTION_ORTHOGONAL;mirror.cull_mask=1;mirror.far=45;add_child(mirror);mirror.current=true
	hybrid.river_material.set_shader_parameter("reflection_map",get_texture())
func update(delta:float)->void:
	elapsed+=delta
	if elapsed<(0.33 if hybrid.game.light_graphics else 0.17):return
	elapsed=0
	var at:Vector2=hybrid.game.player.position
	var water:=WorldData.in_river(at) or MapDocument.base_enabled() and absf(at.x-WorldData.river_x(at.y))<WorldData.river_width(at.y)+700
	if not water:
		for y in range(-6,7):
			for x in range(-6,7):
				if MapDocument.current.terrain.get(MapDocument.cell_key(MapDocument.cell_at(at)+Vector2i(x,y)))=="water":water=true;break
	active=water and hybrid.shaders_enabled and hybrid.game.mode=="playing"
	hybrid.river_material.set_shader_parameter("reflection_strength",0.24 if active else 0.0)
	if not active:return
	var width:=192 if hybrid.game.light_graphics else 256
	var viewport_size:=hybrid.get_viewport().get_visible_rect().size
	var expected:=Vector2i(width,maxi(64,roundi(width*viewport_size.y/maxf(1,viewport_size.x))))
	if size!=expected:size=expected
	mirror.size=hybrid.camera.size
	var p:=hybrid.camera.global_position
	mirror.global_position=Vector3(p.x,-p.y,p.z)
	var target:=hybrid._point(at)+Vector3(0,hybrid.game.player.surface_height()/64+0.3,0)
	target.y=-target.y
	mirror.look_at(target,Vector3.DOWN)
	var matrix:=mirror.get_camera_projection()*Projection(mirror.global_transform.affine_inverse())
	hybrid.river_material.set_shader_parameter("reflection_matrix",matrix)
	render_target_update_mode=SubViewport.UPDATE_ONCE;refreshes+=1
