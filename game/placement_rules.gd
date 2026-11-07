class_name PlacementRules
extends Resource

## Distances are metres. The 2D simulation uses WorldGrid.UNITS_PER_METRE.
@export_range(0.25, 8.0, 0.25) var road_margin := 0.5
@export_range(0.25, 8.0, 0.25) var water_margin := 0.5
@export_range(0.125, 4.0, 0.125) var rock_margin := 0.25
@export_range(0.125, 4.0, 0.125) var building_margin := 0.25
@export_range(0.5, 12.0, 0.25) var village_setback := 1.0
@export_range(1.0, 64.0, 1.0) var relocation_radius := 32.0
@export var protect_decorations := true
static var _defaults:PlacementRules

static func defaults()->PlacementRules:
	if _defaults==null:_defaults=load("res://game/data/placement_rules.tres")
	return _defaults

func units(field:String)->float:
	return maxf(0.125,float(get(field)))*WorldGrid.UNITS_PER_METRE
