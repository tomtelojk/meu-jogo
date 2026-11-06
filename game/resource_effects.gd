class_name ResourceEffects
extends Node3D

var hybrid:HybridWorld
var game:ForestGame
var fragments:Array[Dictionary]=[]
var falls:Array[Dictionary]=[]
var shakes:Dictionary={}
var batches:Dictionary={}
var shade:Dictionary={}
var shake:=0.0
func setup(renderer:HybridWorld)->void:
	hybrid=renderer;game=renderer.game
	for item in ["wood","stone","copper","iron","stump"]:
		var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D
		if item=="stump":
			var mesh:=CylinderMesh.new();mesh.top_radius=0.12;mesh.bottom_radius=0.17;mesh.height=0.18;mesh.radial_segments=8;multi.mesh=mesh
		else:
			var mesh:=BoxMesh.new();mesh.size=Vector3(0.20,0.10,0.10) if item=="wood" else Vector3.ONE*0.13;multi.mesh=mesh
		var node:=MultiMeshInstance3D.new();node.multimesh=multi;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.material_override=_material({"wood":"b7894d","stone":"aab2ad","copper":"c77d4e","iron":"bdcbd2","stump":"997544"}[item]);add_child(node);batches[item]=multi
func _material(color:String)->StandardMaterial3D:
	if not shade.has(color):
		var mat:=StandardMaterial3D.new();mat.albedo_color=Color(color);mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;shade[color]=mat
	return shade[color]
func hit(entry:Dictionary,damage:int,finished:bool)->void:
	shake=0.055 if not finished else 0.12
	var at:=hybrid._point(entry.resource.position)+Vector3(0,0.3,0)
	var label:=Label3D.new();label.text="-%d"%damage;label.font=load(PixelArt.FONT);label.font_size=32;label.pixel_size=0.008;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.no_depth_test=true;label.position=at+Vector3(0,0.5,0);add_child(label)
	fragments.append({"node":label,"velocity":Vector3(0,0.6,0),"time":0.0,"life":0.8,"label":true})
	var color:="ac804a" if entry.resource.kind=="wood" else ("cb8148" if entry.resource.get("type")=="copper_ore" else "a3aaa8")
	var dust:=CPUParticles3D.new();dust.amount=10;dust.lifetime=0.4;dust.one_shot=true;dust.explosiveness=1.0;dust.direction=Vector3.UP;dust.spread=65;dust.initial_velocity_min=0.2;dust.initial_velocity_max=0.7;dust.gravity=Vector3(0,-0.8,0)
	var dust_mesh:=BoxMesh.new();dust_mesh.size=Vector3.ONE*0.035;dust.mesh=dust_mesh;dust.material_override=_material("d6bf94" if entry.resource.kind=="wood" else "b8bdba");dust.position=at;add_child(dust);dust.emitting=true
	fragments.append({"node":dust,"time":0.0,"life":0.5,"emitter":true})
	for i in 7:
		var node:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=Vector3.ONE*0.045;node.mesh=mesh;node.material_override=_material(color);node.position=at;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node)
		var angle:=i*TAU/7;fragments.append({"node":node,"velocity":Vector3(cos(angle)*1.2,1.4+(i%3)*0.3,sin(angle)*1.2),"time":0.0,"life":0.65+(i%3)*0.08,"label":false})
	var id:String=entry.resource.id
	if entry.has("sprite") and finished:
		var pivot:=Node3D.new();pivot.position=hybrid._point(entry.resource.position);pivot.basis=hybrid.camera.global_basis;add_child(pivot)
		var card:=hybrid._card(entry.sprite);card.reparent(pivot,false);card.material_override.set_shader_parameter("face_camera",false)
		var daylight:Color=game.world.daylight.color;card.material_override.set_shader_parameter("day_color",Vector3(daylight.r,daylight.g,daylight.b))
		falls.append({"id":id,"node":pivot,"basis":pivot.basis,"time":0.0,"direction":-1 if game.player.position.x>entry.resource.position.x else 1})
	elif hybrid.landscape.resource_instances.has(id):
		var ref:Dictionary=hybrid.landscape.resource_instances[id]
		shakes[id]={"multi":ref.multi,"index":ref.index,"transform":ref.multi.get_instance_transform(ref.index),"time":0.0}
func _process(delta:float)->void:
	if game==null or game.mode!="playing":return
	shake=move_toward(shake,0,delta*0.35)
	for id in shakes.keys():
		var row:Dictionary=shakes[id];row.time+=delta
		if game.rpg.depleted.has(id):shakes.erase(id);continue
		var transform:Transform3D=row.transform
		transform.origin.x+=sin(row.time*55)*0.045*exp(-row.time*13)
		row.multi.set_instance_transform(row.index,transform)
		if row.time>0.3:row.multi.set_instance_transform(row.index,row.transform);shakes.erase(id)
	for row in fragments.duplicate():
		row.time+=delta
		if row.time>=row.life:row.node.queue_free();fragments.erase(row);continue
		if row.get("emitter",false):continue
		if not row.label:row.velocity.y-=4.8*delta;row.node.rotate_z(delta*6)
		row.node.position+=row.velocity*delta
		if row.label:row.node.modulate.a=1.0-row.time/row.life
	for row in falls.duplicate():
		row.time+=delta
		row.node.basis=row.basis.rotated(hybrid.camera.global_basis.z, pow(clampf(row.time/0.85,0,1),2.3)*PI*0.48*row.direction)
		if row.time>=0.85:row.node.queue_free();falls.erase(row)
	_draw_batches()
func _draw_batches()->void:
	var rows:Dictionary={"wood":[],"stone":[],"copper":[],"iron":[],"stump":[]}
	for drop in game.rpg.resources.drops.values():
		var at:=Vector2(drop.x,drop.y)
		if at.distance_squared_to(game.player.position)>1600*1600:continue
		rows[drop.item].append(Transform3D(Basis(Vector3.UP,drop.age*0.7),hybrid._point(at)+Vector3(0,0.08+drop.z/64,0)))
	for id in game.rpg.resources.states:
		var state:Dictionary=game.rpg.resources.states[id]
		if state.stage!="stump":continue
		var at:=Vector2(state.x,state.y)
		if at.distance_squared_to(game.player.position)>1600*1600:continue
		var falling:=false
		for fall in falls:
			if fall.id==id:falling=true;break
		if not falling:rows.stump.append(Transform3D(Basis.IDENTITY,hybrid._point(at)+Vector3(0,0.09,0)))
	for item in rows:
		var multi:MultiMesh=batches[item]
		if multi.instance_count<rows[item].size():multi.instance_count=rows[item].size()+16
		multi.visible_instance_count=rows[item].size()
		for i in rows[item].size():multi.set_instance_transform(i,rows[item][i])
