extends Node2D

# Lifecycle
## Register this node as a pillar target for collisions and queries.
func _ready():
	add_to_group("pillar")
