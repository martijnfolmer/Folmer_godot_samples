extends CharacterBody2D

@export_group("Movement")
## Speed of the player (pixels/second)
@export var speed: float = 500.0
## How fast the player accelerates toward the desired speed (pixels/second²)
@export var accelerate: float = 2000.0
## How fast the player slows down to 0 when no input is given (pixels/second²)
@export var deccelerate: float = 2500.0
## How quickly the body turns to face the mouse (higher = snappier)
@export var angular_speed: float = 8.0

@export_group("Sprites")
## Body sprite texture
@export var texture: Texture2D
## Leg sprite texture
@export var legTexture: Texture2D

@export_group("Leg visualisation")
## How far the legs trail behind the body while moving (pixels)
@export var trail_distance: float = 10.0
## Side-to-side spacing between left/right legs (pixels)
@export var leg_side_offset: float = 6.0
## How quickly the leg pair position follows its target (higher = snappier)
@export var leg_follow_smooth: float = 22.0
## How quickly the legs rotate to align with movement direction (higher = snappier)
@export var legs_rot_smooth: float = 18.0

@export_group("Stepping (rate + fading)")
## Estimated stride length (pixels) when leg_base_scale_x = 1.0 (bigger = fewer steps)
@export var step_length_pixels_at_scale_1: float = 24.0
## Smoothing for changes in step rate (higher = less jitter when speed changes)
@export var step_rate_smooth: float = 12.0
## How quickly stepping fades in/out when starting or stopping (higher = faster fade)
@export var step_fade_smooth: float = 16.0

@export_group("Leg scale smoothing")
## How quickly the leg X-scale (front/back flip) follows its target (higher = snappier)
@export var scale_smooth_x: float = 20.0
## How quickly the leg Y-scale (thickness/extension) follows its target (higher = snappier)
@export var scale_smooth_y: float = 20.0

@export_group("Leg shape")
## Base X scale for legs, also treated as legt length for step rate calculation
@export var leg_base_scale_x: float = 1.0
## Base Y scale for legs (thickness)
@export var leg_base_scale_y: float = 1.0
## Extra Y scaling added at the extremes of each step
@export var leg_extend_amount_y: float = 0.35

var sprite: Sprite2D
var leg_left: Sprite2D
var leg_right: Sprite2D

var _step_time: float = 0.0
var _step_strength: float = 0.0
var _step_angular_speed: float = 0.0  # smoothed radians/sec

var _cur_lx: float = 0.0
var _cur_rx: float = 0.0
var _cur_ly: float = 1.0
var _cur_ry: float = 1.0

var _last_move_dir: Vector2 = Vector2.RIGHT
var _legs_center: Vector2 = Vector2.ZERO
var _legs_rotation: float = 0.0

func _ready() -> void:
	
	# Main body sprite
	sprite = Sprite2D.new()
	add_child(sprite)
	sprite.texture = texture

	# Leg sprites
	leg_left = Sprite2D.new()
	add_child(leg_left)
	leg_left.texture = legTexture
	leg_left.z_index = sprite.z_index - 1
	leg_left.modulate.a = 0.6

	leg_right = Sprite2D.new()
	add_child(leg_right)
	leg_right.texture = legTexture
	leg_right.z_index = sprite.z_index - 1
	leg_right.modulate.a = 0.6

	_cur_ly = leg_base_scale_y
	_cur_ry = leg_base_scale_y
	leg_left.scale = Vector2(_cur_lx, _cur_ly)
	leg_right.scale = Vector2(_cur_rx, _cur_ry)

	_legs_center = sprite.global_position
	_legs_rotation = 0.0

