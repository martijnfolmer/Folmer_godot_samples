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
@export var path_line_color: Color = Color(0.495, 0.001, 0.658, 0.949)
## Width of path debug lines.
@export var path_line_width: float = 5.0
## The color of the grid if it is available / non-blocked
@export var grid_color_available: Color = Color(0.2, 0.2, 1.0, 0.949)
## the color of the grid if is is available, but more expensive
@export var grid_color_expensive: Color = Color(0.897, 0.968, 0.368, 0.949)
## The color of the grid if is is not available
@export var grid_color_blocked : Color = Color(1.0, 0.2, 0.4, 0.949)
## Width of the lines showing the grid
@export var grid_line_width: float = 3.0
## Font size used for grid_path value text.
@export var grid_path_value_font_size: int = 14
## Color used for grid_path value text.
@export var grid_path_value_color: Color = Color.WHITE

@export_group("path cost")
## how much the ENWS borders of a cell that has cost INF also get a further cost
@export var EDGE_COST: int = 2
## How much moving diagonally costs more than moving straight
@export var additional_diagonal_cost : float = 0.1

# The grid that is just true or false, based on whether it is blocked or not
var grid_cost : Grid
# The grid that we ust for forward and backward propagation
var grid_path : Grid
# width of the grid, in number of cells
var grid_width : int = 0
# height of the grid, in number of cells
var grid_height : int = 0

var path_cell : Array = []
var path_cost : Array = []
var path_coor : Array = []


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
	grid_path = Grid.new(grid_width, grid_height, -1)
	grid_path.set_pixel_coordinates(TopLeft, BottomRight, CellSize)

	grid_cost = Grid.new(grid_width, grid_height, 1)
	grid_cost.set_pixel_coordinates(TopLeft, BottomRight, CellSize)



#region Lifetime
func _process(delta: float) -> void:
	
	if enable:
		# Occupied the occ
		_populate_occ_grid()

		# forward propagation
		forward_propagation()

		# backward propagation
		var player_nodes = General._nodes_in_group(self, "player")
		if player_nodes.size()>0:
			var player_node = player_nodes.get(0)
			backward_propagation(grid_cost.world_to_grid(player_node.global_position))# player coordinat

		# Redraw the grid for testing
		if draw_astar_enabled:
			queue_redraw()

#endregion


#region OCC grid, where we check which cells are blocked

func _populate_occ_grid() -> void:
	grid_cost.reset_grid(1)       # how much it costs to go to that place
	if grid_cost.cellSize.x <= 0.0 or grid_cost.cellSize.y <= 0.0:
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
	var gw: int = grid_cost.grid_width_cells
	var gh: int = grid_cost.grid_height_cells
	for j in range(gh):
		for i in range(gw):
			var center := grid_cost.get_center_pix(Vector2i(i, j))
			if !_center_on_any_floor_rect(center, floor_rects):
				grid_cost.set_cell(Vector2i(i, j), INF)
				
				# give cost to edges as well
				var border_coor = grid_cost.get_border_coordinates(Vector2i(i, j), grid_path.BORDER_COOR_NO_DIAGONAL)
				for coor in border_coor:
					var val = grid_cost.get_cell(coor)
					if val != INF:
						grid_cost.set_cell(coor, val + EDGE_COST) # give any nearby grids an extra cost


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
	var tl: Vector2 = grid_cost.topLeft
	var csz: Vector2 = grid_cost.cellSize
	var gw: int = grid_cost.grid_width_cells
	var gh: int = grid_cost.grid_height_cells
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
				grid_cost.set_cell(Vector2i(i, j), INF)
				
				# give cost to edges as well
				var border_coor = grid_cost.get_border_coordinates(Vector2i(i, j), grid_path.BORDER_COOR_NO_DIAGONAL)
				for coor in border_coor:
					var val = grid_cost.get_cell(coor)
					if val != INF:
						grid_cost.set_cell(coor, val + EDGE_COST) # give any nearby grids an extra cost

#endregion

#region forward propagation

