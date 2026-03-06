extends Node

@export var weight:float = 1.0
@export var friction:float = 0.5
@export var stop_speed: float = 8.0
@export var body_path:NodePath

@onready var parentBody := get_node(body_path) as CharacterBody2D
var _impact_active: bool = false

func impact(_force: float, _ang: float) -> void:
	var safe_weight = max(weight, 0.001)
	var effective_force = _force / safe_weight
	parentBody.velocity.x = effective_force * cos(_ang)
	parentBody.velocity.y = effective_force * sin(_ang)
	_impact_active = parentBody.velocity.length_squared() > 0.0


func _physics_process(delta: float) -> void:
	# Only move if we are under the influence of an impact (so a kick)
	if !_impact_active:
		return

	# Slow down over time due to friction
	parentBody.velocity *= max(0.0, 1.0 - friction * delta)

	# If velocity is below a certain threshold, we completely stop, and deactive _impact
	if parentBody.velocity.length_squared() <= stop_speed * stop_speed:
		parentBody.velocity = Vector2.ZERO
		_impact_active = false
		return

	parentBody.move_and_slide()
	
	
