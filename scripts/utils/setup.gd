extends Node2D

# This is the functionality we want to repeat over different samples

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.1, 0.1, 0.2))
