extends CharacterBody2D

@export var speed: float = 500.0
@export var accelerate: float = 2000.0    # units/sec^2 (tune)
@export var deccelerate: float = 2500.0   # units/sec^2 (tune)
@export var texture: Texture2D

var sprite: Sprite2D

func _ready() -> void:
	sprite = Sprite2D.new()
	add_child(sprite)
	sprite.texture = texture


func _physics_process(delta: float) -> void:
	
	# Player input
	var input_dir := Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	)

	if input_dir.length() > 0.0:
		input_dir = input_dir.normalized()

	# Movement
	var target_velocity := input_dir * speed

	# Use accel when there is input, otherwise decel toward zero
	var rate := accelerate if input_dir != Vector2.ZERO else deccelerate

	velocity.x = move_toward(velocity.x, target_velocity.x, rate * delta)
	velocity.y = move_toward(velocity.y, target_velocity.y, rate * delta)

	move_and_slide()

	# Flip when moving left or right (prefer actual motion to avoid flip jitter when input changes)
	if sprite:
		if velocity.x < -1.0:
			sprite.flip_h = true
		elif velocity.x > 1.0:
			sprite.flip_h = false
			
			
	# Snapping location
	if sprite:
		sprite.global_position = sprite.global_position.round()
	
