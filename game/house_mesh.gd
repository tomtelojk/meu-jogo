class_name HouseMesh
extends RefCounted

var writer: BuildingVisual
var plan: Dictionary
var kit: HouseData
var frame := Transform3D.IDENTITY
var posts: Dictionary = {}

static func build(model: BuildingVisual, data: Dictionary, stage: int = 3) -> void:
	var builder := HouseMesh.new()
	builder.writer = model; builder.plan = HouseKit.generate(data); builder.kit = builder.plan.kit
	builder.bake(data,stage)

func box(at: Vector3, size: Vector3, color: Color, tag: float = 1) -> void:
	var mesh := BoxMesh.new(); mesh.size = size
	writer._append(mesh, frame * Transform3D(Basis.IDENTITY, at), color, tag)

func post(at: Vector3, height: float) -> void:
	var key := str(Vector3i((at*1000.0).round()))
	if posts.has(key): return
	posts[key] = true
	var saved := frame; frame = Transform3D.IDENTITY
	box(at+Vector3(0,height/2,0), Vector3(0.12,height,0.12), plan.wood)
	frame = saved

func bake(data: Dictionary, stage: int = 3) -> void:
	writer.name = String(data.get("id", "House"))
	writer.building_kind = data.kind
	writer.style = posmod(int(data.get("style", plan.seed%6)), 6)
	writer.house_plan = plan
	writer.position = WorldGrid.point3(plan.footprint.position)
	for pair in [["grid_pivot","ground_corner"],["style",writer.style],["house_style",kit.id],["kind",data.kind],["footprint",plan.footprint],["height",plan.height]]: writer.set_meta(pair[0],pair[1])
	writer.surface = SurfaceTool.new(); writer.surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Each kit module uses the same local metre coordinates and corner pivot.
	if stage<=1:
		for x in [0.06,plan.size.x-0.06]:
			for z in [0.06,plan.size.y-0.06]:box(Vector3(x,0.32 if stage==0 else 0.9,z),Vector3(0.12,0.64 if stage==0 else 1.8,0.12),plan.wood)
	for piece in plan.pieces:
		if stage==0:continue
		if stage==1 and piece.kind!="foundation":continue
		if stage==2 and piece.kind in ["roof","chimney","porch"]:continue
		frame = Transform3D.IDENTITY
		match piece.kind:
			"foundation": box(piece.at, piece.size, Color("77796a"), 2)
			"wall", "window", "door": facade(piece)
			"roof":
				writer._roof(piece.at, piece.size, kit.roof_height, plan.roof, kit.hip_roof)
				box(piece.at-Vector3(0,0.025,0),Vector3(piece.size.x,0.10,piece.size.y),plan.wood)
				# Fascia closes the roof edge; the overhang casts a real shadow.
				for side in [-1,1]: box(piece.at+Vector3(side*piece.size.x/2,-0.01,0),Vector3(0.07,0.14,piece.size.y),plan.wood)
			"porch": porch(piece)
			"steps":
				box(piece.at+Vector3(0,0.025,0.22),Vector3(0.90,0.05,0.44),Color("898574"),2)
				box(piece.at+Vector3(0,0.075,0.10),Vector3(0.90,0.05,0.24),Color("96917e"),2)
			"chimney":
				box(piece.at+Vector3(0,0.40,0),Vector3(0.36,0.80,0.36),Color("86776d"),2)
				box(piece.at+Vector3(0,0.81,0),Vector3(0.46,0.08,0.46),Color("aca08d"),2)
				box(piece.at+Vector3(0,0.855,0),Vector3(0.24,0.01,0.24),Color("292b2a"),0)
	# Transform the finished kit once, so rotations never move its ground pivot.
	writer.surface.index()
	var raw := writer.surface.commit()
	var arrays := raw.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in vertices.size():
		vertices[i] = plan.transform * vertices[i]
		normals[i] = plan.transform.basis * normals[i]
	arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_NORMAL]=normals
	var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	writer.visual_mesh = MeshInstance3D.new(); writer.visual_mesh.name="ModularHouse"
	writer.visual_mesh.mesh=mesh; writer.visual_mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if BuildingVisual.shared_material==null:
		BuildingVisual.shared_material=ShaderMaterial.new(); BuildingVisual.shared_material.shader=load("res://game/shaders/architecture.gdshader")
	writer.visual_mesh.material_override=BuildingVisual.shared_material
	writer.add_child(writer.visual_mesh); writer.surface=null

