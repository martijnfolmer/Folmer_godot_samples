extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("glass")

func _instance_destroy() ->void:
	 #Free children
	for child in get_children():
		child.queue_free()
	queue_free()
