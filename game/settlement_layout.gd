class_name SettlementLayout
extends RefCounted

# The seed fixes lots and streets across visits. Generation 1 remains available
# for player-authored maps so an update cannot rearrange their edited towns.
static func generate(towns:Array[Dictionary],legacy_places:Dictionary)->Dictionary:
	var buildings:Array[Dictionary]=[]
	var roads:Array[PackedVector2Array]=[]
	var out:={"buildings":buildings,"roads":roads,"places":legacy_places.duplicate(true)}
	_country_roads(out)
	for town in towns:
		var c:Vector2=town.position
		var rng:=RandomNumberGenerator.new();rng.seed=String(town.id).hash()^193741
		var reserved:Array[Rect2]=[]
		if town.capital:_add(out,reserved,town,"Castelo de "+town.name,"castle",c+Vector2(0,-512),Vector2(512,320))
		_add(out,reserved,town,"Ferraria e comércio de "+town.name,"forge",c+Vector2(-192,128),Vector2(208,160))
		_add(out,reserved,town,"Estalagem de "+town.name,"tavern",c+Vector2(192,128),Vector2(208,160))
		var spine:Array[Vector2]=[c+Vector2(40,-1152),c+Vector2(360,-800),c+Vector2(350,-400),c,c+Vector2(0,384),c+Vector2(-64,960),c+Vector2(32,1560)]
		out.roads.append(_curve(spine))
		var branches:Array[PackedVector2Array]=[]
		for level in (4 if town.capital else 3):
			for side in [-1,1]:
				var y:float= (-900+level*650 if town.capital else -450+level*600)+rng.randf_range(-125,125)
				var reach:float=1740 if town.capital else 1060
				var bend:=rng.randf_range(-160,160)
				var road:=_curve([c+Vector2(0,y),c+Vector2(side*reach*0.4,y+bend),c+Vector2(side*reach*0.75,y+bend*0.5+90),c+Vector2(side*reach,y+rng.randf_range(-100,140))])
				branches.append(road);out.roads.append(road)
		# Named workplaces stay recognisable; all homes and their entrances follow
		# the new lots instead of unrelated points that can lie inside walls.
		var specials:Array=[]
		if town.id=="aurelia":specials=[{"name":"Forja de Bento","kind":"forge","at":Vector2(4224,4224),"point":"forge"},{"name":"Arquivo dos Reinos","kind":"library","at":Vector2(4992,3840),"point":"archives"}]
		for entry in specials:
			_add(out,reserved,town,entry.name,entry.kind,entry.at,Vector2(176,128))
			out.places[entry.point]=entry.at+Vector2(0,64)
		var homes:Array[Vector2]=[]
		var wanted:=36 if town.capital else 12
		for attempt in 600:
			if homes.size()>=wanted:break
			var arm:int=attempt%branches.size()
			var road:PackedVector2Array=branches[arm]
			var fraction:=rng.randf_range(0.21,0.95)
			var sample:=road[clampi(roundi(fraction*(road.size()-1)),0,road.size()-1)]
			var size:=Vector2(rng.randi_range(144,208),rng.randi_range(112,152))
			var at:=sample+Vector2(rng.randf_range(-26,26),-rng.randf_range(86,120))
			var rect:=Rect2(at-Vector2(size.x/2,size.y),size)
			var free:=true
			for wall in reserved:
				if wall.grow(46).intersects(rect):free=false;break
			if not free:continue
			for path in out.roads:
				if _hits_road(rect.grow(62),path):free=false;break
			if not free:continue
			_add(out,reserved,town,"Casa de "+town.name+" "+str(homes.size()+1),["cottage","timber","stone_house"][rng.randi_range(0,2)],at,size)
			homes.append(at+Vector2(0,52))
			out.roads.append(PackedVector2Array([sample,at+Vector2(0,38)]))
		for i in 6:
			out.places[town.id+"_home_"+str(i)]=homes[i%homes.size()] if not homes.is_empty() else c+Vector2(0,384)
		for prefix in ["wood","stone"]:
			var center:Vector2=out.places[town.id+"_"+prefix]
			out.roads.append(_curve([c+Vector2(0,1200),c+Vector2(-480,1480),center+Vector2(0,240)]))
		# Work is performed in reachable patches, away from the trunk/collision.
		for role in ["wood","stone","farm"]:
			for i in 4:out.places[town.id+"_"+role+"_"+str(i)]=out.places[town.id+"_"+role]+Vector2((i%2)*128-64,(i/2)*128+160)
		if town.id=="aurelia":
			for pair in [["bento_home",0],["lia_home",1],["eron_home",2]]:out.places[pair[0]]=out.places[town.id+"_home_"+str(pair[1])]
		if town.id=="valverde":
			for pair in [["iris_home",0],["mila_home",1]]:out.places[pair[0]]=out.places[town.id+"_home_"+str(pair[1])]
			out.places.mila_farm=out.places.valverde_farm+Vector2(0,160)
		for i in 3:out.places[town.id+"_garden_"+str(i)]=c+Vector2(420+i*96,-192+(i%2)*96)
		if town.capital:
			var king:="aurel" if town.id=="aurelia" else "caio"
			out.places[king+"_home"]=c+Vector2(-160,-400)
			out.places[king+"_garden"]=c+Vector2(480,-320)
	var river:=NaturalLandscape.river_center(4800)
	var width:=NaturalLandscape.river_width(4800)
	out.places.bridge_west=Vector2(river-width-128,4800);out.places.bridge_east=Vector2(river+width+128,4800)
	out.places.guard_post=Vector2(river+width+160,4800);out.places.barracks=Vector2(river+width+320,4800)
	_add(out,[],{"realm":"valverde"},"Quartel da Travessia","barracks",out.places.barracks-Vector2(0,64),Vector2(176,128))
	return out

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

static func _add(out:Dictionary,reserved:Array[Rect2],town:Dictionary,label:String,kind:String,at:Vector2,size:Vector2)->void:
	out.buildings.append({"name":label,"kind":kind,"realm":town.realm,"tile":at/64,"size":size})
	reserved.append(Rect2(at-Vector2(size.x/2,size.y),size))

static func _hits_road(rect:Rect2,path:PackedVector2Array)->bool:
	for i in range(1,path.size()):
		if rect.has_point(path[i]) or rect.has_point(path[i-1]):return true
		var a:=path[i-1];var b:=path[i]
		for edge in [[rect.position,Vector2(rect.end.x,rect.position.y)],[Vector2(rect.end.x,rect.position.y),rect.end],[rect.end,Vector2(rect.position.x,rect.end.y)],[Vector2(rect.position.x,rect.end.y),rect.position]]:
			if Geometry2D.segment_intersects_segment(a,b,edge[0],edge[1])!=null:return true
	return false

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
