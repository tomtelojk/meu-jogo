class_name BuildingVisual
extends Node3D

# One colored mesh per building. Windows, beams, steps and roofs do not each
# create a draw call, and the main walls exactly match the simulation footprint.
const PALETTES := [
	[Color("e3d3ad"),Color("a75d49"),Color("624938")],
	[Color("d6ba8c"),Color("5d7965"),Color("584534")],
	[Color("adb6bb"),Color("4e657c"),Color("515258")],
	[Color("e3c0a0"),Color("8c6548"),Color("71513e")],
	[Color("c8d2be"),Color("6e586e"),Color("4d584b")],
	[Color("cbb9a1"),Color("88654c"),Color("59483a")],
]
static var shared_material: ShaderMaterial
static var shared_fade_material:ShaderMaterial
var visual_mesh:MeshInstance3D
var faded:=false
var surface: SurfaceTool
var building_kind := ""
var style := 0

func setup(data: Dictionary) -> void:
	name=String(data.get("id","Building"))
	building_kind=data.kind
	var seed_value := posmod(String(data.name).hash(),100000)
	style=int(data.get("style",seed_value%6))
	set_meta("style",style)
	set_meta("kind",building_kind)
	var palette: Array=PALETTES[style]
	var wall: Color=palette[0]
	var roof_color: Color=palette[1]
	var wood: Color=palette[2]
	var footprint := KingdomData.building_rect(data)
	position=WorldGrid.point3(footprint.position)
	set_meta("grid_pivot","ground_corner")
	var w:=footprint.size.x/64
	var d:=footprint.size.y/64
	var tall: bool=building_kind in ["castle","tower","library"]
	var h: float=3.0 if tall else 1.55+(seed_value%4)*0.16
	if building_kind=="tavern":h=2.35
	surface=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(Vector3(0,0.05,0),Vector3(w+0.12,0.10,d+0.12),Color("71756c"),2)
	_box(Vector3(0,h/2+0.1,0),Vector3(w,h,d),wall,2 if building_kind in ["castle","stone_house","tower"] else 0)
	var roof_h:=0.8+(seed_value%3)*0.16
	if building_kind in ["tower","castle"]:
		_box(Vector3(0,h+0.22,0),Vector3(w+0.18,0.28,d+0.18),wall.darkened(0.16),2)
		for side in [-1,1]:
			for i in 5:
				_box(Vector3(side*w/2,h+0.5,lerpf(-d/2,d/2,i/4.0)),Vector3(0.22,0.45,0.26),wall,2)
			for i in 7:
				_box(Vector3(lerpf(-w/2,w/2,i/6.0),h+0.5,side*d/2),Vector3(0.28,0.45,0.22),wall,2)
		if building_kind=="castle":
			for side in [-1,1]:
				var at:=Vector3(side*w*0.34,h*0.75,-d*0.18)
				_box(at,Vector3(w*0.23,h*1.5,d*0.55),wall.darkened(0.05),2)
				_roof(Vector3(at.x,h*1.5+0.1,at.z),Vector2(w*0.29,d*0.62),1.6,roof_color,true)
	else:
		_roof(Vector3(0,h+0.10,0),Vector2(w+0.42,d+0.40),roof_h,roof_color,style%3==1)
		# Timber silhouettes and side windows make repeated types readable in 3D.
		for side in [-1,1]:
			_box(Vector3(side*(w/2-0.055),h/2+0.1,d/2+0.025),Vector3(0.11,h,0.09),wood,1)
			_box(Vector3(side*(w/2+0.02),h/2+0.08,0),Vector3(0.07,0.10,d),wood,1)
		_box(Vector3(0,h*0.62,d/2+0.035),Vector3(w,0.10,0.08),wood,1)
		if style%2==1:
			_box(Vector3(0,h/2+0.08,d/2+0.03),Vector3(0.10,h,0.08),wood,1)
		if seed_value%3!=0 or building_kind=="forge":
			_box(Vector3(w*0.25,h+0.55,-d*0.15),Vector3(0.34,1.35,0.40),Color("757978"),2)
			_box(Vector3(w*0.25,h+1.25,-d*0.15),Vector3(0.44,0.12,0.50),Color("494c48"),2)
	# Recessed door and warm framed glazing; the face is on the south wall.
	_box(Vector3(0,0.68,d/2+0.025),Vector3(0.55,1.20,0.07),wood.darkened(0.23),1)
	_box(Vector3(0,1.30,d/2+0.075),Vector3(0.70,0.12,0.12),wood,1)
	_box(Vector3(0.16,0.63,d/2+0.08),Vector3(0.045,0.045,0.03),Color("deb66d"),0)
	for side in [-1,1]:
		_window(Vector3(side*w*0.30,h*0.52,d/2+0.05),wood)
		if h>2.1:_window(Vector3(side*w*0.30,h*0.84,d/2+0.05),wood)
	for i in 2:_box(Vector3(0,0.04+i*0.04,d/2+0.12+(1-i)*0.10),Vector3(0.9,0.08,0.30),Color("96998a"),2)
	if building_kind in ["tavern","forge"]:
		var awning: Color=Color("7a9b86") if building_kind=="tavern" else Color("b7825b")
		_box(Vector3(w*0.25,1.44,d/2+0.28),Vector3(w*0.54,0.10,0.70),awning,0)
		for side in [-1,1]:_box(Vector3(w*0.25+side*w*0.23,0.7,d/2+0.52),Vector3(0.07,1.40,0.07),wood,1)
		_box(Vector3(-w*0.38,1.25,d/2+0.26),Vector3(0.40,0.40,0.08),Color("d9b866"),0)
	if building_kind=="forge":
		_box(Vector3(w*0.23,0.4,d/2+0.25),Vector3(0.50,0.22,0.30),Color("4a5052"),2)
	if building_kind in ["castle","tower"]:
		_box(Vector3(0,h+1.2,0),Vector3(0.06,1.9,0.06),wood,1)
		_box(Vector3(0.3,h+1.6,0),Vector3(0.60,0.38,0.04),KingdomData.REALMS[data.realm].color,0)
	var mesh:=MeshInstance3D.new()
	visual_mesh=mesh
	mesh.name="Architecture"
	mesh.position=Vector3(w/2,0,d/2)
	mesh.mesh=surface.commit()
	mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if shared_material==null:
		shared_material=ShaderMaterial.new()
		shared_material.shader=load("res://game/shaders/architecture.gdshader")
	mesh.material_override=shared_material
	add_child(mesh)
	set_meta("footprint",footprint)
	set_meta("height",h+roof_h)
	surface=null

