extends Node

@export var weight:float = 1.0
@export var friction:float = 0.5
@export var body_path:NodePath

@onready var parentBody := get_node(body_path) as CharacterBody2D

func impact(_force: float, _ang: float) -> void:
	var effective_force := _force / weight
	parentBody.velocity.x = effective_force * cos(_ang)
	parentBody.velocity.y = effective_force * sin(_ang)


func _physics_process(delta: float) -> void:
	# Slow down over time due to friction (start fast, decay toward zero)
	parentBody.velocity *= max(0.0, 1.0 - friction * delta)
	parentBody.move_and_slide()
	
	
