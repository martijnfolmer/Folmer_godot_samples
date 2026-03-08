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

@export_group("Attacking")
@export var attack_dist: float = 1000		# TODO: we don't use this anymore
@export var attack_v: float = 1000
@export var kick_force: float = 100.0
@export var kick_leg_length_mult: float = 2.5
@export var kick_leg_forward_offset: float = 28.0

## increasing scale of leg when kicking
@export var kick_leg_thickness_mult: float = 1.2

## Speed multiplier while kicking (player can still move from input but slower)
@export var kick_speed_mult: float = 0.5


var sprite: Sprite2D    # TODO: change name to something like player_sprite
var kick_hitbox: Area2D # the hitbox for the kick
var leg_left: Sprite2D
var leg_right: Sprite2D

var _step_time: float = 0.0
var _step_strength: float = 0.0
var _step_angular_speed: float = 0.0  # smoothed radians/sec

# The things 
var _cur_lx: float = 0.0
var _cur_rx: float = 0.0
var _cur_ly: float = 1.0
var _cur_ry: float = 1.0

var _last_move_dir: Vector2 = Vector2.RIGHT
var _legs_center: Vector2 = Vector2.ZERO
var _legs_rotation: float = 0.0

var _attack: Dictionary
var _kick_hit_bodies: Array[Node] = []

func _ready() -> void:
	
	# Main body sprite
	sprite = Sprite2D.new()
	add_child(sprite)
	sprite.texture = texture

	# attacking
	_attack = {"dist_c": 0, "dist_t": attack_dist, "v":attack_v, "ang":0, "state" : false} # TODO: I don't think we use this anymore

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

	# Kick hitbox: follows extended leg during attack, applies damage/kickback to pillars and goblins on overlap
	# TODO: add comments for what each of the kick_hitbox 
	kick_hitbox = Area2D.new()
	kick_hitbox.name = "KickHitbox"
	kick_hitbox.monitoring = true
	kick_hitbox.monitorable = false
	kick_hitbox.collision_layer = 0
	kick_hitbox.collision_mask = 1
	add_child(kick_hitbox)
	var kick_shape := CircleShape2D.new()
	kick_shape.radius = 32.0
	var kick_col := CollisionShape2D.new()
	kick_col.shape = kick_shape
	kick_hitbox.add_child(kick_col)
	kick_hitbox.body_entered.connect(_on_kick_hitbox_body_entered) # this happens every time we do a kick_hitbox

