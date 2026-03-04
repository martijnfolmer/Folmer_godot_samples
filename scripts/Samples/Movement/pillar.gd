extends Node2D


func _ready():
	add_to_group("pillar")


## TESTING:
#func _unhandled_input(event: InputEvent) -> void:
	#if _is_space_pressed(event):
		#$CompDamage.take_damage(1)
		#$CompBodyKickback.impact(10, 0)
#
#
#func _is_space_pressed(event: InputEvent) -> bool:
	#return event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE
