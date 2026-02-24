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

	var cam_center = get_camera_center_world_px()
	var x1 = cam_center.x - cell_size.x * W / 2
	var y1 = cam_center.y - cell_size.y * H / 2

	for y in range(H):
		for x in range(W):
			var cell := cell_scene.instantiate() as Cell
			add_child(cell)

			cell.position = Vector2(x1 + x * cell_size.x, y1 + y * cell_size.y)
			cell.init(x, y, cell_size.x, cell_size.y)

			grid_state.set_cell(x, y, cell)
			
# Find the center of the camera
func get_camera_center_world_px() -> Vector2:
	var rect = get_viewport().get_visible_rect()
	return rect.position + rect.size/2