func facade(piece: Dictionary) -> void:
	frame=Transform3D(Basis(Vector3.UP,piece.turn*PI/2),piece.at)
	var height := kit.wall_height
	var span: float=piece.span
	box(Vector3(0,height/2,-0.075),Vector3(maxf(0.05,span-0.12),height,0.15),plan.wall,1 if kit.id=="poor" else (2 if kit.id=="rich" else 0))
	box(Vector3(0,height-0.05,0),Vector3(span,0.10,0.13),plan.wood)
	post(frame*Vector3(-span/2,0,0),height)
	post(frame*Vector3(span/2,0,0),height)
	if piece.kind=="door":
		box(Vector3(0,0.64,0.04),Vector3(0.62,1.28,0.12),plan.wood.darkened(0.12))
		for side in [-1,1]:box(Vector3(side*0.34,0.70,0.05),Vector3(0.075,1.40,0.16),plan.wood.lightened(0.12))
		box(Vector3(0,1.38,0.05),Vector3(0.75,0.10,0.16),plan.wood)
		box(Vector3(0.20,0.66,0.12),Vector3(0.045,0.06,0.05),Color("e2bf72"),0)
	elif piece.kind=="window":
		var y:=height*0.58
		box(Vector3(0,y,0.04),Vector3(0.60,0.70,0.10),plan.wood)
		box(Vector3(0,y,0.10),Vector3(0.46,0.55,0.035),Color("efc58b"),4)
		box(Vector3(0,y,0.13),Vector3(0.045,0.58,0.025),plan.wood)
		box(Vector3(0,y,0.13),Vector3(0.48,0.04,0.025),plan.wood)
		box(Vector3(0,y-0.38,0.10),Vector3(0.72,0.07,0.25),Color("b2a28a"),2)
		if kit.id in ["poor","common"]:
			for side in [-1,1]:box(Vector3(side*0.38,y,0.065),Vector3(0.13,0.64,0.08),kit.accent_color)
		if kit.id=="rich":box(Vector3(0,y+0.41,0.07),Vector3(0.74,0.12,0.18),Color("d2cbb6"),2)

func porch(piece: Dictionary) -> void:
	var at: Vector3=piece.at
	var w: float=piece.width
	box(at+Vector3(0,0.17,0),Vector3(w,0.10,1),plan.wood.lightened(0.15))
	for side in [-1,1]:box(at+Vector3(side*(w/2-0.15),piece.height/2,0.30),Vector3(0.10,piece.height,0.10),plan.wood)
	box(at+Vector3(0,piece.height,0),Vector3(w+0.16,0.10,1.20),plan.roof)
	if kit.id=="rich":
		box(at+Vector3(0,piece.height+0.55,0.44),Vector3(w,0.08,0.08),kit.accent_color)
		for i in ceili(w*3):box(at+Vector3(-w/2+(i+0.5)/3,piece.height+0.30,0.44),Vector3(0.045,0.5,0.045),kit.accent_color)
	if kit.id=="shop":
		for i in ceili(w*2):box(at+Vector3(-w/2+(i+0.5)*0.5,piece.height+0.06,0.02),Vector3(minf(0.5,w),0.03,1.2),kit.accent_color if i%2==0 else Color("ddd1ac"),0)
		box(at+Vector3(-w*0.32,0.45,0.1),Vector3(0.65,0.55,0.50),plan.wood)
		for i in 3:box(at+Vector3(-w*0.32+(i-1)*0.16,0.77,0.1),Vector3(0.12,0.14,0.18),[Color("a97a42"),Color("78915a"),Color("ae624b")][i],0)
	if kit.id=="tavern":
		box(at+Vector3(-w*0.34,0.40,0.05),Vector3(0.75,0.09,0.38),plan.wood)
		box(at+Vector3(w*0.32,1.30,0.54),Vector3(0.52,0.46,0.08),kit.accent_color,0)
		box(at+Vector3(w*0.32,1.30,0.60),Vector3(0.18,0.25,0.025),Color("f1d9a2"),0)
		box(at+Vector3(w*0.32+0.13,1.32,0.60),Vector3(0.06,0.15,0.03),Color("f1d9a2"),0)
