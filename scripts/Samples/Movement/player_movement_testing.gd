extends Node2D

@export var kick_force : float = 100
@export var kick_radius : float = 600


## Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
	#pass

# TODO: kickback explosion
func _unhandled_input(event: InputEvent) -> void:
	if _is_space_pressed(event):
		var pillars := get_tree().get_nodes_in_group("pillar")
		for pillar in pillars:

			# apply force to pillars based on their distance
			var distance = pillar.global_position.distance_to($movement_WASD.global_position)
			if distance< kick_radius:
				var ang = (pillar.global_position - $movement_WASD.global_position).angle()
				pillar.get_node("CompDamage").take_damage(1)
				pillar.get_node("CompBodyKickback").impact(kick_force * (1.0 - distance / kick_radius), ang)


func _is_space_pressed(event: InputEvent) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE
