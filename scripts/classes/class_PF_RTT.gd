class_name RTT


"""
	This is the class that performs the Rapidly exploring random tree (RTT), a pathfinding algo that
	is particularly usefull if you have irregular shapes that cause collision and don't fit around
	an aligned grid. 
	
	The RTT algo can be altered to take kinodynamics into account (meaning restrictions on how fast
	a path can turn). In order to do that, you need to add further restrictions when closest point
	is found, so it also checks if turning circle is valid
	
	This works by checking collisions between randomly found points using collision shapes, 
	and not planning any paths that collide with them
	
	The resulting path will be a little uneven, I'll add RTT* later, which is a variant of 
	RTT that improves the path shape and finds (theoretically) the shortest path
	
	Point list that we pass on has the following shape
	point_list = [{
		point : Vector2,
		prev_point_idx : int
	}]
	
	# meaning the initial point list that we pass on must have the following values
	point_list = [{
		point : startLoc,
		prev_point_idx : -1
	}]
	
"""
static func PF_RTT(source_node : Node2D, point_list : Array[Dictionary], endLoc : Vector2, field : Rect2, step_distance : int = 100, numberOfPoints = 10) -> Array[Dictionary]:
	
	# check if point_list is bigger than 0
	if len(point_list) == 0:
		push_error("ERROR : the tree is empty, we require a start location")
		return []
		
	# get all individual points of our point_list
	var allGlobalPoints : Array[Vector2] = []
	for point in point_list:
		allGlobalPoints.append(point["point"])
	
	# Add points
	for i in range(numberOfPoints):
		
		# find a random point inside of the field
		var p1 : Vector2 = _find_next_point(source_node, field)
		
		# find the closest point to this point in the existing point list
		var idx : int = array.closest_val(p1, allGlobalPoints)
		var closest_point : Vector2 = allGlobalPoints[idx]
		
		# get the new point that is step_distance away from the closest point, in direction of p1
		var p2 = _point_step(closest_point, p1, step_distance)
		
		var does_line_collide = collisions.does_line_collide(source_node, closest_point, p2)
		
		if not does_line_collide:
			point_list.append({
				"point" : p2,
				"prev_point_idx" : idx,
			})
	
	# Try to find the last point
	var idx : int = array.closest_val(endLoc, allGlobalPoints)
	var distToEnd = endLoc.distance_to(allGlobalPoints[idx])
	var p2 = _point_step(allGlobalPoints[idx], endLoc, step_distance)
	if distToEnd <= step_distance:
		p2 = endLoc
	var does_line_collide = collisions.does_line_collide(source_node, allGlobalPoints[idx], p2)
	if not does_line_collide :
		point_list.append({
			"point" : p2,
			"prev_point_idx" : idx
		})
	
	return point_list
	
	
## return a point that is dist away from p1, with direction from p1 to p2
static func _point_step(p1 : Vector2, p2: Vector2, Dist : float) -> Vector2:
	var ang = p1.direction_to(p2)
	return p1 + ang * Dist
	

## Get a random point within the field
static func _find_next_point(source_node : Node2D, field_coordinates : Rect2) -> Vector2:
	
	var kn : int = 0
	while kn<1000:
		var pos : Vector2 = field_coordinates.position
		var size : Vector2 = field_coordinates.size
		
		var xloc : float = randf_range(pos.x, pos.x + size.x)
		var yloc : float = randf_range(pos.y, pos.y + size.y)
		
		var does_it_collide =collisions.does_point_collide(source_node, Vector2(xloc, yloc))
		if not does_it_collide:
			return Vector2(xloc, yloc)
		
		kn +=1
	
	# if we reach here, it means that we were not able to find a point that doesn't collide
	# with a collision object, so we couldn't get a random point
	return Vector2.ZERO
