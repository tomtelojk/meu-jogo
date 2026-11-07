class_name ConstructionVisual
extends BuildingVisual

var kind:=""

func setup_piece(entry:Dictionary)->void:
	kind=entry.kind
	var definition:=ConstructionCatalog.piece(kind)
	var rect:=ConstructionCatalog.footprint(entry)
	name="Built_"+kind;position=Vector3(rect.get_center().x/64,0,rect.get_center().y/64);rotation.y=-int(entry.get("turn",0))*PI/2
	set_meta("footprint",rect);set_meta("height",float(definition.height));set_meta("kind",kind)
	surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wood:=Color("866044");var dark:=Color("4f382c");var stone:=Color("858782")
	match kind:
		"wood_floor":
			for i in 5:_box(Vector3((i-2)*0.2,0.035,0),Vector3(0.194,0.07,1),wood.lightened(i%2*0.07),1)
		"stone_floor":_box(Vector3(0,0.03,0),Vector3(1,0.06,1),stone,2)
		"wood_wall","stone_wall":
			var stonework:bool=kind=="stone_wall";var h:float=definition.height
			_box(Vector3(0,h/2,0),Vector3(1,h,0.25 if stonework else 0.1875),stone if stonework else Color("c5af8a"),2 if stonework else 0)
			if not stonework:
				for side in [-1,1]:_box(Vector3(side*0.45,h/2,0),Vector3(0.1,h+0.04,0.22),dark,1)
				for y in [0.12,1.0,1.6]:_box(Vector3(0,y,0),Vector3(1,0.09,0.22),wood,1)
		"door":
			for side in [-1,1]:_box(Vector3(side*0.45,0.84,0),Vector3(0.1,1.68,0.19),dark,1)
			_box(Vector3(0,1.65,0),Vector3(1,0.12,0.22),dark,1)
			var hinge:=Transform3D(Basis(Vector3.UP,-PI/2 if entry.get("open",false) else 0),Vector3(-0.38,0,0))
			var panel:=BoxMesh.new();panel.size=Vector3(0.76,1.5,0.09)
			_append(panel,hinge*Transform3D(Basis.IDENTITY,Vector3(0.38,0.77,0)),wood,1)
			var knob:=BoxMesh.new();knob.size=Vector3(0.06,0.06,0.08)
			_append(knob,hinge*Transform3D(Basis.IDENTITY,Vector3(0.65,0.8,0.08)),Color("d4b365"),0)
		"roof":
			_box(Vector3(0,2.0,0),Vector3(1.04,0.1,1.04),Color("8b6352"),3)
			for side in [-1,1]:_box(Vector3(side*0.47,1.91,0),Vector3(0.07,0.12,1.04),dark,1)
		"bed":
			_box(Vector3(0,0.27,0),Vector3(0.72,0.18,1.64),wood,1)
			_box(Vector3(0,0.41,0.04),Vector3(0.65,0.19,1.48),Color("c4ba96"),0)
			_box(Vector3(0,0.53,-0.48),Vector3(0.50,0.08,0.33),Color("e7dac2"),0)
			_box(Vector3(0,0.52,0.26),Vector3(0.67,0.08,0.94),Color("697f87"),0)
			_box(Vector3(0,0.40,-0.81),Vector3(0.78,0.5,0.09),dark,1)
			for x in [-0.29,0.29]:
				for z in [-0.68,0.68]:_box(Vector3(x,0.16,z),Vector3(0.1,0.32,0.1),dark,1)
		"table","workbench":
			_box(Vector3(0,0.77,0),Vector3(0.82,0.12,0.60 if kind=="workbench" else 0.72),wood,1)
			for x in [-0.31,0.31]:
				for z in [-0.22,0.22]:_box(Vector3(x,0.37,z),Vector3(0.11,0.74,0.11),dark,1)
			if kind=="workbench":
				_box(Vector3(0,0.31,0),Vector3(0.72,0.06,0.44),wood.darkened(0.12),1)
				_box(Vector3(-0.15,0.87,0.03),Vector3(0.35,0.10,0.18),Color("c6b18c"),1)
				_box(Vector3(0.22,0.87,-0.03),Vector3(0.08,0.15,0.23),Color("666d71"),2)
		"bench":
			_box(Vector3(0,0.41,0),Vector3(0.85,0.09,0.36),wood,1)
			for x in [-0.29,0.29]:_box(Vector3(x,0.2,0),Vector3(0.13,0.4,0.31),dark,1)
		"forge":
			_box(Vector3(-0.43,0.42,0),Vector3(0.9,0.84,0.72),stone,2)
			_box(Vector3(-0.43,0.72,-0.24),Vector3(0.92,1.45,0.22),stone.darkened(0.12),2)
			_box(Vector3(-0.43,0.49,0.37),Vector3(0.55,0.43,0.025),dark,0)
			_box(Vector3(-0.43,0.39,0.39),Vector3(0.42,0.16,0.03),Color("ed9f4d"),4)
			_box(Vector3(0.44,0.34,0),Vector3(0.62,0.67,0.58),wood.darkened(0.24),1)
			_box(Vector3(0.44,0.76,0),Vector3(0.69,0.2,0.34),Color("555d65"),2)
			_box(Vector3(0.67,0.73,0),Vector3(0.37,0.12,0.23),Color("636b72"),2)
		"torch":
			_box(Vector3(0,0.52,0),Vector3(0.12,1.04,0.12),dark,1)
			_box(Vector3(0,1.0,0),Vector3(0.25,0.15,0.25),stone.darkened(0.3),2)
			_box(Vector3(0,1.13,0),Vector3(0.14,0.23,0.14),Color("efbe72"),4)
	visual_mesh=MeshInstance3D.new();visual_mesh.mesh=surface.commit();surface=null
	if shared_material==null:shared_material=ShaderMaterial.new();shared_material.shader=load("res://game/shaders/architecture.gdshader")
	visual_mesh.material_override=shared_material;visual_mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON;add_child(visual_mesh)
