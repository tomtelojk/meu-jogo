class_name SettlementLayout
extends RefCounted

# Generation 3: all public curves are immutable before reserving the first lot.
# Generation 2 is a frozen data snapshot so authored maps retain their IDs.
static func legacy_v2()->Dictionary:
	var raw:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://game/data/settlements_v2.json"))
	var out:={"buildings":[],"roads":[],"places":{}}
	for b in raw.buildings:
		var item:Dictionary=b.duplicate();item.tile=Vector2(b.tile[0],b.tile[1]);item.size=Vector2(b.size[0],b.size[1]);out.buildings.append(item)
	for source in raw.roads:
		var road:=PackedVector2Array()
		for point in source:road.append(Vector2(point[0],point[1]))
		out.roads.append(road)
	for id in raw.places:out.places[id]=Vector2(raw.places[id][0],raw.places[id][1])
	return out

static func generate(towns:Array[Dictionary],legacy_places:Dictionary,rules:PlacementRules=null)->Dictionary:
	if rules==null:rules=PlacementRules.defaults()
	var buildings:Array[Dictionary]=[];var roads:Array[PackedVector2Array]=[]
	var out:={"buildings":buildings,"roads":roads,"places":legacy_places.duplicate(true),"unplaced":[]}
	var branches:Dictionary={}
	_country_roads(out)
	# Phase 1 includes every town, bridge approach and route to gathering grounds.
	for town in towns:
		var c:Vector2=town.position
		var rng:=RandomNumberGenerator.new();rng.seed=String(town.id).hash()^193741
		var spine:=_curve([c+Vector2(40,-1152),c+Vector2(360,-800),c+Vector2(350,-400),c,c+Vector2(0,384),c+Vector2(-64,960),c+Vector2(32,1560)])
		roads.append(spine);branches[town.id]=[]
		for level in (5 if town.capital else 4):
			for side in [-1,1]:
				var y:float=(-900+level*650 if town.capital else -450+level*600)+rng.randf_range(-125,125)
				var reach:float=2600 if town.capital else 2000
				var bend:=rng.randf_range(-160,160)
				var target:=c+Vector2(0,y);var start:=target;var best:=INF
				for i in range(1,spine.size()):
					var at:=Geometry2D.get_closest_point_to_segment(target,spine[i-1],spine[i])
					if at.distance_squared_to(target)<best:best=at.distance_squared_to(target);start=at
				var road:=_curve([start,c+Vector2(side*reach*0.4,y+bend),c+Vector2(side*reach*0.75,y+bend*0.5+90),c+Vector2(side*reach,y+rng.randf_range(-100,140))])
				branches[town.id].append(road);roads.append(road)
		for prefix in ["wood","stone"]:
			var center:Vector2=out.places[town.id+"_"+prefix]
			roads.append(_curve([c+Vector2(0,1200),c+Vector2(-480,1480),center+Vector2(0,240)]))
	var manager:=RoadManager.new()
	for i in roads.size():manager.register_path("road_"+str(i),roads[i])
	for town in towns:manager.register_plaza(town.id,town.position)
	var context:={"roads":manager,"base":"reinos","generation":3,"terrain":{},"rules":rules,"buildings":[],"resources":[],"reservations":[]}
	for town in towns:
		context.reservations.append({"id":"farm_"+town.id,"owner":"public_farm","rect":Rect2(town.position+Vector2(1472,640),Vector2(384,384))})
		for kind in ["wood","stone"]:
			for point in NaturalLandscape.grove(out.places[town.id+"_"+kind],kind):context.resources.append({"position":point,"radius":14.0,"kind":kind})
	# Phase 2: reserve services and construction plots before filling residential lots.
	for town in towns:
		var c:Vector2=town.position
		if town.capital:_service(out,context,town,"Castelo de "+town.name,"castle",c+Vector2(0,-512),Vector2(512,320))
		for kind in ["forge","tavern"]:
			var data:=_service(out,context,town,("Ferraria e comércio de " if kind=="forge" else "Estalagem de ")+town.name,kind,c+Vector2(-256 if kind=="forge" else 320,128),Vector2(256,192))
			if not data.is_empty():
				data.service_town=town.id
				var at:=HouseKit.approach(data);var role:="shop" if kind=="forge" else "inn"
				out.places[town.id+"_"+role]=at
				for i in 6:out.places[town.id+"_"+role+"_"+str(i)]=at+Vector2((i%3-1)*24,24+(i/3)*24)
		if town.id=="aurelia":
			for special in [{"name":"Forja de Bento","kind":"forge","at":Vector2(4224,4224),"point":"forge"},{"name":"Arquivo dos Reinos","kind":"library","at":Vector2(4992,3840),"point":"archives"}]:
				var data:=_service(out,context,town,special.name,special.kind,special.at,Vector2(192,128))
				if not data.is_empty():out.places[special.point]=HouseKit.approach(data)
		if not town.capital:
			var at:Vector2=out.places[town.id+"_plot"]
			var plot:={"id":"plot_"+town.id,"name":"Terreno de um morador","kind":"cottage","owner":town.id+"_resident_0","tile":at/64,"size":Vector2(192,128)}
			var found:=PlacementValidator.find_site(plot,context,rules.units("relocation_radius"),false)
			if found.ok:
				var entry:Dictionary=found.building
				out.places[town.id+"_plot"]=entry.tile*64
				context.reservations.append({"id":plot.id,"owner":plot.owner,"rect":KingdomData.building_rect(entry).grow(PlacementValidator.DECORATION_MARGIN)})
	# Phase 3: homes follow road tangents; the road network is never extended here.
	for town in towns:
		var rng:=RandomNumberGenerator.new();rng.seed=String(town.id).hash()^81493
		var homes:Array[Vector2]=[];var wanted:=36 if town.capital else 12
		for attempt in 5000:
			if homes.size()>=wanted:break
			var road:PackedVector2Array=branches[town.id][attempt%branches[town.id].size()]
			var segment:=rng.randi_range(1,road.size()-1)
			var point:=road[segment-1].lerp(road[segment],rng.randf_range(0.1,0.9))
			var tangent:Vector2=(road[segment]-road[segment-1]).normalized()
			var normal:=Vector2(-tangent.y,tangent.x)*(1 if attempt%2==0 else -1)
			var kind:String=["cottage","timber","stone_house"][rng.randi_range(0,2)]
			var style:String=HouseKit.KINDS[kind];var seed_value:=rng.randi_range(0,2147483646)
			var turn:=PlacementValidator.facing_turn(-normal)
			var size:=HouseKit.size_for(style,seed_value,turn)
			var projection:=absf(normal.x)*size.x/2+absf(normal.y)*size.y/2
			var setback:=maxf(rules.units("village_setback"),rules.units("road_margin"))
			var center:=point+normal*(RoadManager.HALF_WIDTH+RoadManager.BORDER_WIDTH+setback+PlacementValidator.DECORATION_MARGIN+projection)
			var corner:=(center-size/2).snapped(Vector2.ONE*WorldGrid.CELL)
			var at:=Vector2(corner.x+size.x/2,corner.y+size.y)
			var data:={"id":"house_"+town.id+"_"+str(homes.size()),"name":"Casa de "+town.name+" "+str(homes.size()+1),"kind":kind,"realm":town.realm,"tile":at/64,"size":size,"house_style":style,"house_seed":seed_value,"house_turn":turn,"town":town.id}
			if not PlacementValidator.validate(KingdomData.building_rect(data),context,{"decoration":true}).ok:continue
			var nearest:=manager.nearest(KingdomData.building_rect(data).get_center())
			data.house_turn=PlacementValidator.facing_turn(nearest.point-KingdomData.building_rect(data).get_center());data.front_road=nearest.id
			# Swapping a non-square kit changes the lot: validate again after orientation.
			data.size=HouseKit.size_for(style,seed_value,data.house_turn)
			var rect:=KingdomData.building_rect(data);var aligned:=rect.position.snapped(Vector2.ONE*WorldGrid.CELL)
			data.tile=Vector2(aligned.x+data.size.x/2,aligned.y+data.size.y)/64
			if not PlacementValidator.validate(KingdomData.building_rect(data),context,{"decoration":true}).ok:continue
			buildings.append(data);context.buildings.append({"id":data.id,"rect":KingdomData.building_rect(data),"decoration":true})
			homes.append(HouseKit.approach(data))
		if homes.size()<wanted:out.unplaced.append({"town":town.id,"requested":wanted,"placed":homes.size()})
		for i in 6:out.places[town.id+"_home_"+str(i)]=homes[i%homes.size()] if not homes.is_empty() else town.position+Vector2(0,384)
		for role in ["wood","stone","farm"]:
			for i in 4:out.places[town.id+"_"+role+"_"+str(i)]=out.places[town.id+"_"+role]+Vector2((i%2)*128-64,(i/2)*128+160)
		if town.id=="aurelia":
			for pair in [["bento_home",0],["lia_home",1],["eron_home",2]]:out.places[pair[0]]=out.places[town.id+"_home_"+str(pair[1])]
		if town.id=="valverde":
			for pair in [["iris_home",0],["mila_home",1]]:out.places[pair[0]]=out.places[town.id+"_home_"+str(pair[1])]
			out.places.mila_farm=out.places.valverde_farm+Vector2(0,160)
		for i in 3:out.places[town.id+"_garden_"+str(i)]=town.position+Vector2(420+i*96,-192+(i%2)*96)
		if town.capital:
			var king:="aurel" if town.id=="aurelia" else "caio"
			out.places[king+"_home"]=town.position+Vector2(-160,-400);out.places[king+"_garden"]=town.position+Vector2(480,-320)
	var river:=NaturalLandscape.river_center(4800);var width:=NaturalLandscape.river_width(4800)
	out.places.bridge_west=Vector2(river-width-128,4800);out.places.bridge_east=Vector2(river+width+128,4800)
	out.places.guard_post=Vector2(river+width+160,4800)
	var guard:={"realm":"valverde","id":"valverde"}
	var barracks:=_service(out,context,guard,"Quartel da Travessia","barracks",Vector2(river+width+320,4736),Vector2(192,128))
	out.places.barracks=HouseKit.approach(barracks) if not barracks.is_empty() else out.places.guard_post
	return out

