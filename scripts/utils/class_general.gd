# res://scripts/utils/class_general.gd
class_name General

"""
	All general functions that we want to reuse
"""


# Get all nodes in the current tree of this node that belong to a certain group
static func _nodes_in_group(node: Node, group: StringName) -> Array[Node]:
	return node.get_tree().get_nodes_in_group(group)

## Return all nodes in the scene that the node belongs to, that belong to at least one group as 
## defined in the group array
static func _nodes_in_groups(node: Node, groups: Array[StringName]) -> Array[Node]:
	var all_nodes: Array[Node] = []
	for group in groups:
		var NodeArray = _nodes_in_group(node, group)
		for nodeCur in NodeArray:
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
