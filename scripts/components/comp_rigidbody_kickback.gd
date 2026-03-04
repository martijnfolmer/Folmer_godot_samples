extends Node

@export var weight:float = 1.0
@export var friction:float = 0.1
@export var body_path:NodePath

@onready var parentBody := get_node(body_path) as CharacterBody2D

func impact(_force: float, _ang: float) -> void:
	parentBody.velocity.x = 10
	parentBody.velocity.y = 10
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	parentBody.move_and_slide()
	
	
