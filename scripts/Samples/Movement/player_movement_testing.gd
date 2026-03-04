extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _unhandled_input(event: InputEvent) -> void:
	if _is_space_pressed(event):
		print("Pillar")
		var pillars := get_tree().get_nodes_in_group("pillar")
		for pillar in pillars:
			pillar.get_node("CompDamage").take_damage(1)
			pillar.get_node("CompBodyKickback").impact(10, 0)



func _is_space_pressed(event: InputEvent) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE
