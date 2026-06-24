class_name verlet_line


'''
	This is the line/rope verlet intergration class:
		
		Initialization example:
			line = verlet_line.new(30, Vector2(100, 100), Vector2(1000, 100), [0, 10])
			
		Running example:
			line._update(delta)
			
			# Move one of the points of the line with a certain velocity
			var p_end = line.all_points.get(len(line.all_points)-1)
			p_end["cur_pos"] += velocity
	
	all_points consists of (number_of_line_segments + 1) points, first point is _start_loc, last 
	point is _end_loc, equidistant
	
	point : dictionary = {
		"cur_pos" : Vector2, # current position of the point
		"prev_pos" : Vector2, # previous position of the point
		"fixed" : bool, # if this point is fixed in place or not
	}
	

	Things to add:
		- Collisions for each point with the environment and eachother optionally
		- Connect objects to the end of the rope
		
'''

## gravity constant, pulls in the positive y direction
@export var gravity: float = 98 
## how much velocity slows down due to friction between frames	
@export var dampening: float = 0.9 	
## how often to run the constraints each frame. Rule of thumb = more = more accurate but more computationally expensive
@export var num_constraints: int = 5 

var all_points : Array[Dictionary] = [] # Contains dictionary with cur_pos, prev_pos and if the point is fixed
var segment_length: float = 0.0 # desired length of each line segment

func _init(_number_of_line_segments : int, _start_loc : Vector2, _end_loc : Vector2, _idx_points_fixed : Array[int]) -> void:
	all_points = _get_starting_points(_number_of_line_segments, _start_loc, _end_loc, _idx_points_fixed) # Get the initial locations of each point
	segment_length = _start_loc.distance_to(_end_loc)/_number_of_line_segments

func _get_starting_points(_number_of_line_segments : int, _start_loc : Vector2, _end_loc : Vector2, _idx_points_fixed : Array[int]) -> Array[Dictionary]:
	var all_interpolated_points : Array[Dictionary] = []
	for i in range(_number_of_line_segments):
		var currentPosition = _start_loc.lerp(_end_loc, float(i)/_number_of_line_segments)
		var fixed = true if i in _idx_points_fixed else false
		
		all_interpolated_points.append({
			"cur_pos" = currentPosition,
			"prev_pos" = currentPosition,
			"fixed" = fixed
		})
	all_interpolated_points.append({
		"cur_pos" = _end_loc,
		"prev_pos" = _end_loc,
		"fixed" = _number_of_line_segments in _idx_points_fixed
	})
	
	return all_interpolated_points

## Update points based on gravity and previous positions, then execute constraints
func _update(delta : float) -> void:
	# update points
	for idx in range(len(all_points)):
		var point : Dictionary = all_points[idx]
		if point["fixed"]:
			continue
		
		var prev_pos : Vector2 = point["prev_pos"]
		var cur_pos : Vector2 = point["cur_pos"]
		
		var velocity : Vector2 = (cur_pos - prev_pos) * dampening
		var acceleration : Vector2 = Vector2.DOWN * gravity * delta
		
		point["cur_pos"] = cur_pos + velocity + acceleration
		point["prev_pos"] = cur_pos 
	
	# run the constraints on the updated points
	for constraint_idx in range(num_constraints):
		for idx in range(len(all_points)-1):
			var p1 : Dictionary = all_points[idx]
			var p2 : Dictionary = all_points[idx + 1]
			
			if p1["fixed"] and p2["fixed"]: # both ends of this segement are fixed, so doesn't get updated
				continue
			
			var dist_points : float = p1["cur_pos"].distance_to(p2["cur_pos"]) # distance between two points at end of line segment
			if dist_points == 0.0:
				continue 
				
			var line_diff : float = segment_length - dist_points
			var percent : float = line_diff / dist_points
			var point_diff : Vector2 = p2["cur_pos"] - p1["cur_pos"]
			var offset : Vector2 = point_diff * percent
			
			# Split based on which points can move
			if not p1["fixed"] and not p2["fixed"]:
				p1["cur_pos"] -= offset * 0.5
				p2["cur_pos"] += offset * 0.5
			elif not p1["fixed"]:
				p1["cur_pos"] -= offset # Takes the full offset, other side is fixed
			elif not p2["fixed"]:
				p2["cur_pos"] += offset # Takes the full offset, other side is fixed