static func _service(out:Dictionary,context:Dictionary,town:Dictionary,label:String,kind:String,at:Vector2,size:Vector2)->Dictionary:
	var data:={"id":"service_"+town.id+"_"+str(out.buildings.size()),"name":label,"kind":kind,"realm":town.realm,"tile":at/64,"size":size,"town":town.id}
	if kind in HouseKit.KINDS:
		data.merge({"house_style":HouseKit.KINDS[kind],"house_seed":posmod(label.hash(),2147483647),"house_turn":0})
		data.size=HouseKit.size_for(data.house_style,data.house_seed)
	var found:=PlacementValidator.find_site(data,context)
	if not found.ok:out.unplaced.append({"name":label,"reason":found.message});return {}
	data=found.building;out.buildings.append(data);context.buildings.append({"id":data.id,"rect":KingdomData.building_rect(data),"decoration":true})
	return data

static func _country_roads(out:Dictionary)->void:
	# Country roads bend with the landscape and approach each bridge along its
	# deck, rather than drawing a continent-sized orthogonal lattice.
	for points in [
		[Vector2(4648,2944),Vector2(4080,2640),Vector2(4480,1664),Vector2(5760,1664)],
		[Vector2(4640,5656),Vector2(3500,6380),Vector2(2800,7120),Vector2(3240,7040)],
		[Vector2(11304,4224),Vector2(12600,4880),Vector2(13200,6000),Vector2(13608,7040)],
		[Vector2(13600,9752),Vector2(13200,10700),Vector2(11700,11100),Vector2(10920,9088)],
		[Vector2(1536,1664),Vector2(2700,1900),Vector2(4080,2640)]]:
		out.roads.append(_curve(points))
	for y in [1280.0,4800.0,8192.0,11008.0]:
		var x:=NaturalLandscape.river_center(y)
		var span:=NaturalLandscape.river_width(y)+82
		var left:=Vector2(x-span,y);var right:=Vector2(x+span,y)
		out.roads.append(PackedVector2Array([left,right]))
		var west:=Vector2(4608,5536) if y<6000 else Vector2(3200,8576)
		var east:=Vector2(11264,6816) if y<6000 else Vector2(10880,10624)
		out.roads.append(_curve([west,Vector2(6100,y+200),left]))
		out.roads.append(_curve([right,Vector2(9800,y-240),east]))

static func _curve(anchors:Array)->PackedVector2Array:
	var result:=PackedVector2Array()
	for i in range(anchors.size()-1):
		var a:Vector2=anchors[maxi(0,i-1)];var b:Vector2=anchors[i];var c:Vector2=anchors[i+1];var d:Vector2=anchors[mini(anchors.size()-1,i+2)]
		var count:=maxi(4,ceili(b.distance_to(c)/120))
		for step in count:
			var t:=float(step)/count
			result.append(0.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t))
	result.append(anchors.back())
	return result
