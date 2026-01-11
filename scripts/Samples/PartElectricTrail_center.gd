extends Node2D

@export var radius: float = 120.0
@export var angular_speed: float = 2.5 # radians/sec

@onready var ball: Node2D = $Ball
@onready var sparks: GPUParticles2D = $Sparks

var angle := 0.0
var last_ball_position := Vector2.ZERO

func _ready() -> void:
	last_ball_position = ball.position

# Make the ball move
func _process(delta: float) -> void:
	angle += angular_speed * delta
	ball.position = Vector2(cos(angle), sin(angle)) * radius
	
	# Emitter has the same position as the ball
	sparks.position = Vector2(cos(angle), sin(angle)) * radius
	

	# estimate velocity
	var diffPosition = ball.position - last_ball_position
	var v = diffPosition / max(delta, 0.0001)
	last_ball_position = ball.position
	
	# point sparks opposite to velocity (so they shoot "back")
	if v.length() > 0.01:
		var base_rot = v.angle() + PI
		var jitter = randf_range(-0.5, 0.5) # radians
		sparks.rotation = base_rot + jitter