func _physics_process(delta: float) -> void:

	# Turn the body towards the global position
	var desired_body_rot: float = (get_global_mouse_position() - global_position).angle()

	# Start attack (use just_pressed so it doesn't re-trigger on the next frames)
	if !_attack["state"] and Input.is_action_just_pressed("ui_primary_action"):
		_attack["state"] = true
		_attack["ang"] = desired_body_rot
		_attack["dist_c"] = 0.0
		_kick_hit_bodies.clear()

	# When attacking, check overlapping bodies so we don't miss pillars/goblins when close (hitbox can tunnel through)
	if _attack["state"]:
		for body in kick_hitbox.get_overlapping_bodies():
			var target: Node = body.get_parent()
			if (target.is_in_group("pillar") or target.is_in_group("goblin")) and target not in _kick_hit_bodies:
				_apply_kick_to_target(target)

	# Movement: always input-based; slow down while kicking
	var input_dir: Vector2 = Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	)
	if input_dir.length() > 0.0:
		input_dir = input_dir.normalized()

	var effective_speed: float = speed * (kick_speed_mult if _attack["state"] else 1.0) # slower when we speed
	var target_velocity: Vector2 = input_dir * effective_speed
	var rate: float = accelerate if input_dir != Vector2.ZERO else deccelerate
	velocity.x = move_toward(velocity.x, target_velocity.x, rate * delta)
	velocity.y = move_toward(velocity.y, target_velocity.y, rate * delta)

	# Attack duration: advance virtual distance and end kick after attack_dist/attack_v time
	if _attack["state"]:
		_attack["dist_c"] += float(_attack["v"]) * delta
		if _attack["dist_c"] >= float(_attack["dist_t"]):
			_attack["state"] = false

	# actual movement and collision with pillars and such
	move_and_slide()

	# Stop attack if we hit something, stop moving and apply impact/damage to any pillars we collided with
	if _attack["state"] and get_slide_collision_count() > 0:
		for i in get_slide_collision_count():
			var col := get_slide_collision(i)
			if !col:
				continue
			var body := col.get_collider() as Node2D
			if !body:
				continue
			
			# Check what we are colliding with it
			var collNode: Node = body.get_parent()
			if (collNode.is_in_group("pillar") or collNode.is_in_group("goblin")) and collNode not in _kick_hit_bodies:
				_apply_kick_to_target(collNode)
				
				
		_attack["state"] = false
		velocity = Vector2.ZERO

	# Get direction of the movement
	var moving: bool = velocity.length() > 0.05	# are we moving?
	var vel_dir: Vector2 = velocity.normalized() if moving else Vector2.ZERO
	if moving:
		_last_move_dir = vel_dir
	var move_dir: Vector2 = _last_move_dir.normalized()

	# Body (and hitbox) always rotate toward mouse; sprite stays aligned with body
	rotation = lerp_angle(rotation, desired_body_rot, angular_speed * delta)
	sprite.rotation = 0.0

	# Legs rotate toward movement direction (or kick direction when attacking)
	# Legs are body children so use local angle: desired world angle minus body rotation
	var legs_world_ang: float = _attack["ang"] if _attack["state"] else move_dir.angle()
	var desired_legs_rot: float = legs_world_ang - rotation
	_legs_rotation = lerp_angle(_legs_rotation, desired_legs_rot, 1.0 - exp(-legs_rot_smooth * delta))
	leg_left.rotation = _legs_rotation
	leg_right.rotation = _legs_rotation

	# Legs position: centered under body, trailing behind movement (no trailing during kick)
	var center_target: Vector2 = sprite.global_position
	if moving and !_attack["state"]:
		center_target -= vel_dir * trail_distance
	_legs_center = _legs_center.lerp(center_target, 1.0 - exp(-leg_follow_smooth * delta))

	# Split left/right relative to body facing (top-down)
	var perp: Vector2 = Vector2.RIGHT.rotated(rotation).orthogonal().normalized()
	leg_left.global_position = _legs_center - perp * leg_side_offset
	leg_right.global_position = _legs_center + perp * leg_side_offset
	if _attack["state"]:
		var kick_forward: Vector2 = Vector2.RIGHT.rotated(_attack["ang"])
		leg_left.global_position += kick_forward * kick_leg_forward_offset
	
	#Set depth of leg	
	leg_left.z_index = sprite.z_index - 1
	leg_right.z_index = sprite.z_index - 1

	# Stepping strength (fade in/out when you start/stop; no stepping during kick)
	var target_strength: float = 0.0 if _attack["state"] else (1.0 if moving else 0.0)
	_step_strength = lerp(_step_strength, target_strength, 1.0 - exp(-step_fade_smooth * delta))

	var desired_lx: float
	var desired_rx: float
	var desired_ly: float
	var desired_ry: float

	if _attack["state"]:
		# Kick pose: one leg forward, one still (no _step_time advance)
		desired_lx = leg_base_scale_x * kick_leg_length_mult
		desired_rx = 0.0
		desired_ly = leg_base_scale_y * kick_leg_thickness_mult
		desired_ry = leg_base_scale_y
	else:
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
		desired_lx = phase_l * leg_base_scale_x
		desired_rx = phase_r * leg_base_scale_x
		desired_ly = leg_base_scale_y + leg_extend_amount_y * abs(float(phase_l))
		desired_ry = leg_base_scale_y + leg_extend_amount_y * abs(float(phase_r))

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

	if _attack["state"]:
		# Place hitbox at tip of extended leg so it matches where the foot visually hits
		var leg_half_length: float = leg_left.texture.get_size().x * leg_left.scale.x * 0.5
		var foot_tip: Vector2 = leg_left.global_position + Vector2.RIGHT.rotated(leg_left.global_rotation) * leg_half_length
		kick_hitbox.global_position = foot_tip


func _apply_kick_to_target(target: Node) -> void:
	_kick_hit_bodies.append(target)
	target.get_node("CompDamage").take_damage(1)
	var ang: float = (get_global_mouse_position() - global_position).angle()
	target.get_node("CompBodyKickback").impact(kick_force, ang)


# Kicking! collision with foot (pillars and goblins and other things we want to kick)
func _on_kick_hitbox_body_entered(body: Node2D) -> void:
	if !_attack["state"]:
		return
	var target: Node = body.get_parent()
	if !target.is_in_group("pillar") and !target.is_in_group("goblin"):
		return
	if target in _kick_hit_bodies:
		return
	_apply_kick_to_target(target)
