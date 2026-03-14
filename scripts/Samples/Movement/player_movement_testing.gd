extends Node2D

@export_group("Pillar crush test")
@export var pillar_test_force: float = 1000.0

# Input
## Handle debug input and trigger the pillar push test.
func _unhandled_input(event: InputEvent) -> void:
	if _is_space_pressed(event):
		_move_two_closest_pillars_towards_player()

## Return true when the key event is a non-repeated Space press.
func _is_space_pressed(event: InputEvent) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE

# Debug action
## Push the two nearest pillars toward the player using kickback impact.
func _move_two_closest_pillars_towards_player() -> void:
	# Resolve the player used as the attraction point.
	var player := $movement_WASD as CharacterBody2D
	if player == null:
		return

	# Gather candidate pillars from the scene.
	var pillars: Array[Node] = get_tree().get_nodes_in_group("pillar")
	if pillars.is_empty():
		return

	# Keep only Node2D pillars so we can sort by position.
	var sortable: Array[Node2D] = []
	for node in pillars:
		if node is Node2D:
			sortable.append(node)

	if sortable.is_empty():
		return

	# Sort pillars by distance to the player.
	var player_pos: Vector2 = player.global_position
	sortable.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(player_pos) < b.global_position.distance_squared_to(player_pos)
	)

	# Apply impact to at most two nearest pillars.
	var count: int = min(2, sortable.size())
	for i in count:
		var pillar: Node2D = sortable[i]
		var kickback: Node = pillar.get_node_or_null("CompBodyKickback")
		if kickback == null:
			continue
		var ang: float = (player_pos - pillar.global_position).angle()
		kickback.call("impact", pillar_test_force, ang)
