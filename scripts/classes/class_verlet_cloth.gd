class_name verlet_cloth

'''
This is the code to simulate a cloth using verlet integration

		Example of initialization of the cloth
			var cloth_width: int = 15                 # number of segments in width
			var cloth_height: int = 15				  # number of segments in height
			var cloth_spacing: float = 20.0			  # size of the segments
			var cloth_start_pos := Vector2(100, 200)  # top left position
			
			# Add fixed points (which don't move)
			var fixed_cloth_points: Array[Vector2i] = []
			for x in range(cloth_width):
				fixed_cloth_points.append(Vector2i(x, 0)) # Y = 0 represents the top row
				
			# Instantiate the cloth
			cloth = verlet_cloth.new(cloth_width, cloth_height, cloth_start_pos, cloth_spacing, fixed_cloth_points)
		
		Example of running the cloth
			cloth._update(delta) # run each frame that you want to update the cloth
			
			# move one corner of the cloth with a velocity
			var p_end = cloth.all_points.get(len(cloth.all_points)-1)
			p_end["cur_pos"] += velocity

	all_points consists of (grid_width * grid_height) points, which are connected by their North,
	East, South and West neighbours.
	
	Each point is defined by a dictionary
	point : dictionary = {
		"cur_pos" : Vector2, # current position of the point
		"prev_pos" : Vector2, # previous position of the point
		"fixed" : bool        # if it is influenced by constraints or gravity
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

var all_points: Array[Dictionary] = [] # Contains dictionary with cur_pos, prev_pos and if the point is fixed
var grid_width: int = 0
var grid_height: int = 0
var segment_length: float = 0.0 # desired length of each line segment (spacing)

## Initialize the cloth grid
func _init(_width_points: int, _height_points: int, _top_left_loc: Vector2, _segment_spacing: float, _fixed_points_coords: Array[Vector2i]) -> void:
	grid_width = _width_points
	grid_height = _height_points
	segment_length = _segment_spacing
	all_points = _get_starting_points(_width_points, _height_points, _top_left_loc, _segment_spacing, _fixed_points_coords)

## Generate the initial grid of points
func _get_starting_points(_width: int, _height: int, _top_left: Vector2, _spacing: float, _fixed_coords: Array[Vector2i]) -> Array[Dictionary]:
	var generated_points: Array[Dictionary] = []
	for y in range(_height):
		for x in range(_width):
			var currentPosition := _top_left + Vector2(x * _spacing, y * _spacing)
			var is_fixed: bool = Vector2i(x, y) in _fixed_coords
			
			generated_points.append({
				"cur_pos": currentPosition,
				"prev_pos": currentPosition,
				"fixed": is_fixed
			})
			
	return generated_points

## 2D coordinates to a 1D index, so we know where it is in all_points
func _get_index(x: int, y: int) -> int:
	return x + y * grid_width

## Updates points and constraints line segments by original width and height
func _update(delta: float) -> void:
	for idx in range(all_points.size()):
		var point: Dictionary = all_points[idx]
		if point["fixed"]:
			continue
		
		var prev_pos: Vector2 = point["prev_pos"]
		var cur_pos: Vector2 = point["cur_pos"]
		
		var velocity: Vector2 = (cur_pos - prev_pos) * dampening
		var acceleration: Vector2 = Vector2.DOWN * gravity * delta
		
		point["cur_pos"] = cur_pos + velocity + acceleration
		point["prev_pos"] = cur_pos 
	
	for idx in range(num_constraints):
		# Horizontal constraints (left to right)
		for y in range(grid_height):
			for x in range(grid_width - 1):
				var p1: Dictionary = all_points[_get_index(x, y)]
				var p2: Dictionary = all_points[_get_index(x + 1, y)]
				_resolve_link(p1, p2)
				
		# Vertical constraints (top to bottom)
		for y in range(grid_height - 1):
			for x in range(grid_width):
				var p1: Dictionary = all_points[_get_index(x, y)]
				var p2: Dictionary = all_points[_get_index(x, y + 1)]
				_resolve_link(p1, p2)

## Try to return towards original line segment
func _resolve_link(p1: Dictionary, p2: Dictionary) -> void:
	if p1["fixed"] and p2["fixed"]: # both ends are fixed, skip
		return
	
	var dist_points: float = p1["cur_pos"].distance_to(p2["cur_pos"]) 
	if dist_points == 0.0: # Prevent divide by zero
		return 
		
	var line_diff: float = segment_length - dist_points
	var percent: float = line_diff / dist_points
	var point_diff: Vector2 = p2["cur_pos"] - p1["cur_pos"]
	var offset: Vector2 = point_diff * percent
	
	# Split the offset based on which points are allowed to move
	if not p1["fixed"] and not p2["fixed"]:
		p1["cur_pos"] -= offset * 0.5
		p2["cur_pos"] += offset * 0.5
	elif not p1["fixed"]:
		p1["cur_pos"] -= offset # Takes the full offset, because other side is fixed
	elif not p2["fixed"]:
		p2["cur_pos"] += offset # Takes the full offset, because other side is fixed
