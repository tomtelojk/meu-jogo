class_name WorldGrid
extends RefCounted

# Construction uses metres in 3D and the original XY simulation in pixels.
# Every module has a ground-level corner pivot on an integer grid vertex.
const CELL_SIZE:=1.0
const UNITS_PER_METRE:=64.0
const CELL:=CELL_SIZE*UNITS_PER_METRE
const NAVIGATION_STEP:=CELL/2.0
const VERSION:=2
const EPSILON:=0.0001
const WALL_THICKNESS:=0.25
const WALL_HEIGHT:=2.0
const FLOOR_HEIGHT:=0.08
const ROOF_BOTTOM:=WALL_HEIGHT
const ROOF_THICKNESS:=0.12

static func cell_at(point:Vector2)->Vector2i:return Vector2i((point/CELL).floor())
static func vertex_at(point:Vector2)->Vector2i:return Vector2i((point/CELL).round())
static func world(cell:Vector2i)->Vector2:return Vector2(cell)*CELL
static func point3(point:Vector2,height:float=0.0)->Vector3:return Vector3(point.x/UNITS_PER_METRE,height,point.y/UNITS_PER_METRE)
static func rotate_cell(point:Vector2i,turn:int)->Vector2i:
	match posmod(turn,4):
		1:return Vector2i(-point.y,point.x)
		2:return -point
		3:return Vector2i(point.y,-point.x)
	return point
static func minimum_offset(size:Vector2i,turn:int)->Vector2i:
	var diagonal:=rotate_cell(size,turn)
	return Vector2i(mini(0,diagonal.x),mini(0,diagonal.y))
static func anchor(minimum:Vector2i,size:Vector2i,turn:int)->Vector2i:return minimum-minimum_offset(size,turn)
static func rect(at:Vector2i,size:Vector2i,turn:int)->Rect2:
	var diagonal:=rotate_cell(size,turn)
	return Rect2(world(at+minimum_offset(size,turn)),Vector2(absi(diagonal.x),absi(diagonal.y))*CELL)
static func node_key(at:Vector2i)->String:return "%d,%d"%[at.x,at.y]
static func edge_points(entry:Dictionary)->Array[Vector2i]:
	var start:=Vector2i(roundi(entry.x),roundi(entry.y))
	return [start,start+rotate_cell(Vector2i.RIGHT,int(entry.get("turn",0)))]
static func edge_key(entry:Dictionary)->String:
	var points:=edge_points(entry);var start:Vector2i=points[0];var end:Vector2i=points[1]
	return ("h:" if start.y==end.y else "v:")+node_key(Vector2i(mini(start.x,end.x),mini(start.y,end.y)))
static func aligned(value:Variant)->bool:return (value is int or value is float) and is_finite(float(value)) and absf(float(value)-roundf(float(value)))<EPSILON
