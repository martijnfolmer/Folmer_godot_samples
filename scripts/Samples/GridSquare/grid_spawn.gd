extends Node

@export var W: int = 10
@export var H: int = 10
@export var cell_size: Vector2 = Vector2(32, 32)
@export var cell_scene: PackedScene

var grid_state: GridState

func _ready() -> void:
	grid_state = GridState.new()
	spawn_grid()

func spawn_grid() -> void:
	grid_state.clear()
	grid_state.set_size(W, H)

	for y in range(H):
		for x in range(W):
			var cell := cell_scene.instantiate() as Cell
			add_child(cell)

			cell.position = Vector2(x * cell_size.x, y * cell_size.y)
			cell.init(x, y)

			grid_state.set_cell(x, y, cell)
