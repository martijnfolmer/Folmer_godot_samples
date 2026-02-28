extends Node2D


# TESTING:
func _unhandled_input(event: InputEvent) -> void:
	if _is_space_pressed(event):
		$CompDamage.take_damage(5)


func _is_space_pressed(event: InputEvent) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE
