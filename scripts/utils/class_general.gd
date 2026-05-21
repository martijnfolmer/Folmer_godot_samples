# res://scripts/utils/class_general.gd
class_name General

"""
	All general functions that we want to reuse
	
"""

## Line of sight collision
static func _blocked_by_LOS(node: Node, x1 : float, y1: float, x2 : float, y2 : float, groups: Array[StringName]) -> bool:
	
	var all_nodes = nodes_in_groups(node, groups, true)
	if all_nodes.size()==0:
		return false
	
	# for each node, find out if it has a collision with the line
	var seen: Dictionary = {}
	for n in all_nodes:
		
		# check if we have already seen the node, needed if objects have more than 1 group
		if seen.has(n):
			continue
		seen[n] = true
		
		# check for collisionshapes
		for child in n.find_children("*", "CollisionShape2D", true, false):
			var rect = collision_shape_world_aabb(child as CollisionShape2D)
			if Geom2Util.line_intersects_rect(x1, y1, x2, y2, rect):
				return true
			
		## check for collisionpolygons
		for child in n.find_children("*", "CollisionPolygon2D", true, false):
			var rect = collision_polygon_world_aabb(child as CollisionPolygon2D)
			if Geom2Util.line_intersects_rect(x1, y1, x2, y2, rect):
				return true
	#
	return false


## Turns a collisionShape into a rectangle we can use for collision checking (rect2 = pos, size)
static func collision_shape_world_aabb(cs: CollisionShape2D) -> Rect2:
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

## Turns a CollisionPolygon2D into a rectangle we can use for collision checking (rect2 = pos, size)
static func collision_polygon_world_aabb(cp: CollisionPolygon2D) -> Rect2:
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


## Get all nodes in the current tree of this node that belong to a certain group
static func nodes_in_group(node: Node, group: StringName, exclude_self: bool = false) -> Array[Node]:
	var allNodes = node.get_tree().get_nodes_in_group(group)
	
	# Don't pass ourself away if we are excluding self
	if exclude_self:
		var nodesAdd = []
		for nodec in allNodes:
			if nodec != node and nodec.get_parent()!= node:
				nodesAdd.append(nodec)
		allNodes = nodesAdd
	
	return allNodes

## Return all nodes in the scene that the node belongs to, that belong to at least one group as
## defined in the group array. Each node is returned at most once even if it belongs to multiple groups.
static func nodes_in_groups(node: Node, groups: Array[StringName], exclude_self: bool = false) -> Array[Node]:
	var all_nodes: Array[Node] = []
	var seen: Dictionary = {}
	for group in groups:
		for nodeCur in node.get_tree().get_nodes_in_group(group):
			if seen.has(nodeCur):
				continue
			if exclude_self and (nodeCur == node or nodeCur == node.get_parent()):
				continue
			seen[nodeCur] = true
			all_nodes.append(nodeCur)
	return all_nodes


## Return true when node or any of their ancestor belongs to the given group.
static func _node_or_ancestor_in_group(node: Node, group: StringName) -> bool:
	var current: Node = node
	while current != null:
		if current.is_in_group(group):
			return true
		current = current.get_parent()
	return false


## Return true when node or any of their ancestor belongs to the given group
static func _node_or_ancestor_in_groups(node: Node, group_list: Array[StringName]) -> bool:
	var current: Node = node
	while current != null:
		for group in group_list:
			if current.is_in_group(group):
				return true
		current = current.get_parent()
	return false
	
## return all nodes that start with a given name
static func get_nodes_with_base_name(node: Node, base_name: String) -> Array[Node]:
	var matches: Array[Node] = []

	for nodec in node.get_tree().current_scene.find_children("*", "", true, false):
		if nodec.name.begins_with(base_name):
			matches.append(nodec)

	return matches
	
## return the minimum value of an array
static func get_min_arr(arr: Array):
	var index = get_min_index_arr(arr)
	if index>=0 and index<arr.size():
		return arr[index]
	return null


## return the index of the minimum value of an array
static func get_min_index_arr(arr: Array) -> int:
	if arr.is_empty():
		return -1

	var min_index := 0

	for i in range(1, arr.size()):
		if arr[i] < arr[min_index]:
			min_index = i

	return min_index

## return the maximum value of the array
static func get_max_arr(arr: Array):
	var index = get_max_index_arr(arr)
	if index>=0 and index<arr.size():
		return arr[index]
	return null

static func get_max_index_arr(arr: Array) -> int:
	if arr.is_empty():
		return -1

	var max_index := 0

	for i in range(1, arr.size()):
		if arr[i] < arr[max_index]:
			max_index = i

	return max_index
