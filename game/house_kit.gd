class_name HouseKit
extends RefCounted

const IDS := ["poor", "common", "rich", "tavern", "shop"]
const KINDS := {"cottage":"poor", "timber":"common", "stone_house":"rich", "tavern":"tavern", "forge":"shop", "library":"rich", "barracks":"common"}
static var resources: Dictionary = {}

static func style_for(data: Dictionary) -> String:
	return data.get("house_style", KINDS.get(data.get("kind", "timber"), "common"))

static func definition(id: String) -> HouseData:
	if not id in IDS: id = "common"
	if not resources.has(id): resources[id] = load("res://game/data/houses/" + id + ".tres")
	return resources[id]

static func seed_for(data: Dictionary) -> int:
	return posmod(int(data.get("house_seed", String(data.get("id", data.get("name", "house"))).hash())), 2147483647)

static func size_for(id: String, seed_value: int, turn: int = 0) -> Vector2:
	var kit := definition(id)
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	var size := Vector2(rng.randi_range(kit.min_cells.x, kit.max_cells.x), rng.randi_range(kit.min_cells.y, kit.max_cells.y)) * WorldGrid.CELL
	return Vector2(size.y, size.x) if posmod(turn, 2) == 1 else size

static func clean_options(data: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	if not data.get("house_style", "") in IDS: return result
	result.house_style = data.house_style
	for key in ["house_seed", "house_turn"]:
		var value: Variant = data.get(key, 0)
		if not ResourceProgress.number(value): return {}
		result[key] = posmod(int(value), 4 if key == "house_turn" else 2147483647)
	return result

static func from_home(id: String, home: Dictionary, rpg: RPGState) -> Dictionary:
	var data := {"id":id, "name":id, "kind":"timber" if home.owner == "player" else "cottage", "realm":KingdomData.realm_at(Vector2(home.x, home.y)), "tile":Vector2(home.x, home.y)/WorldGrid.CELL, "size":rpg.home_rect(home).size,"house_turn":posmod(int(home.get("house_turn",0)),4)}
	data.merge(clean_options(home), true)
	return data

## Pivots are ground corners. Rotation keeps the resulting footprint fixed;
## old fractional city lots use trimmed edge modules, new lots use whole cells.
static func generate(data: Dictionary) -> Dictionary:
	var kit := definition(style_for(data))
	var seed_value := seed_for(data)
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	var turn := posmod(int(data.get("house_turn", seed_value % 4 if kit.id in ["poor", "common", "rich"] else 0)), 4)
	var footprint := KingdomData.building_rect(data)
	var size := footprint.size / WorldGrid.UNITS_PER_METRE
	var local_size := Vector2(size.y, size.x) if turn % 2 else size
	var basis := Basis(Vector3.UP, turn * PI / 2.0)
	var corners := [Vector3.ZERO, basis*Vector3(local_size.x,0,0), basis*Vector3(0,0,local_size.y), basis*Vector3(local_size.x,0,local_size.y)]
	var minimum := Vector3.ZERO
	for p: Vector3 in corners: minimum = minimum.min(p)
	var transform := Transform3D(basis, -minimum)
	var w := local_size.x; var d := local_size.y
	# A porch occupies the front cell of the lot, rather than intruding on streets.
	var porch_depth := 1.0 if kit.porch and d >= 3.0 else 0.0
	var body_depth := d - porch_depth
	var height := kit.wall_height * kit.floors
	var door_x := minf(floorf(w / 2.0) + 0.5, w - 0.5)
	var door := transform * Vector3(door_x, 0, body_depth)
	var entrance := transform * Vector3(door_x, 0, d + 0.60)
	var variation := rng.randf_range(-0.055, 0.055)
	var wall := kit.wall_color.lightened(variation) if variation > 0 else kit.wall_color.darkened(-variation)
	var roof := kit.roof_color.lightened(rng.randf_range(0, 0.08))
	var palette_tints:=[Color("f2d8b5"),Color("bdcfb2"),Color("b4c5d8"),Color("e0bca0"),Color("c5bacf"),Color("c8b89c")]
	var palette:=posmod(int(data.get("style",seed_value%6)),6)
	wall=wall.lerp(wall*palette_tints[palette],0.32)
	roof=roof.lerp(roof*palette_tints[palette],0.26)
	var pieces: Array[Dictionary] = []
	for z in ceili(d):
		for x in ceili(w):
			var sx := minf(1.0,w-x); var sz := minf(1.0,d-z)
			pieces.append({"kind":"foundation", "at":Vector3(x+sx/2,0.08,z+sz/2), "size":Vector3(sx,0.16,sz)})
	for floor_index in kit.floors:
		for side in 4:
			var along_x := side < 2
			var length := w if along_x else body_depth
			var cells := ceili(length)
			for index in cells:
				var span := minf(1.0,length-index)
				var at := Vector3(index+span/2,0.16+floor_index*kit.wall_height,body_depth if side==0 else 0) if along_x else Vector3(0 if side==2 else w,0.16+floor_index*kit.wall_height,index+span/2)
				var is_door := side==0 and floor_index==0 and absf(at.x-door_x)<0.1
				var window := not is_door and (index+side+seed_value)%3!=0 and span>=0.75
				pieces.append({"kind":"door" if is_door else ("window" if window else "wall"), "at":at, "span":span, "turn":[0,2,3,1][side], "floor":floor_index})
	pieces.append({"kind":"roof", "at":Vector3(w/2,height+0.16,body_depth/2), "size":Vector2(w+kit.eaves*2,body_depth+kit.eaves*2)})
	if porch_depth > 0:
		pieces.append({"kind":"porch", "at":Vector3(w/2,0,body_depth+0.5), "width":w, "height":kit.wall_height})
	pieces.append({"kind":"steps", "at":Vector3(door_x,0,d)})
	if kit.chimney:
		pieces.append({"kind":"chimney", "at":Vector3(maxf(0.4,w-0.65),height+0.16+kit.roof_height*0.5,0.55), "height":0.8})
	var smoke := transform * Vector3(maxf(0.4,w-0.65),height+0.16+kit.roof_height*0.5+0.88,0.55)
	return {"style":kit.id, "seed":seed_value, "turn":turn, "kit":kit, "size":local_size, "height":height+kit.roof_height+0.16, "transform":transform, "pieces":pieces, "wall":wall, "roof":roof, "wood":kit.timber_color, "door":door, "entrance":WorldGrid.point3(footprint.position)+entrance, "smoke":smoke, "footprint":footprint}

static func approach(data: Dictionary) -> Vector2:
	var at: Vector3 = generate(data).entrance
	return Vector2(at.x, at.z) * WorldGrid.UNITS_PER_METRE
