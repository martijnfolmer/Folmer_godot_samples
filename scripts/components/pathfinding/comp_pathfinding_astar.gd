extends Node2D

"""
	This is the component that does astar pathfinding without using the astar build in data type
	of godot. We use the grid class we made (class_grid.gd) to hold the 2d grid we use for 
	forward and backward propagation

	Uses CompPathfindingSelectionRect to define the bounds of where the Astar is going to go
	
	Any cell that is not on top of a floor cell will be unoccupied
"""


@export var enable : bool = true


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


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	_initialize_grid()
	

func _initialize_grid() -> void:
	
	# Find the closest selection rect that we can use for pathfinding
	var allSelectionRects = General.get_nodes_with_base_name(self, "CompPathfindingSelectionRect")
	if allSelectionRects.size() > 0:
		# Find the closest rect
		var closestRect= allSelectionRects.get(0)
		for rect in allSelectionRects.slice(1, allSelectionRects.size()-1):
			# are we inside of this rect
			if rect.has_point(global_position):
				closestRect = rect
				break
		TopLeft = closestRect.get_global_top_left()
		BottomRight = closestRect.get_global_bottom_right()

	
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
	
	if enable:
		# Occupied the occ
		_populate_occ_grid()

		# forward propagation
		

		# Redraw the grid for testing
		if draw_astar_enabled:
			queue_redraw()

#endregion


#region OCC grid, where we check which cells are blocked

func _populate_occ_grid() -> void:
	grid_occ.reset_grid(false)
	if grid_occ.cellSize.x <= 0.0 or grid_occ.cellSize.y <= 0.0:
		return

	var all_nodes: Array[Node] = General._nodes_in_groups(self, blocking_elements_groups_astar)
	
	# filter the parent node (goblin) from this population
	var exclude_node := get_parent()
	all_nodes = all_nodes.filter(func(n: Node) -> bool:
		return n != exclude_node
	)
	
	var seen: Dictionary = {}
	for n in all_nodes:
		if seen.has(n):
			continue
		seen[n] = true
		# check for collisionshapes
		for child in n.find_children("*", "CollisionShape2D", true, false):
			_mark_cells_for_collision_shape(child as CollisionShape2D)
		# check for collisionpolygons (TODO: check if we removed all of these, if so, don't use it)
		for child in n.find_children("*", "CollisionPolygon2D", true, false):
			_mark_cells_for_collision_polygon(child as CollisionPolygon2D)

	var floor_rects := _collect_cell_floor_world_rects()
	var gw: int = grid_occ.grid_width_cells
	var gh: int = grid_occ.grid_height_cells
	for j in range(gh):
		for i in range(gw):
			var center := grid_occ.get_center_pix(Vector2i(i, j))
			if !_center_on_any_floor_rect(center, floor_rects):
				grid_occ.set_cell(Vector2i(i, j), true)


func _collect_cell_floor_world_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var tree := get_tree()
	if tree == null:
		return rects
	for n in tree.get_nodes_in_group("cell_floor"):
		if !is_instance_valid(n):
			continue
		for child in n.find_children("*", "CollisionShape2D", true, false):
			var r := _collision_shape_world_aabb(child as CollisionShape2D)
			if r.has_area():
				rects.append(r)
	return rects


func _center_on_any_floor_rect(center: Vector2, floor_rects: Array[Rect2]) -> bool:
	for r in floor_rects:
		if r.has_point(center):
			return true
	return false


## Axis-aligned world bounds of a collision shape (handles rotation / skew).
func _collision_shape_world_aabb(cs: CollisionShape2D) -> Rect2:
	if cs == null or cs.disabled or cs.shape == null:
		return Rect2()
	var lr: Rect2 = cs.shape.get_rect()
	var xf: Transform2D = cs.global_transform
	var corners: Array[Vector2] = [
		xf * lr.position,
		xf * Vector2(lr.end.x, lr.position.y),
		xf * Vector2(lr.position.x, lr.end.y),
		xf * lr.end,
	]
	var r := Rect2(corners[0], Vector2.ZERO)
	for i in range(1, 4):
		r = r.merge(Rect2(corners[i], Vector2.ZERO))
	return r


