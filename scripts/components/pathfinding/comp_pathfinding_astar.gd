extends Node2D

"""
	This is the component that does astar pathfinding without using the astar build in data type
	of godot. We use the grid class we made (class_grid.gd) to hold the 2d grid we use for 
	forward and backward propagation

	Uses CompPathfindingSelectionRect to define the bounds of where the Astar is going to go
	
	Any cell that is not on top of a floor cell will be unoccupied
"""


@export var enable : bool = true


## The top left coordinates of the grid we check (should be overwritten)
@export var TopLeft : Vector2 = Vector2.ZERO
## The bottom right coordinates of the grid we check (should be overwritten)
@export var BottomRight : Vector2 = Vector2.ZERO
## The size of the cell (width x height)
@export var CellSize : Vector2 = Vector2.ZERO


@export_group("blocking_elements")
## Physics groups whose colliders block line-of-sight raycasts to the player.
@export var blocking_elements_groups_los: Array[StringName] = ["pillar", "wall"]
## Physics groups treated as solid for A* grid marking and path-smoothing obstacle checks.
@export var blocking_elements_groups_astar: Array[StringName] = ["pillar", "wall", "glass", "goblin"]

@export_group("Path values")
## How often to refind the path
@export var refind_path_time : float = 1.0


@export_group("Path Debug")
## When true, draws the active path from the body to waypoints in the editor/game view.
@export var draw_astar_enabled: bool = false

## When true, draws the line of sight to the player, if the player still exists
@export var draw_los_enabled: bool = true

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

var path_cell : Array = []		# the cell coordinates of the path
var path_cost : Array = []		# how much it costs to go there
var path_coor : Array = []		# the pixel coordinates

## CollisionShape2D nodes belonging to non-goblin blocking groups, cached at ready.
## find_children() is only ever called once; per-refresh we iterate this flat list instead.
## Invalid entries (destroyed obstacles) are pruned from the list each path refresh.
var _non_goblin_shapes: Array[CollisionShape2D] = []
var _non_goblin_polygons: Array[CollisionPolygon2D] = []
## Floor rects are truly static — cached once and never rebuilt.
var _cached_floor_rects: Array[Rect2] = []
## Obstacle groups that change position at runtime and must be re-scanned each path refresh.
var _dynamic_obstacle_groups: Array[StringName] = [&"goblin"]
## World-space bounds from the arena SelectionRect; used for validation only.
var _world_grid_bounds: Rect2 = Rect2()
var _grid_initialized: bool = false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	call_deferred("_initialize_grid")


## World position used for grid seeding and LOS (CharacterBody2D, not this moving node).
func get_pathfinding_world_position() -> Vector2:
	var body := get_parent().get_node_or_null("CharacterBody2D") as Node2D
	if body != null:
		return body.global_position
	return global_position


func _resolve_selection_rect() -> SelectionRect:
	var all_rects: Array[Node] = General.get_nodes_with_base_name(self, "CompPathfindingSelectionRect")
	if all_rects.is_empty():
		push_error("CompPathfindingAstar: no CompPathfindingSelectionRect found in current scene.")
		return null

	var chosen: SelectionRect = all_rects[0] as SelectionRect
	if chosen == null:
		push_error("CompPathfindingAstar: CompPathfindingSelectionRect node is not a SelectionRect.")
		return null

	var world_pos := get_pathfinding_world_position()
	for candidate in all_rects.slice(1):
		var sr := candidate as SelectionRect
		if sr != null and sr.contains_global_point(world_pos):
			chosen = sr
			break
	return chosen


func _is_within_grid_bounds(world_pos: Vector2) -> bool:
	if not _grid_initialized:
		return false
	return _world_grid_bounds.has_point(world_pos)


func _initialize_grid() -> void:
	if CellSize.x <= 0.0 or CellSize.y <= 0.0:
		push_error("CompPathfindingAstar: CellSize must be set (width and height > 0).")
		return

	var selection_rect := _resolve_selection_rect()
	if selection_rect == null:
		return

	_world_grid_bounds = selection_rect.get_global_rect()
	TopLeft = _world_grid_bounds.position
	BottomRight = _world_grid_bounds.end

	grid_width = int(ceil((_world_grid_bounds.size.x) / CellSize.x))
	grid_height = int(ceil((_world_grid_bounds.size.y) / CellSize.y))
	if grid_width <= 0 or grid_height <= 0:
		push_error("CompPathfindingAstar: grid has no cells; check SelectionRect size and CellSize.")
		return

	grid_path = Grid.new(grid_width, grid_height, -1)
	grid_path.set_pixel_coordinates(TopLeft, BottomRight, CellSize)

	grid_cost = Grid.new(grid_width, grid_height, 1)
	grid_cost.set_pixel_coordinates(TopLeft, BottomRight, CellSize)

	_grid_initialized = true
	_cache_obstacle_shapes()
	if draw_astar_enabled or draw_los_enabled:
		queue_redraw()



