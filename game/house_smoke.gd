class_name HouseSmoke
extends MultiMeshInstance3D

const MAX_CHIMNEYS := 12
const PUFFS := 5
var game: ForestGame
var timer := 1.0
var sources:Dictionary={}
var selected_key:="__dirty__"

func setup(source: ForestGame) -> void:
	game=source
	multimesh=MultiMesh.new();multimesh.transform_format=MultiMesh.TRANSFORM_3D;multimesh.use_custom_data=true
	var quad:=QuadMesh.new();quad.size=Vector2.ONE;multimesh.mesh=quad
	multimesh.instance_count=MAX_CHIMNEYS*PUFFS;multimesh.visible_instance_count=0
	var material:=ShaderMaterial.new();material.shader=load("res://game/shaders/chimney_smoke.gdshader");material_override=material
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;extra_cull_margin=4.0
	for model in game.hybrid.architecture.get_children():
		if not model.house_plan.is_empty():cache_plan(String(model.name),model.house_plan)
	for id in game.rpg.houses:sync_house(id)
	game.world.house_updated.connect(sync_house)

func cache_plan(id:String,plan:Dictionary)->void:
	if not plan.kit.chimney:return
	sources[id]={"id":id,"at":WorldGrid.point3(plan.footprint.position)+plan.smoke,"point":plan.footprint.get_center(),"seed":plan.seed}
	selected_key="__dirty__"

func sync_house(id:String)->void:
	sources.erase(id);selected_key="__dirty__"
	var home:Dictionary=game.rpg.houses.get(id,{})
	if not home.is_empty() and home.stage==3:cache_plan(id,HouseKit.generate(HouseKit.from_home(id,home,game.rpg)))

func _process(delta: float) -> void:
	if game==null:return
	timer+=delta
	if timer<0.5:return
	timer=0
	var nearby:Array[Dictionary]=[]
	for entry in sources.values():
		if entry.point.distance_squared_to(game.player.position)<1200*1200:nearby.append(entry)
	nearby.sort_custom(func(a:Dictionary,b:Dictionary):return a.point.distance_squared_to(game.player.position)<b.point.distance_squared_to(game.player.position))
	nearby=nearby.slice(0,MAX_CHIMNEYS)
	var ids:=PackedStringArray()
	for entry in nearby:ids.append(entry.id)
	var key:=",".join(ids)
	if key==selected_key:return
	selected_key=key
	var count:=0
	for entry in nearby:
		var at:Vector3=entry.at
		for puff in PUFFS:
			multimesh.set_instance_transform(count,Transform3D(Basis.IDENTITY,at))
			multimesh.set_instance_custom_data(count,Color(float(puff)/PUFFS,float(entry.seed%100)*0.2,0,0));count+=1
	multimesh.visible_instance_count=count
