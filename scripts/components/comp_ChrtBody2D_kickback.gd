extends Node

@export var weight:float = 1.0
## Friction (velocity multiplier per second). With v0=100, stop_speed=8: ~1.25 gives ~2s slide.
@export var friction: float = 1.25
@export var stop_speed: float = 8.0
@export var body_path:NodePath
## Shake amplitude per unit of velocity (pixels) when moving from impact
@export var movement_shake_scale: float = 0.08

@onready var parentBody := get_node(body_path) as CharacterBody2D
var _impact_active: bool = false
var _body_sprite: Sprite2D

func _ready() -> void:
	_body_sprite = parentBody.get_node_or_null("Sprite2D") as Sprite2D

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
		if _body_sprite:
			_body_sprite.position = Vector2.ZERO
		return

	parentBody.move_and_slide()

	# Movement shake: harder when faster
	if _body_sprite:
		var speed: float = parentBody.velocity.length()
		var amplitude: float = speed * movement_shake_scale
		_body_sprite.position = Vector2(
			randf_range(-amplitude, amplitude),
			randf_range(-amplitude, amplitude)
		)
