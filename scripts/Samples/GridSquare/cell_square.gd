extends Node2D
class_name Cell

enum CellType { EMPTY, ROAD, ROCK }

var grid_x: int
var grid_y: int
var cell_type: CellType = CellType.EMPTY

func init(x: int, y: int, t: CellType = CellType.EMPTY) -> void:
	grid_x = x
	grid_y = y
	set_type(t)

func set_type(t: CellType) -> void:
	cell_type = t
	# match cell_type:
	# 	CellType.EMPTY: ...
	# 	CellType.ROAD:  ...
	# 	CellType.ROCK:  ...
