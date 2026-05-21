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

# constants
const BORDER_COOR_NO_DIAGONAL: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(0, -1),
	Vector2i(-1, 0),
	Vector2i(0, 1),
]

const BORDER_COOR_ONLY_DIAGONAL: Array[Vector2i] = [
	Vector2i(1, -1),
	Vector2i(-1, -1),
	Vector2i(-1, 1),
	Vector2i(1, 1),
]

const BORDER_COOR_ALL: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(1, -1),
	Vector2i(0, -1),
	Vector2i(-1, -1),
	Vector2i(-1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1),
	Vector2i(1, 1),
]

# Drawing the grid
@export var grid_color: Color = Color(0.225, 0.608, 0.0, 1.0)
@export var grid_line_width: float = 3.0


func _init(width: int = 10, height: int = 10, default_value: Variant = null) -> void:
	grid_width_cells = width
	grid_height_cells = height
	resize_grid(width, height)
	reset_grid(default_value)


#region Pixel to cell and cell to pixel
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

## Take a world coordinate, and find its grid coordinate
func world_to_grid(pos: Vector2) -> Vector2i:
	if topLeft == null:
		push_error("Grid.topLeft is not set")
	if cellSize == null:
		push_error("Grid.topLeft is not set")

	var x := int(floor((pos.x - topLeft.x) / cellSize.x))
	var y := int(floor((pos.y - topLeft.y) / cellSize.y))
	return Vector2i(x, y)

#endregion


#region resize grid
## Change the size of the grid
func resize_grid(width: int, height: int, default_value: Variant = null) -> void:
	grid_width_cells = width
	grid_height_cells = height
	grid_size = grid_width_cells * grid_height_cells

	grid.resize(grid_size)

	for i in range(grid_size):
		grid[i] = default_value

#endregion

#region setting cells
## set all values inside of a grid to a certain value
func reset_grid(val: Variant = null) -> void:
	set_region(
		Vector2i(0, 0),
		Vector2i(grid_width_cells - 1, grid_height_cells - 1),
		val
	)

## Set value at position in the grid
func set_cell(pos: Vector2i, val: Variant) -> bool:
	if not is_in_bounds(pos):
		push_error("Grid.set_cell: position out of bounds: %s" % pos)
		return false

	grid[get_index(pos)] = val
	return true

## Set a specific region of the grid to a certain value
func set_region(top_left: Vector2i, bottom_right: Vector2i, val: Variant) -> void:
	var start_x: int = max(0, top_left.x)
	var start_y: int = max(0, top_left.y)
	var end_x: int = min(grid_width_cells - 1, bottom_right.x)
	var end_y: int = min(grid_height_cells - 1, bottom_right.y)

	for y in range(start_y, end_y + 1):
		for x in range(start_x, end_x + 1):
			grid[x + y * grid_width_cells] = val

#endregion

#region Getting cells
## Get value at position in the grid
func get_cell(pos: Vector2i) -> Variant:
	if not is_in_bounds(pos):
		push_error("Grid.get_cell: position out of bounds: %s" % pos)
		return null

	return grid[get_index(pos)]

## Get border cells values
func get_border_values(pos: Vector2i, allow_diagonal: bool) -> Array:
	
	var all_values = []
	
	# check diagonal or not
	var border = BORDER_COOR_NO_DIAGONAL	
	if allow_diagonal:
		border = BORDER_COOR_ALL
	
	# get the coordinats that are within bounds of the coordinate
	var border_coor = get_border_coordinates(pos, border)
	
	# Get the values
	for coor in border_coor:
		all_values.append(get_cell(coor))

	return all_values

## Get the coordinates of the border cells, if they are in bounds of the grid
func get_border_coordinates(pos: Vector2i, border_coor: Array) -> Array:
	
	var all_coordinates = []
	for coor in border_coor:
		if is_in_bounds(Vector2i(pos.x + coor.x, pos.y + coor.y)):
			all_coordinates.append(Vector2i(pos.x + coor.x, pos.y + coor.y))
	return all_coordinates


## Cell values along the discrete line from [param pos1] to [param pos2] (inclusive order).
## Only in-bounds cells are included, pass on world coordinates
func get_line_values_pix_coor(pos1: Vector2, pos2: Vector2) -> Array:
	var cellCoor1 = world_to_grid(pos1)
	var cellCoor2 = world_to_grid(pos2)
	return get_line_values_grid_coor(cellCoor1, cellCoor2)


## Cell values along the discrete line from [param pos1] to [param pos2] (inclusive order).
## Only in-bounds cells are included, pass on grid coordinates
func get_line_values_grid_coor(pos1: Vector2i, pos2: Vector2i) -> Array:
	var all_values: Array = []

	for coor in get_line_coordinates(pos1, pos2):
		all_values.append(get_cell(coor))

	return all_values


## Integer Bresenham line from [param pos1] to [param pos2], inclusive, in traversal order.
## Only coordinates inside the grid are returned so callers can safely use [method get_cell]
func get_line_coordinates(pos1: Vector2i, pos2: Vector2i) -> Array[Vector2i]:
	var all_coordinates: Array[Vector2i] = []
	var x0: int = pos1.x
	var y0: int = pos1.y
	var x1: int = pos2.x
	var y1: int = pos2.y
	var dx: int = absi(x1 - x0)
	var dy: int = -absi(y1 - y0)
	var sx: int = signi(x1 - x0)
	var sy: int = signi(y1 - y0)
	var err: int = dx + dy

	while true:
		var p := Vector2i(x0, y0)
		if is_in_bounds(p):
			all_coordinates.append(p)
		if x0 == x1 and y0 == y1:
			break
		var e2: int = err + err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy

	return all_coordinates


#endregion


#region Helpers
func is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < grid_width_cells and pos.y < grid_height_cells

## The grid is a single dimension array, so this turns the 2d vector (x,y) to the position
func get_index(pos: Vector2i) -> int:
	return pos.x + pos.y * grid_width_cells
#endregion