#region Lifetime

func _process(_delta: float) -> void:
	# _draw() uses this node's local space; the goblin root moves every frame, so any
	# cached draw moves with it until we redraw. Refresh while debug overlays are on.
	if _grid_initialized and (draw_astar_enabled or draw_los_enabled):
		queue_redraw()


## Tries to find a path, either direct or using pathfinding
func refind_path() -> void:
	if not enable or not _grid_initialized:
		return

	var root := get_parent()
	if root != null and root.has_method("get_ground_state"):
		if root.call("get_ground_state") == Enums.GroundState.FALLING:
			return

	var player_nodes = General.nodes_in_group(self, "player")
	if player_nodes.is_empty():
		return
	var player_node = player_nodes[0]

	var enemy_world: Vector2 = get_pathfinding_world_position()
	var player_world: Vector2 = player_node.global_position

	if not _is_within_grid_bounds(enemy_world):
		push_warning("CompPathfindingAstar: goblin outside pathfinding grid bounds at %s" % enemy_world)
		return
	if not _is_within_grid_bounds(player_world):
		push_warning("CompPathfindingAstar: player outside pathfinding grid bounds at %s" % player_world)
		return

	var blocked := is_segment_blocked(enemy_world, player_world)

	if !blocked:
		path_coor = []
		path_coor.append(enemy_world)
		path_coor.append(player_world)
	else:
		_populate_occ_grid()

		if not forward_propagation():
			return

		var goal_coor: Vector2i = grid_cost.world_to_grid(player_world)
		if not grid_cost.is_in_bounds(goal_coor):
			push_warning("CompPathfindingAstar: player grid cell out of bounds: %s" % goal_coor)
			return
		backward_propagation(goal_coor)

#endregion


#region OCC grid, where we check which cells are blocked

## Called once at _ready(). Walks the scene tree with find_children() ONCE to build a flat
## list of all CollisionShape2D/Polygon2D nodes in non-goblin blocking groups. Also caches
## floor rects which are truly static. After this, no find_children() is ever called again.
func _cache_obstacle_shapes() -> void:
	_non_goblin_shapes.clear()
	_non_goblin_polygons.clear()

	var non_goblin_groups: Array[StringName] = []
	for g in blocking_elements_groups_astar:
		if not _dynamic_obstacle_groups.has(g):
			non_goblin_groups.append(g)

	for n in General.nodes_in_groups(self, non_goblin_groups):
		for child in n.find_children("*", "CollisionShape2D", true, false):
			_non_goblin_shapes.append(child as CollisionShape2D)
		for child in n.find_children("*", "CollisionPolygon2D", true, false):
			_non_goblin_polygons.append(child as CollisionPolygon2D)

	# Floor layout never changes at runtime — cache once.
	_cached_floor_rects = _collect_cell_floor_world_rects()


## Remove freed shape nodes from the cached lists (destroyed walls, glass, etc.).
func _prune_invalid_obstacle_shapes() -> void:
	var kept_shapes: Array[CollisionShape2D] = []
	for cs in _non_goblin_shapes:
		if is_instance_valid(cs):
			kept_shapes.append(cs)
	_non_goblin_shapes = kept_shapes

	var kept_polygons: Array[CollisionPolygon2D] = []
	for cp in _non_goblin_polygons:
		if is_instance_valid(cp):
			kept_polygons.append(cp)
	_non_goblin_polygons = kept_polygons


