extends Node

"""
	Check if we are in collision with the cells (meaning, we are standing over them)
	
	Uses physics collision to check. Queries only the floor_cell physics layer
"""

signal on_cell_state_changed(is_on_cell: bool, area: Area2D)

@export var body_path: NodePath = NodePath("../CharacterBody2D") # our characterbody2d
@export var sprite_path: NodePath = NodePath("../CharacterBody2D/Sprite2D") # the sprite
@export_flags_2d_physics var floor_collision_mask: int = 2
@export var poll_in_physics: bool = true		# either poll in physics, or in normal process
@export var debug_print_changes: bool = false

var is_on_cell: bool = false
var current_cell_area: Area2D = null

var _body: CollisionObject2D = null
var _sprite: Sprite2D = null


func _ready() -> void:
	_body = get_node_or_null(body_path) as CollisionObject2D		# get our collision
	_sprite = get_node_or_null(sprite_path) as Sprite2D
	_refresh_overlap_state()


func _physics_process(_delta: float) -> void:
	if poll_in_physics:
		_refresh_overlap_state()
		_rotate_when_not_on_cell_area()

func _process(_delta: float) -> void:
	if !poll_in_physics:
		_refresh_overlap_state()
		_rotate_when_not_on_cell_area()

## check if we are overlapping or not
func _refresh_overlap_state() -> void:
	var overlap_area := _find_overlapping_cell_area()
	var next_is_on_cell: bool = overlap_area != null
	var changed: bool = next_is_on_cell != is_on_cell or overlap_area != current_cell_area

	if !changed:
		return

	is_on_cell = next_is_on_cell
	current_cell_area = overlap_area
	on_cell_state_changed.emit(is_on_cell, current_cell_area)

	if debug_print_changes:
		print(name, " on_cell=", is_on_cell, " area=", current_cell_area)


func _rotate_when_not_on_cell_area():
	if !is_on_cell : 
		_sprite.rotation += 0.1
		_sprite.scale.x = move_toward(_sprite.scale.x, 0.0, 0.01);
		_sprite.scale.y = move_toward(_sprite.scale.y, 0.0, 0.01);
		if _sprite.scale.x <= 0.01:
			var damage := get_parent().get_node_or_null("CompDamage")
			if damage != null and damage.has_method("_instance_destroy"):
				damage._instance_destroy(false)

## Check if we are hitting the 
func _find_overlapping_cell_area() -> Area2D:
	if _body == null or !is_instance_valid(_body):
		return null

	if floor_collision_mask == 0:
		return null

	var world := _body.get_world_2d()
	if world == null:
		return null

	var space_state := world.direct_space_state
	for owner_id in _body.get_shape_owners():
		if _body.is_shape_owner_disabled(owner_id):
			continue

		var owner_transform: Transform2D = _body.shape_owner_get_transform(owner_id)
		var shape_count: int = _body.shape_owner_get_shape_count(owner_id)

		for shape_idx in range(shape_count):
			var shape: Shape2D = _body.shape_owner_get_shape(owner_id, shape_idx)
			if shape == null:
				continue

			var query := PhysicsShapeQueryParameters2D.new()
			query.shape = shape
			query.transform = _body.global_transform * owner_transform
			query.collide_with_areas = true
			query.collide_with_bodies = false
			query.exclude = [_body.get_rid()]
			query.collision_mask = floor_collision_mask

			var hits := space_state.intersect_shape(query, 1)
			for hit in hits:
				var collider = hit.get("collider")
				if collider is Area2D and _is_cell_area(collider):
					return collider

	return null


func _is_cell_area(area: Area2D) -> bool:
	return _node_or_ancestor_in_group(area, "cell_floor") != null


func _node_or_ancestor_in_group(node: Node, group_name: StringName) -> Node:
	var current: Node = node
	while current != null:
		if current.is_in_group(group_name):
			return current
		current = current.get_parent()
	return null