func _collision_polygon_world_aabb(cp: CollisionPolygon2D) -> Rect2:
	if cp == null or cp.disabled or cp.polygon.is_empty():
		return Rect2()
	var xf: Transform2D = cp.global_transform
	var min_v: Vector2 = xf * cp.polygon[0]
	var max_v: Vector2 = min_v
	for i in range(1, cp.polygon.size()):
		var q: Vector2 = xf * cp.polygon[i]
		min_v.x = min(min_v.x, q.x)
		min_v.y = min(min_v.y, q.y)
		max_v.x = max(max_v.x, q.x)
		max_v.y = max(max_v.y, q.y)
	return Rect2(min_v, max_v - min_v)

## turn collisionshape into a rectangle that we can mark cells with
func _mark_cells_for_collision_shape(cs: CollisionShape2D) -> void:
	var aabb := _collision_shape_world_aabb(cs)
	_mark_cells_for_world_rect(aabb)

## turn polygon to rectangle, so we can mark cells that collide with the rectangle
func _mark_cells_for_collision_polygon(cp: CollisionPolygon2D) -> void:
	var aabb := _collision_polygon_world_aabb(cp)
	_mark_cells_for_world_rect(aabb)


## Marks cells whose world-space cell rectangles intersect `world_aabb` (clipped to the grid).
func _mark_cells_for_world_rect(world_aabb: Rect2) -> void:
	if !world_aabb.has_area():
		return
	var tl: Vector2 = grid_occ.topLeft
	var csz: Vector2 = grid_occ.cellSize
	var gw: int = grid_occ.grid_width_cells
	var gh: int = grid_occ.grid_height_cells
	var grid_rect := Rect2(tl, Vector2(gw * csz.x, gh * csz.y))
	var clipped := world_aabb.intersection(grid_rect)
	if !clipped.has_area():
		return

	var i0: int = clampi(int(floor((clipped.position.x - tl.x) / csz.x)), 0, gw - 1)
	var i1: int = clampi(int(ceil((clipped.end.x - tl.x) / csz.x)) - 1, 0, gw - 1)
	var j0: int = clampi(int(floor((clipped.position.y - tl.y) / csz.y)), 0, gh - 1)
	var j1: int = clampi(int(ceil((clipped.end.y - tl.y) / csz.y)) - 1, 0, gh - 1)
	if i1 < i0 or j1 < j0:
		return

	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var cell_rect := Rect2(tl.x + i * csz.x, tl.y + j * csz.y, csz.x, csz.y)
			if cell_rect.intersects(clipped):
				grid_occ.set_cell(Vector2i(i, j), true)

#endregion

#region forward propagation

#endregion


#region backward propagation

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
				x * target_grid.cellSize.x - global_position.x,
				y * target_grid.cellSize.y - global_position.y
			)


			var rect := Rect2(pos, target_grid.cellSize)
			draw_rect(rect, color, true)
			
	var width_px = target_grid.grid_width_cells * target_grid.cellSize.x
	var height_px = target_grid.grid_height_cells * target_grid.cellSize.y

	# Vertical lines
	for x in range(target_grid.grid_width_cells + 1):
		var px = x * target_grid.cellSize.x
		draw_line(
			Vector2(px - global_position.x,  - global_position.y),
			Vector2(px - global_position.x, height_px - global_position.y),
			target_grid.grid_color,
			target_grid.grid_line_width
		)

	# Horizontal lines
	for y in range(target_grid.grid_height_cells + 1):
		var py = y * target_grid.cellSize.y
		draw_line(
			Vector2(-global_position.x, py - global_position.y),
			Vector2(width_px - global_position.x, py - global_position.y),
			target_grid.grid_color,
			target_grid.grid_line_width
		)





#endregion
