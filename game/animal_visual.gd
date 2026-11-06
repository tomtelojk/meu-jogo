class_name AnimalVisual
extends MultiMeshInstance3D

var animal:WorldAnimal
var parts:Array[Dictionary]=[]
var label:Label3D

func setup(source:WorldAnimal)->void:
	animal=source
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var body_color:=Color("ad8152")
	var body_size:=Vector3(0.65,0.4,0.3)
	var leg_height:=0.25
	match animal.species:
		"cow":body_color=Color("e0d9bb");body_size=Vector3(0.8,0.45,0.4);leg_height=0.35
		"chicken":body_color=Color("f0dba9");body_size=Vector3(0.28,0.23,0.2);leg_height=0.12
		"rabbit":body_color=Color("b8a791");body_size=Vector3(0.3,0.23,0.2);leg_height=0.1
		"boar":body_color=Color("685142");body_size=Vector3(0.65,0.35,0.35)
		"deer":body_color=Color("b48c5f");body_size=Vector3(0.6,0.33,0.28);leg_height=0.38
	_part(Vector3(0,leg_height+body_size.y/2,0),body_size,body_color)
	_part(Vector3(body_size.x*0.48,leg_height+body_size.y*0.8,0),Vector3(body_size.x*0.35,body_size.y*0.75,body_size.z*0.8),body_color.darkened(0.08))
	for side in [-1,1]:
		_part(Vector3(body_size.x*0.62,leg_height+body_size.y*0.9,side*body_size.z*0.37),Vector3(0.035,0.04,0.025),Color("171f1b"))
	for x in [-1,1]:
		for z in [-1,1]:_part(Vector3(x*body_size.x*0.3,leg_height/2,z*body_size.z*0.32),Vector3(0.07,leg_height,0.07),body_color.darkened(0.35),x*z)
	if animal.species=="cow":
		_part(Vector3(-0.15,leg_height+body_size.y+0.005,0),Vector3(0.25,0.02,0.32),Color("514b43"))
		for side in [-1,1]:_part(Vector3(0.42,leg_height+0.55,side*0.12),Vector3(0.08,0.16,0.05),Color("d6c5a0"))
	elif animal.species=="chicken":
		_part(Vector3(0.19,0.38,0),Vector3(0.09,0.1,0.04),Color("b44b35"))
		_part(Vector3(0.22,0.28,0),Vector3(0.1,0.06,0.08),Color("e4ad4c"))
	elif animal.species=="rabbit":
		for side in [-1,1]:_part(Vector3(0.12,0.42,side*0.06),Vector3(0.07,0.22,0.05),body_color.lightened(0.1))
	elif animal.species=="deer":
		for side in [-1,1]:_part(Vector3(0.29,0.85,side*0.09),Vector3(0.04,0.28,0.04),Color("65533d"))
	elif animal.species=="boar":
		for side in [-1,1]:_part(Vector3(0.44,0.44,side*0.1),Vector3(0.12,0.07,0.045),Color("e3d8bb"))
	multimesh=MultiMesh.new()
	multimesh.transform_format=MultiMesh.TRANSFORM_3D
	multimesh.use_colors=true
	multimesh.mesh=BoxMesh.new()
	multimesh.instance_count=parts.size()
	var material:=StandardMaterial3D.new()
	material.vertex_color_use_as_albedo=true
	material.roughness=1.0
	material_override=material
	label=Label3D.new()
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size=25
	label.pixel_size=0.006
	label.position=Vector3(0,1.1,0)
	add_child(label)
	for i in parts.size():
		multimesh.set_instance_transform(i,Transform3D(Basis.from_scale(parts[i].size),parts[i].at))
		multimesh.set_instance_color(i,parts[i].color)

func _part(at:Vector3,size:Vector3,color:Color,leg:int=0)->void:
	parts.append({"at":at,"size":size,"color":color,"leg":leg})

func _process(_delta:float)->void:
	if not is_instance_valid(animal):queue_free();return
	visible=animal.alive
	if not visible:return
	label.visible=(animal.definition.hostile or animal.health<animal.definition.health) and animal.position.distance_to(animal.game.player.position)<180
	label.text="%s · %d"%[animal.definition.name,animal.health]
	position=Vector3(animal.position.x/64,0,animal.position.y/64)
	rotation.y=-atan2(animal.facing.y,animal.facing.x)
	for i in parts.size():
		var part:Dictionary=parts[i]
		if part.leg==0:continue
		var at:Vector3=part.at
		at.x+=sin(animal.gait)*0.055*part.leg if animal.velocity.length_squared()>1 else 0.0
		multimesh.set_instance_transform(i,Transform3D(Basis.from_scale(part.size),at))
