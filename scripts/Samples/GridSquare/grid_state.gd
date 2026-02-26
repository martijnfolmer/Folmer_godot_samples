# res://scripts/Samples/GridSquare/grid_state.gd
class_name GridState
extends Object

var cells: Array = [] # will become Array[Array[Cell]]
var hover_cell_coor: Vector2
var hover_cell: Cell

func _init() -> void:
	hover_cell_coor = Vector2(-1, -1)
	hover_cell = null
	
func clear() -> void:
	cells.clear()

func set_size(w: int, h: int) -> void:
	cells.resize(h)
	for y in range(h):
		cells[y] = []
		cells[y].resize(w)

func set_cell(x: int, y: int, cell: Cell) -> void:
	cells[y][x] = cell

func get_cell(x: int, y: int) -> Cell:
	return cells[y][x]
