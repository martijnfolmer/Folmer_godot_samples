extends Node2D
"""
	This is the sample scene for RTT algorithm, a pathfinding algo usefull for dealing with 
	random collision shapes.
	
	Use left mouse button to set the end location, where we want to go to
	Use right mouse button to set the start location, where we want to start from
	Press spacebar to do a single step of the algorithm
	
	TODO:
		- take into account kinodynamic restrictions in terms of turning circle and speed
		- RTT*
		- bidirectional RTT
"""

var start_loc: Vector2 = Vector2(100, 100)   # Starting location
var end_loc: Vector2 = Vector2(600, 400)     # Ending location
var point_list: Array[Dictionary] = []		# The tree of points, consists of dictionaries containing {point : Vector2, prev_point_idx : int}
var field: Rect2							# The bounding box of where we want to find the path
var final_path: PackedVector2Array = PackedVector2Array() # final path once we found a way to reach the end

func _ready() -> void:
	# Set the bounding box for the algorithm to the screen size
	field = get_viewport_rect()
	
	# Initialize the RRT tree with the starting point
	_reset_tree()

func _unhandled_input(event: InputEvent) -> void:
	# Update end_loc on Left Mouse Click
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		end_loc = get_global_mouse_position()
		_reset_tree() 
		queue_redraw()
	
	# Update start_loc on Right Mouse Click
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		start_loc = get_global_mouse_position()
		_reset_tree() 
		queue_redraw() 
	
	# Grow the tree on Spacebar press
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_grow_tree()

## Start with a completely new tree
func _reset_tree() -> void:
	point_list.clear()
	final_path.clear()
	
	point_list.append({
		"point": start_loc,
		"prev_point_idx": -1
	})
	queue_redraw()

## perform a single step of the algorithm
func _grow_tree() -> void:
	
	# Check if we are done
	if not final_path.is_empty():
		return

	# Call the RTT class for a single step
	point_list = RTT.PF_RTT(self, point_list, end_loc, field, 50, 10)
	
	# Check if the newest points have reached the end_loc
	var target_idx: int = -1
	for i in range(point_list.size() - 1, -1, -1):
		if point_list[i]["point"].distance_to(end_loc) < 1.0:
			target_idx = i
			break
			
	# If we found the target, backtrack to build the final path array
	if target_idx != -1:
		_build_final_path(target_idx)
		
	queue_redraw()

## if we have found the end location, we build the ending path
func _build_final_path(end_index: int) -> void:
	final_path.clear()
	var current_idx: int = end_index
	
	# Loop backwards using the parent index until we hit the start node (-1)
	while current_idx != -1:
		final_path.append(point_list[current_idx]["point"])
		current_idx = point_list[current_idx]["prev_point_idx"]

# Visualisations
func _draw() -> void:
	# Draw the target destination (Red Circle)
	draw_circle(end_loc, 10.0, Color.RED)
	
	# Loop through the point list to draw the tree
	for i in range(point_list.size()):
		var current_node = point_list[i]
		var current_pos = current_node["point"]
		var prev_idx = current_node["prev_point_idx"]
		
		# Draw the connection line to the parent point
		if prev_idx != -1:
			var prev_pos = point_list[prev_idx]["point"]
			draw_line(current_pos, prev_pos, Color.AQUA, 2.0)
			
		# Draw the point itself (Start point is Green, generated points are White)
		var point_color = Color.GREEN if i == 0 else Color.WHITE
		var point_radius = 6.0 if i == 0 else 3.0
		draw_circle(current_pos, point_radius, point_color)
		
	# Draw the final green path on top of everything else if it exists, meaning we foudn a path
	if final_path.size() > 1:
		draw_polyline(final_path, Color.GREEN, 4.0, true)
