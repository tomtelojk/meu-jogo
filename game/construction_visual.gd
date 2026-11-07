class_name ConstructionVisual
extends BuildingVisual

var kind:=""

func setup_piece(entry:Dictionary,joints:Dictionary={})->void:
	kind=entry.kind
	var definition:=ConstructionCatalog.piece(kind)
	var rect:=ConstructionCatalog.footprint(entry)
	name="Built_"+kind;position=WorldGrid.point3(ConstructionCatalog.pivot(entry));rotation.y=-int(entry.get("turn",0))*PI/2
	set_meta("footprint",rect);set_meta("height",float(definition.height));set_meta("kind",kind)
	set_meta("grid_pivot","ground_corner");set_meta("grid_version",WorldGrid.VERSION)
	surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wood:=Color("866044");var dark:=Color("4f382c");var stone:=Color("858782")
	match kind:
		"wood_floor":
			for i in 5:_box(Vector3((i-2)*0.2*WorldGrid.CELL_SIZE,WorldGrid.FLOOR_HEIGHT/2,0),Vector3(0.2*WorldGrid.CELL_SIZE,WorldGrid.FLOOR_HEIGHT,WorldGrid.CELL_SIZE),wood.lightened(i%2*0.07),1)
		"stone_floor":_box(Vector3(0,WorldGrid.FLOOR_HEIGHT/2,0),Vector3(WorldGrid.CELL_SIZE,WorldGrid.FLOOR_HEIGHT,WorldGrid.CELL_SIZE),stone,2)
		"wood_wall","stone_wall":
			var parts:=ConstructionCatalog.wall_parts(entry,joints);var h:=WorldGrid.WALL_HEIGHT;var thickness:=WorldGrid.WALL_THICKNESS
			if kind=="stone_wall":_box(Vector3((parts.start+parts.end)/2,h/2,0),Vector3(parts.end-parts.start,h,thickness),stone,2)
			else:
				# The timber frame partitions the panel; no overlapping decoration
				# or posts extend into the next module's end cap.
				for side in [parts.start+0.04,parts.end-0.04]:_box(Vector3(side,h/2,0),Vector3(0.08,h,thickness),dark,1)
				var spans:=[Vector2(0,0.12),Vector2(0.12,1),Vector2(1,1.10),Vector2(1.10,1.88),Vector2(1.88,2)]
				for i in spans.size():_box(Vector3((parts.start+parts.end)/2,(spans[i].x+spans[i].y)/2,0),Vector3(parts.end-parts.start-0.16,spans[i].y-spans[i].x,thickness),wood if i%2==0 else Color("c5af8a"),1 if i%2==0 else 0)
			for point in parts.posts:_box(Vector3(point.x,h/2,point.y),Vector3(thickness,h,thickness),stone if kind=="stone_wall" else dark,2 if kind=="stone_wall" else 1)
		"door":
			var parts:=ConstructionCatalog.wall_parts(entry,joints);var thickness:=WorldGrid.WALL_THICKNESS
			for side in [parts.start+0.05,parts.end-0.05]:_box(Vector3(side,1,0),Vector3(0.1,2,thickness),dark,1)
			_box(Vector3((parts.start+parts.end)/2,1.9,0),Vector3(parts.end-parts.start-0.2,0.2,thickness),dark,1)
			for point in parts.posts:_box(Vector3(point.x,1,point.y),Vector3(thickness,2,thickness),dark,1)
			var width:float=parts.end-parts.start-0.22
			var hinge:=Transform3D(Basis(Vector3.UP,-PI/2 if entry.get("open",false) else 0),Vector3(parts.start+0.11,0,0))
			var panel:=BoxMesh.new();panel.size=Vector3(width,1.76,0.09)
			_append(panel,hinge*Transform3D(Basis.IDENTITY,Vector3(width/2,0.90,0)),wood,1)
			var knob:=BoxMesh.new();knob.size=Vector3(0.06,0.06,0.08)
			_append(knob,hinge*Transform3D(Basis.IDENTITY,Vector3(width-0.08,0.9,0.08)),Color("d4b365"),0)
		"roof":
			_box(Vector3(0,WorldGrid.ROOF_BOTTOM+WorldGrid.ROOF_THICKNESS/2,0),Vector3(WorldGrid.CELL_SIZE,WorldGrid.ROOF_THICKNESS,WorldGrid.CELL_SIZE),Color("8b6352"),3)
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
	if not ConstructionCatalog.is_edge(kind):
		var size:=Vector2(ConstructionCatalog.size_cells(kind))*WorldGrid.CELL_SIZE
		visual_mesh.position=Vector3(size.x/2,0,size.y/2)
		if definition.layer=="object":
			var bounds:=visual_mesh.mesh.get_aabb();var inner:=size-Vector2.ONE*WorldGrid.WALL_THICKNESS
			visual_mesh.scale=Vector3(minf(1,inner.x/bounds.size.x),1,minf(1,inner.y/bounds.size.z))
			visual_mesh.position=Vector3(size.x/2-bounds.get_center().x*visual_mesh.scale.x,-bounds.position.y,size.y/2-bounds.get_center().z*visual_mesh.scale.z)
	if shared_material==null:shared_material=ShaderMaterial.new();shared_material.shader=load("res://game/shaders/architecture.gdshader")
	visual_mesh.material_override=shared_material;visual_mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON;add_child(visual_mesh)
