class_name array

"""
	Any extra functions we want to do with Arrays
"""

## Find the closest value to point, from a Array filled with points
static func closest_val(point : Vector2, points : Array[Vector2]) -> int:
	
	if len(points) == 0:
		push_error("ERROR : the points array that was passed on is empty")
		return 0
	
	var closest_idx : int = 0
	var closest_dist : float = point.distance_to(points[closest_idx])
	for idx in range(2, len(points)):
		var check_dist : float = point.distance_to(points[idx])
		if check_dist < closest_dist:
			closest_idx = idx
			closest_dist = check_dist
	
	return closest_idx