## Do the forward propagation, where we calculate the cost from the calling cell onward
func forward_propagation() -> void:
	
	# reset the grid
	grid_path.reset_grid(-1)
	
	# add 0 to the location of the calling instance
	var coor = grid_path.world_to_grid(global_position)
	grid_path.set_cell(coor, 0)
	
	# start the cueu
	var check_queue = []
	check_queue.append(coor)
	
	# do the forward propagation
	while check_queue.size() > 0:
		var check_coor = check_queue.pop_front()
		var check_cost = grid_path.get_cell(check_coor)
		
		var borders = grid_path.get_border_coordinates(check_coor, grid_path.BORDER_COOR_ALL)
		
		for b_coor in borders:
			
			# Check if this is a diagonal thing. If so, we add a little extra cost
			var dist = abs(check_coor.x - b_coor.x) + abs(check_coor.y - b_coor.y)
			var add_cost = 0
			if dist > 1.0:
				add_cost = additional_diagonal_cost
			
			var b_current_cost = grid_path.get_cell(b_coor)
			var b_cost_to_get_there = grid_cost.get_cell(b_coor)
			var new_cost = check_cost + b_cost_to_get_there + add_cost
			
			if b_current_cost == -1:
				grid_path.set_cell(b_coor, new_cost)
				check_queue.append(b_coor)
			elif new_cost < b_current_cost:
				grid_path.set_cell(b_coor, new_cost)
				check_queue.append(b_coor)
#endregion


#region backward propagation
func backward_propagation(goal_coor : Vector2) -> void:
	
	'''
		To return
		path_cell -> cell coordinate
		path_cost -> how much it costs to go there
		path_coor -> real world coordinates
	'''
	
	# cell coordinates for path
	path_cell = []
	# Cost of moving to a certain part
	path_cost = []
	# grid coordinates for path
	path_coor = []
	
	
	var cur_loc = goal_coor
	path_cell.append(goal_coor)
	path_cost.append(grid_path.get_cell(goal_coor))
	path_coor.append(grid_path.get_center_pix(goal_coor))
	var kn = 0

	while true:
		var all_val = grid_path.get_border_values(cur_loc, true)
		var all_loc = grid_path.get_border_coordinates(cur_loc, grid_path.BORDER_COOR_ALL)
		
		var min_val_idx = General.get_min_index_arr(all_val)
		var min_val = General.get_min_arr(all_val)
		var min_coor = all_loc[min_val_idx]
		
		cur_loc = min_coor
		path_cell.append(min_coor)
		path_cost.append(min_val)
		path_coor.append(grid_path.get_center_pix(min_coor))
		
		if min_val == 0:
			break
		kn += 1
		if kn >= 100:
			break

	# reverse the paths
	path_cell.reverse()
	path_cost.reverse()
	path_coor.reverse()


#endregion






#region : Drawing Helpers
func _draw() -> void:
	draw_grid_cost(grid_cost)
	draw_grid_path_values(grid_path)
	draw_path_coor()

func draw_path_coor() -> void:
	if !draw_astar_enabled:
		return

	if path_coor.size() < 2:
		return

	for i in range(path_coor.size() - 1):
		var from_pos: Vector2 = to_local(path_coor[i])
		var to_pos: Vector2 = to_local(path_coor[i + 1])

		draw_line(
			from_pos,
			to_pos,
			path_line_color,
			path_line_width
		)

func draw_grid_cost(target_grid: Grid) -> void:
	var alpha := 0.4 # 0.0 = invisible, 1.0 = opaque

	for x in range(target_grid.grid_width_cells):
		for y in range(target_grid.grid_height_cells):
			var val = target_grid.get_cell(Vector2(x, y))
			#var color: Color = grid_color_available if !val else grid_color_blocked
			
			var color: Color = grid_color_available
			if is_inf(val):
				color = grid_color_blocked
			elif val > 1:
				color = grid_color_expensive
			else:
				color = grid_color_available 
			
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

func draw_grid_path_values(target_grid: Grid) -> void:
	if target_grid == null:
		return

	var font: Font = ThemeDB.fallback_font
	if font == null:
		return

	for x in range(target_grid.grid_width_cells):
		for y in range(target_grid.grid_height_cells):
			var coor := Vector2i(x, y)
			var val = target_grid.get_cell(coor)
			var text := str(val)

			# Center of the cell in world coordinates.
			var world_center: Vector2 = target_grid.get_center_pix(coor)

			# Convert world position to this Node2D's local draw coordinates.
			var local_center: Vector2 = to_local(world_center)

			var text_size: Vector2 = font.get_string_size(
				text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				grid_path_value_font_size
			)

			var ascent := font.get_ascent(grid_path_value_font_size)
			var descent := font.get_descent(grid_path_value_font_size)

			# draw_string() uses a baseline position, so compensate for visual centering.
			var text_pos := Vector2(
				local_center.x - text_size.x * 0.5,
				local_center.y + (ascent - descent) * 0.5
			)

			draw_string(
				font,
				text_pos,
				text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				grid_path_value_font_size,
				grid_path_value_color
			)



#endregion