func _physics_process(delta: float) -> void:
	# Input
	var input_dir: Vector2 = Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	)
	if input_dir.length() > 0.0:
		input_dir = input_dir.normalized()

	# Movement
	var target_velocity: Vector2 = input_dir * speed
	var rate: float = accelerate if input_dir != Vector2.ZERO else deccelerate
	velocity.x = move_toward(velocity.x, target_velocity.x, rate * delta)
	velocity.y = move_toward(velocity.y, target_velocity.y, rate * delta)
	var coll = move_and_slide()


	# Get direction of the movement
	var moving: bool = velocity.length() > 0.05
	var vel_dir: Vector2 = velocity.normalized() if moving else Vector2.ZERO
	if moving:
		_last_move_dir = vel_dir
	var move_dir: Vector2 = _last_move_dir.normalized()

	# Body rotates toward mouse
	var desired_body_rot: float = get_local_mouse_position().angle()
	sprite.rotation = lerp_angle(sprite.rotation, desired_body_rot, angular_speed * delta)

	# Legs rotate toward movement direction
	var desired_legs_rot: float = move_dir.angle()
	_legs_rotation = lerp_angle(_legs_rotation, desired_legs_rot, 1.0 - exp(-legs_rot_smooth * delta))
	leg_left.rotation = _legs_rotation
	leg_right.rotation = _legs_rotation

	# Legs position: centered under body, trailing behind movement
	var center_target: Vector2 = sprite.global_position
	if moving:
		center_target -= vel_dir * trail_distance
	_legs_center = _legs_center.lerp(center_target, 1.0 - exp(-leg_follow_smooth * delta))

	# Split left/right relative to body facing (top-down)
	var perp: Vector2 = Vector2.RIGHT.rotated(sprite.rotation).orthogonal().normalized()
	leg_left.global_position = _legs_center - perp * leg_side_offset
	leg_right.global_position = _legs_center + perp * leg_side_offset

	# Stepping strength (fade in/out when you start/stop)
	var target_strength: float = 1.0 if moving else 0.0
	_step_strength = lerp(_step_strength, target_strength, 1.0 - exp(-step_fade_smooth * delta))

	# Step rate based on speed and leg length
	var movement_speed: float = velocity.length()
	var stride_length_pixels: float = max(1.0, step_length_pixels_at_scale_1 * max(0.05, leg_base_scale_x))
	var steps_per_second: float = movement_speed / stride_length_pixels

	# Convert to radians/sec for sin() phase and smooth it so it doesn't jitter
	var desired_step_angular_speed: float = TAU * steps_per_second
	_step_angular_speed = lerp(_step_angular_speed, desired_step_angular_speed, 1.0 - exp(-step_rate_smooth * delta))
	_step_time += _step_angular_speed * delta

	# Left/right opposite phase
	var phase_l: float = sin(_step_time) * _step_strength
	var phase_r: float = sin(_step_time + PI) * _step_strength

	# X swing and Y extension
	var desired_lx: float = phase_l * leg_base_scale_x
	var desired_rx: float = phase_r * leg_base_scale_x

	var desired_ly: float = leg_base_scale_y + leg_extend_amount_y * abs(float(phase_l))
	var desired_ry: float = leg_base_scale_y + leg_extend_amount_y * abs(float(phase_r))

	# Smooth the scale change
	_cur_lx = lerp(_cur_lx, desired_lx, 1.0 - exp(-scale_smooth_x * delta))
	_cur_rx = lerp(_cur_rx, desired_rx, 1.0 - exp(-scale_smooth_x * delta))
	_cur_ly = lerp(_cur_ly, desired_ly, 1.0 - exp(-scale_smooth_y * delta))
	_cur_ry = lerp(_cur_ry, desired_ry, 1.0 - exp(-scale_smooth_y * delta))

	leg_left.scale = Vector2(_cur_lx, _cur_ly)
	leg_right.scale = Vector2(_cur_rx, _cur_ry)

	# Optional pixel snapping
	sprite.global_position = sprite.global_position.round()
	leg_left.global_position = leg_left.global_position.round()
	leg_right.global_position = leg_right.global_position.round()
