class_name HouseData
extends Resource

## A reusable, metre-based architectural kit. Geometry is baked into one mesh.
@export var id := "common"
@export var title := "Casa comum"
@export var description := "Madeira e reboco, com varanda."
@export var min_cells := Vector2i(3, 2)
@export var max_cells := Vector2i(5, 3)
@export var wall_height := 1.8
@export_range(1, 2) var floors := 1
@export var roof_height := 0.85
@export var eaves := 0.22
@export var hip_roof := false
@export var porch := true
@export var chimney := true
@export var wall_color := Color("d6c49e")
@export var roof_color := Color("667c68")
@export var timber_color := Color("624733")
@export var accent_color := Color("799a84")
@export var interior_cells := Vector2i(7, 6)
