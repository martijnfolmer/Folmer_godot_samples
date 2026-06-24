extends Node2D

"""
Small sample of what it looks like to simulate lines and cloth using verlet integration, using 2 classes located in scripts/classes/class_verlet_cloth and /class_verlet_line
"""

var line_fixed_middle : verlet_line
var line_fixed_both_ends : verlet_line
var cloth_washline : verlet_cloth
var cloth_two_points_top : verlet_cloth
var prev_mouse_position : Vector2

func _ready() -> void:
	
	# Verlet line with a part fixed
	line_fixed_middle = verlet_line.new(30, Vector2(100, 100), Vector2(1000, 100), [0, 10])
	
	# Verlet line with both ends fixed
	line_fixed_both_ends = verlet_line.new(10, Vector2(-1000, 100), Vector2(-300, 100), [0, 10])
	
	
	# Verlet cloth : washline (all points at the top
	var cloth_width: int = 15
	var cloth_height: int = 15
	var cloth_spacing: float = 20.0
	var cloth_start_pos := Vector2(-1000, -500)
	
	# We want the top row of the cloth to be fixed in the air so it hangs down
	var fixed_cloth_points: Array[Vector2i] = []
	for x in range(cloth_width):
		fixed_cloth_points.append(Vector2i(x, 0)) # Y = 0 represents the top row
	# Instantiate the cloth
	cloth_washline = verlet_cloth.new(cloth_width, cloth_height, cloth_start_pos, cloth_spacing, fixed_cloth_points)
	
	
	# verlet cloth : single point (middle point fixed)
	cloth_start_pos = Vector2(0, -500)
	
	# We want the top row of the cloth to be fixed in the air so it hangs down
	fixed_cloth_points = []
	fixed_cloth_points.append(Vector2i(2, 0)) 
	fixed_cloth_points.append(Vector2i(9, 0)) 
	fixed_cloth_points.append(Vector2i(14, 14))
	# Instantiate the cloth
	cloth_two_points_top = verlet_cloth.new(cloth_width, cloth_height, cloth_start_pos, cloth_spacing, fixed_cloth_points)
	
	prev_mouse_position = get_global_mouse_position()


# Update the lines and cloths, buy moving one of its endpoints
func _process(delta: float) -> void:
	
	var cur_mouse_position = get_global_mouse_position()
	var velocity_mouse = cur_mouse_position - prev_mouse_position
	
	_update_verlet_object(delta, line_fixed_middle, velocity_mouse)
	_update_verlet_object(delta, line_fixed_both_ends, velocity_mouse)
	_update_verlet_object(delta, cloth_two_points_top, velocity_mouse)
	_update_verlet_object(delta, cloth_washline, velocity_mouse)
	
	prev_mouse_position = cur_mouse_position
	
	queue_redraw()

func _update_verlet_object(delta, verlet_object, velocity_mouse) -> void:
	if verlet_object != null:
		verlet_object._update(delta)
		# move one corner of the cloth
		var p_end = verlet_object.all_points.get(len(verlet_object.all_points)-1)
		p_end["cur_pos"] += velocity_mouse

# verlet 
func _draw() -> void:
	_draw_line(line_fixed_both_ends)
	_draw_line(line_fixed_middle)
	_draw_cloth(cloth_two_points_top)
	_draw_cloth(cloth_washline)


func _draw_line(line : verlet_line) -> void:
	if line != null and not line.all_points.is_empty():
		var points_to_draw := PackedVector2Array()
		for point in line.all_points:
			points_to_draw.append(point["cur_pos"])
		
		# Draw the line segments connecting the points and red dots inbetween them
		draw_polyline(points_to_draw, Color.WHITE, 2.0)
		for pos in points_to_draw:
			draw_circle(pos, 3.0, Color.RED)
			

func _draw_cloth(cloth : verlet_cloth) -> void:
	if cloth != null and not cloth.all_points.is_empty():
		for y in range(cloth.grid_height):
			for x in range(cloth.grid_width):
				var current_idx: int = cloth._get_index(x, y)
				var current_pos: Vector2 = cloth.all_points[current_idx]["cur_pos"]
				
				if x < cloth.grid_width - 1:
					var right_idx: int = cloth._get_index(x + 1, y)
					var right_pos: Vector2 = cloth.all_points[right_idx]["cur_pos"]
					draw_line(current_pos, right_pos, Color.LIGHT_BLUE, 1.5)
					
				if y < cloth.grid_height - 1:
					var bottom_idx: int = cloth._get_index(x, y + 1)
					var bottom_pos: Vector2 = cloth.all_points[bottom_idx]["cur_pos"]
					draw_line(current_pos, bottom_pos, Color.LIGHT_BLUE, 1.5)
					
				draw_circle(current_pos, 2.0, Color.YELLOW)