## Rebuild grid_cost from current obstacle state. No find_children() or group queries are
## needed for non-goblin obstacles: we iterate the cached shape list and prune dead entries.
## Goblins (dynamic) are still queried via the group since they enter/leave the scene.
func _populate_occ_grid() -> void:
	grid_cost.reset_grid(1)
	if grid_cost.cellSize.x <= 0.0 or grid_cost.cellSize.y <= 0.0:
		return

	# Prune shapes that have been freed (destroyed walls, glass, etc.)
	_prune_invalid_obstacle_shapes()

	# Mark non-goblin obstacles using their CURRENT transforms (handles moved pillars, etc.)
	for cs in _non_goblin_shapes:
		_mark_cells_for_collision_shape(cs)
	for cp in _non_goblin_polygons:
		_mark_cells_for_collision_polygon(cp)

	# Mark cells that sit outside any floor tile
	var gw: int = grid_cost.grid_width_cells
	var gh: int = grid_cost.grid_height_cells
	for j in range(gh):
		for i in range(gw):
			var center := grid_cost.get_center_pix(Vector2i(i, j))
			if !_center_on_any_floor_rect(center, _cached_floor_rects):
				grid_cost.set_cell(Vector2i(i, j), INF)
				var border_coor = grid_cost.get_border_coordinates(Vector2i(i, j), grid_path.BORDER_COOR_NO_DIAGONAL)
				for coor in border_coor:
					var val = grid_cost.get_cell(coor)
					if val != INF:
						grid_cost.set_cell(coor, val + EDGE_COST)

	# Dynamic obstacles: goblins can enter/leave the scene so we still query the group
	var exclude_node := get_parent()
	for group in _dynamic_obstacle_groups:
		for n in get_tree().get_nodes_in_group(group):
			if n == exclude_node:
				continue
			for child in n.find_children("*", "CollisionShape2D", true, false):
				_mark_cells_for_collision_shape(child as CollisionShape2D)
			for child in n.find_children("*", "CollisionPolygon2D", true, false):
				_mark_cells_for_collision_polygon(child as CollisionPolygon2D)


## Returns true if from→to intersects any non-goblin blocking obstacle.
## Computes AABBs fresh from the cached shape nodes' CURRENT global transforms — so it
## correctly handles pillars that have been moved and walls/glass that have been destroyed,
## without any scene-tree queries or find_children() calls.
func is_segment_blocked(from: Vector2, to: Vector2) -> bool:
	for cs in _non_goblin_shapes:
		if not is_instance_valid(cs):
			continue
		var r := General.collision_shape_world_aabb(cs)
		if r.has_area() and Geom2Util.line_intersects_rect(from.x, from.y, to.x, to.y, r):
			return true
	for cp in _non_goblin_polygons:
		if not is_instance_valid(cp):
			continue
		var r := General.collision_polygon_world_aabb(cp)
		if r.has_area() and Geom2Util.line_intersects_rect(from.x, from.y, to.x, to.y, r):
			return true
	return false


func _collect_cell_floor_world_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var tree := get_tree()
	if tree == null:
		return rects
	for n in tree.get_nodes_in_group("cell_floor"):
		if !is_instance_valid(n):
			continue
		for child in n.find_children("*", "CollisionShape2D", true, false):
			var r := General.collision_shape_world_aabb(child as CollisionShape2D)
			if r.has_area():
				rects.append(r)
	return rects


func _center_on_any_floor_rect(center: Vector2, floor_rects: Array[Rect2]) -> bool:
	for r in floor_rects:
		if r.has_point(center):
			return true
	return false


## Turn a CollisionShape2D into a world AABB and mark intersecting grid cells.
func _mark_cells_for_collision_shape(cs: CollisionShape2D) -> void:
	var aabb := General.collision_shape_world_aabb(cs)
	_mark_cells_for_world_rect(aabb)

## Turn a CollisionPolygon2D into a world AABB and mark intersecting grid cells.
func _mark_cells_for_collision_polygon(cp: CollisionPolygon2D) -> void:
	var aabb := General.collision_polygon_world_aabb(cp)
	_mark_cells_for_world_rect(aabb)


## Marks cells whose world-space cell rectangles intersect world_aabb (clipped to the grid).
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
				var border_coor = grid_cost.get_border_coordinates(Vector2i(i, j), grid_path.BORDER_COOR_NO_DIAGONAL)
				for coor in border_coor:
					var val = grid_cost.get_cell(coor)
					if val != INF:
						grid_cost.set_cell(coor, val + EDGE_COST)

#endregion

#region forward propagation

## Do the forward propagation, where we calculate the cost from the calling cell onward
func forward_propagation() -> bool:

	# reset the grid
	grid_path.reset_grid(-1)

	var coor: Vector2i = grid_path.world_to_grid(get_pathfinding_world_position())
	if not grid_path.is_in_bounds(coor):
		push_warning("CompPathfindingAstar: goblin grid cell out of bounds: %s" % coor)
		return false

	var set_cell := grid_path.set_cell(coor, 0)
	if set_cell == false:
		return false

	# Read the index instead of popping
	var check_queue: Array[Vector2i] = [coor]
	var queue_read_idx: int = 0

	# do the forward propagation
	while queue_read_idx < check_queue.size():
		var check_coor: Vector2i = check_queue[queue_read_idx]
		queue_read_idx += 1
		var check_cost = grid_path.get_cell(check_coor)

		var borders = grid_path.get_border_coordinates(check_coor, grid_path.BORDER_COOR_ALL)

		for b_coor in borders:

			# Check if this is a diagonal thing. If so, we add a little extra cost
			var dist = abs(check_coor.x - b_coor.x) + abs(check_coor.y - b_coor.y)
			var add_cost := 0.0
			if dist > 1:
				add_cost = additional_diagonal_cost

			var b_current_cost = grid_path.get_cell(b_coor)
			var b_cost_to_get_there = grid_cost.get_cell(b_coor)

			if b_cost_to_get_there != null:
				var new_cost = check_cost + b_cost_to_get_there + add_cost

				if b_current_cost == -1:
					grid_path.set_cell(b_coor, new_cost)
					check_queue.append(b_coor)
				elif new_cost < b_current_cost:
					grid_path.set_cell(b_coor, new_cost)
					check_queue.append(b_coor)

	# we successfully did it
	return true
