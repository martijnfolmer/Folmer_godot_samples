extends Node2D

## The top left coordinates of the grid we check
@export var TopLeft : Vector2 = Vector2.ZERO
## The bottom right coordinates of the grid we check
@export var BottomRight : Vector2 = Vector2.ZERO
## The size of the cell (width x height)
@export var CellSize : Vector2 = Vector2.ZERO

@export_group("blocking_elements")
## Physics groups whose colliders block line-of-sight raycasts to the player.
@export var blocking_elements_groups_los: Array[StringName] = ["pillar", "wall"]
## Physics groups treated as solid for A* grid marking and path-smoothing obstacle checks.
@export var blocking_elements_groups_astar: Array[StringName] = ["pillar", "wall", "glass", "goblin"]



@export_group("Path Debug")
## When true, draws the active path from the body to waypoints in the editor/game view.
@export var draw_astar_enabled: bool = true

## Color used for path debug lines.
@export var path_line_color: Color = Color(0.2, 1.0, 0.2, 0.95)
## Width of path debug lines.
@export var path_line_width: float = 2.0
## The color of the grid if it is available / non-blocked
@export var grid_color_available: Color = Color(0.2, 0.2, 1.0, 0.949)
## The color of the grid if is is not available
@export var grid_color_blocked : Color = Color(1.0, 0.2, 0.4, 0.949)
## Width of the lines showing the grid
@export var grid_line_width: float = 3.0



# The grid that is just true or false, based on whether it is blocked or not
var grid_occ : Grid
# The grid that we ust for forward and backward propagation
var grid_cost : Grid
# width of the grid, in number of cells
var grid_width : int = 0
# height of the grid, in number of cells
var grid_height : int = 0

# Todo:
# initializing grids (done)
# - get all nodes from a certain group (general) (done)
# - set TopLeft, BottomRight, CellSize + reset grid
# draw the grid based on true or false

# Populate occ grid with whether it overlaps with any blockers
# Add lines to the drawing of the grid

# - line of sight function : only pillar and walls block sight
# - Populate grid (but not with the one calling it)
# - recreate grid



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	_initialize_grid()
	

func _initialize_grid() -> void:
	# find out how many cells there are
	grid_width = ceil((BottomRight.x - TopLeft.x)/CellSize.x)
	grid_height = ceil((BottomRight.y - TopLeft.y)/CellSize.y)
	
	# initialize our grid with 0 values
	grid_cost = Grid.new(grid_width, grid_height, 0)
	grid_cost.set_pixel_coordinates(TopLeft, BottomRight, CellSize)

	grid_occ = Grid.new(grid_width, grid_height, false)
	grid_occ.set_pixel_coordinates(TopLeft, BottomRight, CellSize)



#region Lifetime
func _process(delta: float) -> void:
	
	# Occupied the occ
	_populate_occ_grid()

	# Redraw the grid for testing
	if draw_astar_enabled:
		queue_redraw()

#endregion


#region processing grid

func _populate_occ_grid() -> void:
	
	# Reset the grid
	grid_occ.reset_grid(false)

	# find collisions
	var allNodes = General._nodes_in_groups(self, blocking_elements_groups_astar)


#endregion









#region : Drawing Helpers
func _draw() -> void:
	draw_grid_occ(grid_occ)

func draw_grid_occ(target_grid: Grid) -> void:
	var alpha := 0.4 # 0.0 = invisible, 1.0 = opaque

	for x in range(target_grid.grid_width_cells):
		for y in range(target_grid.grid_height_cells):
			var val = target_grid.get_cell(Vector2(x, y))
			var color: Color = grid_color_available if !val else grid_color_blocked
			color.a = alpha
			
			var pos := Vector2(
				x * target_grid.cellSize.x,
				y * target_grid.cellSize.y
			)

			var rect := Rect2(pos, target_grid.cellSize)
			draw_rect(rect, color, true)

#func draw_grid_occ(target_grid: Grid) -> void:
##
##
##
##
##
	##var width_px = target_grid.grid_width_cells * target_grid.cellSize.x
	##var height_px = target_grid.grid_height_cells * target_grid.cellSize.y
##
##
##
##
	### Vertical lines
	##for x in range(target_grid.grid_width_cells + 1):
		##var px = x * target_grid.cellSize.x
		##draw_line(
			##Vector2(px, 0),
			##Vector2(px, height_px),
			##target_grid.grid_color,
			##target_grid.grid_line_width
		##)
##
	### Horizontal lines
	##for y in range(target_grid.grid_height_cells + 1):
		##var py = y * target_grid.cellSize.y
		##draw_line(
			##Vector2(0, py),
			##Vector2(width_px, py),
			##target_grid.grid_color,
			##target_grid.grid_line_width
		##)




#endregion
