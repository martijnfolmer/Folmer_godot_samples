class_name collisions

"""
	Any functions in which we calculate collisions and such
"""


# find out if collision collides in a line (true means collision, false means no collision)
static func does_line_collide(source_Node : Node2D, p1 : Vector2, p2 : Vector2) -> bool:
	var space_state = source_Node.get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(p1, p2)
	query.collide_with_areas = true
	query.hit_from_inside = true
	var result : Dictionary = space_state.intersect_ray(query)
	return not result.is_empty()


# Find out if a point is inside of any collision point (true means collision, false means no collision)
static func does_point_collide(source_Node : Node2D, p1 : Vector2) -> bool:
	var space_state = source_Node.get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = p1
	query.collide_with_areas = true
	var results = space_state.intersect_point(query)
	return results.size() > 0