#endregion


#region backward propagation
func backward_propagation(goal_coor: Vector2i) -> void:
	
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


	# check if the next coordinate is closer than the first
	if path_coor.size() > 1:
		var first_coor = path_coor.get(0)
		var second_coor = path_coor.get(1)
		
		var first_dist = first_coor.distance_to(global_position)
		var first_to_second_dist = first_coor.distance_to(second_coor)
		var second_dist = second_coor.distance_to(global_position)
		
		if second_dist < first_dist + first_to_second_dist:
			path_cell.pop_front()
			path_cost.pop_front()
			path_coor.pop_front()


#endregion






#region : Drawing Helpers
func _draw() -> void:
	if not _grid_initialized:
		return

	if draw_astar_enabled and grid_cost != null and grid_path != null:
		draw_grid_cost(grid_cost)
		draw_grid_path_values(grid_path)
		draw_path_coor()
	if draw_los_enabled:
		draw_los()


func draw_los() -> void:
	
	if draw_los_enabled:
	
		# check if player exists
		var player_node = null
		var player_nodes = General.nodes_in_group(self, "player")
		if player_nodes.size()>0:
			player_node = player_nodes.get(0)
		else:
			return

		# LOS checks use world-space AABBs (see General._blocked_by_LOS).
		var player_world: Vector2 = player_node.global_position
		var enemy_world: Vector2 = get_pathfinding_world_position()
		var blocked = General._blocked_by_LOS(
			self,
			enemy_world.x,
			enemy_world.y,
			player_world.x,
			player_world.y,
			blocking_elements_groups_los
		)

		var color = Color.GREEN
		if blocked:
			color = Color.RED

		# _draw() expects local coordinates (same as draw_path_coor).
		draw_line(
			Vector2.ZERO,
			to_local(player_world),
			color,
			path_line_width
		)



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
	if target_grid == null:
		return

	var csz: Vector2 = target_grid.cellSize
	if csz.x <= 0.0 or csz.y <= 0.0:
		return

	var alpha := 0.4
	var world_tl: Vector2 = target_grid.topLeft

	for x in range(target_grid.grid_width_cells):
		for y in range(target_grid.grid_height_cells):
			var val = target_grid.get_cell(Vector2i(x, y))
			if val == null:
				continue

			var color: Color = grid_color_available
			if is_inf(val):
				color = grid_color_blocked
			elif val > 1:
				color = grid_color_expensive

			color.a = alpha

			var world_corner := Vector2(
				world_tl.x + x * csz.x,
				world_tl.y + y * csz.y
			)
			draw_rect(Rect2(to_local(world_corner), csz), color, true)

	var width_px := target_grid.grid_width_cells * csz.x
	var height_px := target_grid.grid_height_cells * csz.y

	# Vertical lines
	for x in range(target_grid.grid_width_cells + 1):
		var world_x := world_tl.x + x * csz.x
		draw_line(
			to_local(Vector2(world_x, world_tl.y)),
			to_local(Vector2(world_x, world_tl.y + height_px)),
			target_grid.grid_color,
			target_grid.grid_line_width
		)

	# Horizontal lines
	for y in range(target_grid.grid_height_cells + 1):
		var world_y := world_tl.y + y * csz.y
		draw_line(
			to_local(Vector2(world_tl.x, world_y)),
			to_local(Vector2(world_tl.x + width_px, world_y)),
			target_grid.grid_color,
			target_grid.grid_line_width
		)

func draw_grid_path_values(target_grid: Grid) -> void:
	if target_grid == null:
		return

	if target_grid.cellSize.x <= 0.0 or target_grid.cellSize.y <= 0.0:
		return

	var font: Font = ThemeDB.fallback_font
	if font == null:
		return

	for x in range(target_grid.grid_width_cells):
		for y in range(target_grid.grid_height_cells):
			var coor := Vector2i(x, y)
			var val = target_grid.get_cell(coor)
			if val == null:
				continue
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
