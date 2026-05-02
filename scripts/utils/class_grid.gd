# res://scripts/utils/class_grid.gd
class_name Grid

var grid_width_cells: int = 0
var grid_height_cells: int = 0
var grid_size: int
var grid: Array = []

# For calculating the pixel values that belong to the grid
var topLeft: Vector2
var bottomRight : Vector2
var cellSize : Vector2

#TODO: World_to_cell:
"""
	## Convert world position to current grid cell coordinates.
func _world_to_cell(world_pos: Vector2) -> Vector2i:
	var step: float = float(max(8, cell_size))
	var local: Vector2 = world_pos - _grid_origin
	return Vector2i(
		int(floor(local.x / step)),
		int(floor(local.y / step))
	)

"""


# Drawing the grid
@export var grid_color: Color = Color(0.225, 0.608, 0.0, 1.0)
@export var grid_line_width: float = 3.0


func _init(width: int = 10, height: int = 10, default_value: Variant = null) -> void:
	grid_width_cells = width
	grid_height_cells = height
	resize_grid(width, height)
	reset_grid(default_value)


func reset_grid(val: Variant = null) -> void:
	set_region(
		Vector2i(0, 0),
		Vector2i(grid_width_cells - 1, grid_height_cells - 1),
		val
	)

## set the intrinsic pixel coordinates of the grid
func set_pixel_coordinates(top_left : Vector2, bottom_right : Vector2, cell_size : Vector2):
	cellSize = cell_size
	bottomRight = bottom_right
	topLeft = top_left

## gets the pixel coordinates of a certain index, (x1, y1, x2, y2)
func get_rect_pix(pos: Vector2i) -> Rect2:
	if topLeft == null:
		push_error("Grid.topLeft is not set")
	if cellSize == null:
		push_error("Grid.topLeft is not set")
	if not is_in_bounds(pos):
		push_error("Grid.get_cell: position out of bounds: %s" % pos)

	var x1 = topLeft.x + cellSize.x * pos.x
	var y1 = topLeft.y + cellSize.y * pos.y
	var x2 = x1 + cellSize.x
	var y2 = y1 + cellSize.y
	return Rect2(x1, y1, x2, y2)

## Get the center pixel coordinates of the 
func get_center_pix(pos: Vector2i) -> Vector2:
	if topLeft == null:
		push_error("Grid.topLeft is not set")
	if cellSize == null:
		push_error("Grid.topLeft is not set")
	if not is_in_bounds(pos):
		push_error("Grid.get_cell: position out of bounds: %s" % pos)

	var x1 = topLeft.x + cellSize.x * pos.x
	var y1 = topLeft.y + cellSize.y * pos.y
	var x2 = x1 + cellSize.x
	var y2 = y1 + cellSize.y
	return Vector2((x1 + x2)/2, (y1 + y2)/2)


## Change the size of the grid
func resize_grid(width: int, height: int, default_value: Variant = null) -> void:
	grid_width_cells = width
	grid_height_cells = height
	grid_size = grid_width_cells * grid_height_cells

	grid.resize(grid_size)

	for i in range(grid_size):
		grid[i] = default_value


func is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < grid_width_cells and pos.y < grid_height_cells

## The grid is a single dimension array, so this turns the 2d vector (x,y) to the position
func get_index(pos: Vector2i) -> int:
	return pos.x + pos.y * grid_width_cells


## Get value at position in the grid
func get_cell(pos: Vector2i) -> Variant:
	if not is_in_bounds(pos):
		push_error("Grid.get_cell: position out of bounds: %s" % pos)
		return null

	return grid[get_index(pos)]


## Set value at position in the grid
func set_cell(pos: Vector2i, val: Variant) -> void:
	if not is_in_bounds(pos):
		push_error("Grid.set_cell: position out of bounds: %s" % pos)
		return

	grid[get_index(pos)] = val


## Set a specific region of the grid to a certain value
func set_region(top_left: Vector2i, bottom_right: Vector2i, val: Variant) -> void:
	var start_x: int = max(0, top_left.x)
	var start_y: int = max(0, top_left.y)
	var end_x: int = min(grid_width_cells - 1, bottom_right.x)
	var end_y: int = min(grid_height_cells - 1, bottom_right.y)

	for y in range(start_y, end_y + 1):
		for x in range(start_x, end_x + 1):
			grid[x + y * grid_width_cells] = val