func update_occlusion(camera:Camera3D,hero:Vector3,screen:Vector2,extent:Vector2)->void:
	var wanted:=false
	if global_position.distance_squared_to(hero)<14*14:
		var box:=visual_mesh.get_aabb()
		var rect:=Rect2(camera.unproject_position(visual_mesh.global_transform*box.position),Vector2.ZERO)
		for i in 8:
			var corner:=box.position+box.size*Vector3(i&1,(i>>1)&1,(i>>2)&1)
			rect=rect.expand(camera.unproject_position(visual_mesh.global_transform*corner))
		wanted=rect.intersects(Rect2(screen-extent,extent*2))
	if faded==wanted:return
	faded=wanted
	if wanted and shared_fade_material==null:
		# Keep early depth testing on ordinary houses; only real occluders need
		# the cutout pass. Both variants share the same architecture surface code.
		shared_fade_material=shared_material.duplicate()
		var shader:=Shader.new()
		var cutout:="""
 vec2 gap=(SCREEN_UV-hero_screen.xy)/hero_screen.zw;
 float front=smoothstep(0.10,0.65,hero_depth+VERTEX.z);
 float same_view=1.0-step(0.5,distance(INV_VIEW_MATRIX[3].xyz,main_camera));
 float opacity=1.0-(1.0-smoothstep(0.60,1.0,length(gap)))*front*same_view*0.78;
 float pattern=fract(dot(floor(FRAGCOORD.xy),vec2(0.5,0.25)))+0.125;
 if(pattern>opacity)discard;
"""
		shader.code=shared_material.shader.code.replace("void fragment() {","void fragment() {\n"+cutout)
		shared_fade_material.shader=shader
	visual_mesh.material_override=shared_fade_material if wanted else shared_material

func _box(at: Vector3, size: Vector3, color: Color, tag: float) -> void:
	var box:=BoxMesh.new()
	box.size=size
	_append(box,Transform3D(Basis.IDENTITY,at),color,tag)

func _append(mesh: Mesh, transform: Transform3D, color: Color, tag: float) -> void:
	var arrays:=mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	for index in indices:
		surface.set_color(color)
		surface.set_normal((transform.basis*normals[index]).normalized())
		surface.set_uv(uvs[index]);surface.set_uv2(Vector2(tag,0))
		surface.add_vertex(transform*vertices[index])

func _roof(at: Vector3, size: Vector2, height: float, color: Color, hip: bool) -> void:
	var x:=size.x/2
	var z:=size.y/2
	var a:=at+Vector3(-x,0,-z)
	var b:=at+Vector3(x,0,-z)
	var c:=at+Vector3(x,0,z)
	var d:=at+Vector3(-x,0,z)
	var e:=at+Vector3(0,height,-z*(0.50 if hip else 1.0))
	var f:=at+Vector3(0,height,z*(0.50 if hip else 1.0))
	for triangle in [[a,d,e],[d,f,e],[b,e,c],[c,e,f],[a,e,b],[d,c,f]]:
		var normal: Vector3=(triangle[1]-triangle[0]).cross(triangle[2]-triangle[0]).normalized()
		for v: Vector3 in triangle:
			surface.set_color(color);surface.set_normal(normal)
			surface.set_uv(Vector2(v.x,v.z));surface.set_uv2(Vector2(3,0))
			surface.add_vertex(v)

func _window(at: Vector3, wood: Color) -> void:
	_box(at,Vector3(0.46,0.57,0.09),wood,1)
	_box(at+Vector3(0,0,0.052),Vector3(0.34,0.44,0.025),Color("eac48d"),4)
	_box(at+Vector3(0,0,0.075),Vector3(0.035,0.44,0.02),wood,1)
	_box(at+Vector3(0,0,0.075),Vector3(0.34,0.035,0.02),wood,1)
