extends CharacterBody2D

@export_group("Movement")
## Maximum player move speed from WASD input
@export var speed: float = 500.0
## How quickly input velocity ramps up toward target speed
@export var accelerate: float = 2000.0
## How quickly input velocity slows when there is no input (name kept for compatibility)
@export var deccelerate: float = 2500.0
## Rotation follow speed while turning to face the mouse
@export var angular_speed: float = 8.0

@export_group("Sprites")
## Texture used for both procedural leg sprites
@export var legTexture: Texture2D

@export_group("Leg visualisation")
## How far leg center trails behind body while moving
@export var trail_distance: float = 10.0
## Horizontal spacing between left and right legs
@export var leg_side_offset: float = 6.0
## Smoothing rate for leg center follow movement
@export var leg_follow_smooth: float = 22.0
## Smoothing rate for leg rotation alignment
@export var legs_rot_smooth: float = 18.0

@export_group("Stepping (rate + fading)")
## Base stride length used to convert speed into step rate
@export var step_length_pixels_at_scale_1: float = 24.0
## Smoothing rate applied to stepping angular speed
@export var step_rate_smooth: float = 12.0
## Blend speed for stepping in/out when starting or stopping movement
@export var step_fade_smooth: float = 16.0

@export_group("Leg scale smoothing")
## Smoothing rate for leg X scale changes
@export var scale_smooth_x: float = 20.0
## Smoothing rate for leg Y scale changes
@export var scale_smooth_y: float = 20.0

@export_group("Leg shape")
## Base X scale for legs; also used as leg-length proxy for step rate
@export var leg_base_scale_x: float = 1.0
## Base Y scale (thickness) of both legs
@export var leg_base_scale_y: float = 1.0
## Added Y stretch when leg is in the extended part of a step
@export var leg_extend_amount_y: float = 0.35

@export_group("Attacking")
## Total duration of the kick state in seconds
@export var kick_duration_sec: float = 1.0
## Force passed to target kickback component on hit
@export var kick_force: float = 100.0
## Multiplier for kicking leg forward length during attack pose
@export var kick_leg_length_mult: float = 2.5
## Forward offset applied to kicking leg and hitbox anchor
@export var kick_leg_forward_offset: float = 28.0

## Thickness multiplier for kicking leg during attack pose
@export var kick_leg_thickness_mult: float = 1.2

## Movement speed multiplier while kick attack is active
@export var kick_speed_mult: float = 0.5
## Screen shake strength in camera pixels when a kick hits (requires SingletonCamera autoload)
@export var kick_screen_shake_strength: float = 10.0
## Screen shake duration in seconds when a kick hits
@export var kick_screen_shake_duration_sec: float = 0.2

@export_group("Pillar push")
## Fraction of pillar velocity carried into external push
@export var pillar_push_carry_ratio: float = 1.0
## How much opposing player input can reduce push while in contact
@export var pillar_push_escape_ratio: float = 0.8
## Smoothing speed when external push follows contact push
@export var pillar_push_follow_smooth: float = 20.0
## Base decay rate for external push when no contact remains
@export var pillar_push_decay: float = 1400.0
## Extra decay multiplier used when not touching pillars
@export var pillar_push_no_contact_decay_mult: float = 1.8
## Absolute speed cap for external push velocity
@export var pillar_push_max_speed: float = 1400.0
## Contact-time cap for push speed while touching a pillar
@export var pillar_push_contact_max_speed: float = 900.0
## Time window to keep recent pillar contacts cached
@export var pillar_contact_memory_sec: float = 0.14
## Distance used per overlap-separation nudge step
@export var pillar_separation_epsilon: float = 1.2
## Number of separation passes when resolving pillar overlap
@export var pillar_separation_iterations: int = 3

# Runtime node references
## Main body sprite created in _ready()
var sprite: Sprite2D
## Overlap area used to detect kick hits at leg tip
var kick_hitbox: Area2D
## Collision shape reused for direct space-state kick queries
var kick_shape: CircleShape2D
## Left leg sprite created in _ready()
var leg_left: Sprite2D
## Right leg sprite created in _ready()
var leg_right: Sprite2D

# Step animation state
## Running phase value for sinusoidal stepping
var _step_time: float = 0.0
## Blend weight for step animation (0 idle, 1 full step)
var _step_strength: float = 0.0
## Smoothed angular speed driving _step_time
var _step_angular_speed: float = 0.0

# Current leg scales (smoothed)
## Current left leg X scale after smoothing
var _cur_lx: float = 0.0
## Current right leg X scale after smoothing
var _cur_rx: float = 0.0
## Current left leg Y scale after smoothing
var _cur_ly: float = 1.0
## Current right leg Y scale after smoothing
var _cur_ry: float = 1.0

# Leg alignment/cache state
## Last non-zero movement direction used when velocity is near zero
var _last_move_dir: Vector2 = Vector2.RIGHT
## Smoothed world-space center point shared by both legs
var _legs_center: Vector2 = Vector2.ZERO
## Local leg rotation relative to body, smoothed each frame
var _legs_rotation: float = 0.0

# Attack and hit tracking state
## Whether a kick attack is currently active
var _attack_active: bool = false
## Cached world-space attack angle captured when kick starts
var _attack_angle: float = 0.0
## Remaining kick active time in seconds
var _attack_time_left: float = 0.0
## Targets already hit during the current kick to avoid duplicate hits
var _kick_hit_bodies: Array[Node] = []
## Guard flag to prevent multiple squash-destroy triggers
var _destroying_from_squash: bool = false

# Movement and external push state
## Player velocity driven directly by input acceleration/deceleration
var _input_velocity: Vector2 = Vector2.ZERO
## Additional velocity contributed by pillar push/carry interactions
var _external_push_velocity: Vector2 = Vector2.ZERO
## Short-lived cache of recent pillar contacts for squash detection
var _recent_pillar_contacts: Dictionary = {}

# Lifecycle
## Create runtime sprites/hitbox and initialize player state
func _ready() -> void:
	add_to_group("player")

	# get the sprite2D
	sprite = $Sprite2D

	# Build leg sprites
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

	# Create kick hitbox used for close-range overlap detection
	kick_hitbox = Area2D.new()
	kick_hitbox.name = "KickHitbox"
	kick_hitbox.monitoring = true
	kick_hitbox.monitorable = false
	kick_hitbox.collision_layer = 0
	kick_hitbox.collision_mask = 1
	add_child(kick_hitbox)
	kick_shape = CircleShape2D.new()
	kick_shape.radius = 32.0
	var kick_col := CollisionShape2D.new()
	kick_col.shape = kick_shape
	kick_hitbox.add_child(kick_col)

# Main loop
## Process movement, combat, leg animation, and external push each frame
func _physics_process(delta: float) -> void:
	# Aim body rotation toward mouse world position
	var desired_body_rot: float = (get_global_mouse_position() - global_position).angle()

	# Start attack on press and reset hit tracking
	if !_attack_active and Input.is_action_just_pressed("ui_primary_action"):
		_attack_active = true
		_attack_angle = desired_body_rot
		_attack_time_left = max(0.01, kick_duration_sec)
		_kick_hit_bodies.clear()

	## While attacking, apply hits to any overlapping valid targets
	if _attack_active:
		var space_state := get_world_2d().direct_space_state
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = kick_shape
		query.transform = Transform2D(0, kick_hitbox.global_position)
		query.collision_mask = 1
		query.exclude = [get_rid()]
		for result in space_state.intersect_shape(query):
			var body: Node = result["collider"]
			var target: Node = body.get_parent()
			if target in _kick_hit_bodies:
				continue
			if target.is_in_group("pillar") or target.is_in_group("goblin"):
				_apply_kick_to_target(target)
			elif target.is_in_group("glass") or target.is_in_group("wall"):
				_apply_kick_to_static(target)

	# Read WASD axis input and normalize direction
	var input_dir: Vector2 = Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	)
	if input_dir.length() > 0.0:
		input_dir = input_dir.normalized()

	# Accelerate/decelerate input velocity and combine with external push
	var effective_speed: float = speed * (kick_speed_mult if _attack_active else 1.0)
	var target_velocity: Vector2 = input_dir * effective_speed
	var rate: float = accelerate if input_dir != Vector2.ZERO else deccelerate
	_input_velocity.x = move_toward(_input_velocity.x, target_velocity.x, rate * delta)
	_input_velocity.y = move_toward(_input_velocity.y, target_velocity.y, rate * delta)
	velocity = _input_velocity + _external_push_velocity

	# Advance attack duration timer and end when virtual distance is reached
	if _attack_active:
		_attack_time_left = max(0.0, _attack_time_left - delta)
		if _attack_time_left <= 0.0:
			_attack_active = false

	# Run movement, carry pillar push, and resolve overlap nudges
	move_and_slide()
	_update_external_push_from_pillars(delta)
	_resolve_pillar_overlap()
	velocity = _input_velocity + _external_push_velocity

	# Trigger squash death when opposing pillar contacts are detected
	var squash_contacts: Array = _get_pillar_squash_contacts()
	if squash_contacts.size() < 2:
		squash_contacts = _get_recent_pillar_squash_contacts()
	if squash_contacts.size() >= 2:
		_destroy_from_pillars_squash(squash_contacts[0], squash_contacts[1])
		return

	# If kick collides during slide checks, apply kick once per target and stop attack
	if _attack_active and get_slide_collision_count() > 0:
		for i in get_slide_collision_count():
			var col := get_slide_collision(i)
			if !col:
				continue
			var body := col.get_collider() as Node2D
			if !body:
				continue

			var collNode: Node = body.get_parent()
			if collNode not in _kick_hit_bodies:
				if collNode.is_in_group("pillar") or collNode.is_in_group("goblin"):
					_apply_kick_to_target(collNode)
				elif collNode.is_in_group("glass") or collNode.is_in_group("wall"):
					_apply_kick_to_static(collNode)

		_attack_active = false

	# Compute movement direction used by body/legs visual logic
	var moving: bool = velocity.length() > 0.05
	var vel_dir: Vector2 = velocity.normalized() if moving else Vector2.ZERO
	if moving:
		_last_move_dir = vel_dir
	var move_dir: Vector2 = _last_move_dir.normalized()

	# Rotate body toward aim; sprite remains unrotated locally
	rotation = lerp_angle(rotation, desired_body_rot, angular_speed * delta)
	sprite.rotation = 0.0

	# Rotate legs toward kick angle or movement direction
	var legs_world_ang: float = _attack_angle if _attack_active else move_dir.angle()
	var desired_legs_rot: float = legs_world_ang - rotation
	_legs_rotation = lerp_angle(_legs_rotation, desired_legs_rot, 1.0 - exp(-legs_rot_smooth * delta))
	leg_left.rotation = _legs_rotation
	leg_right.rotation = _legs_rotation

	# Update legs center and side offsets relative to body
	var center_target: Vector2 = sprite.global_position
	if moving and !_attack_active:
		center_target -= vel_dir * trail_distance
	_legs_center = _legs_center.lerp(center_target, 1.0 - exp(-leg_follow_smooth * delta))

	var perp: Vector2 = Vector2.RIGHT.rotated(rotation).orthogonal().normalized()
	leg_left.global_position = _legs_center - perp * leg_side_offset
	leg_right.global_position = _legs_center + perp * leg_side_offset
	if _attack_active:
		var kick_forward: Vector2 = Vector2.RIGHT.rotated(_attack_angle)
		leg_left.global_position += kick_forward * kick_leg_forward_offset

	# Keep legs behind body depth
	leg_left.z_index = sprite.z_index - 1
	leg_right.z_index = sprite.z_index - 1

	# Blend stepping strength in/out depending on state
	var target_strength: float = 0.0 if _attack_active else (1.0 if moving else 0.0)
	_step_strength = lerp(_step_strength, target_strength, 1.0 - exp(-step_fade_smooth * delta))

	var desired_lx: float
	var desired_rx: float
	var desired_ly: float
	var desired_ry: float

	# Choose pose for kick state or walking step cycle
	if _attack_active:
		desired_lx = leg_base_scale_x * kick_leg_length_mult
		desired_rx = 0.0
		desired_ly = leg_base_scale_y * kick_leg_thickness_mult
		desired_ry = leg_base_scale_y
	else:
		# Derive stepping phase speed from movement speed and stride
		var movement_speed: float = velocity.length()
		var stride_length_pixels: float = max(1.0, step_length_pixels_at_scale_1 * max(0.05, leg_base_scale_x))
		var steps_per_second: float = movement_speed / stride_length_pixels

		var desired_step_angular_speed: float = TAU * steps_per_second
		_step_angular_speed = lerp(_step_angular_speed, desired_step_angular_speed, 1.0 - exp(-step_rate_smooth * delta))
		_step_time += _step_angular_speed * delta

		# Use opposite sine phase for left/right legs
		var phase_l: float = sin(_step_time) * _step_strength
		var phase_r: float = sin(_step_time + PI) * _step_strength

		desired_lx = phase_l * leg_base_scale_x
		desired_rx = phase_r * leg_base_scale_x
		desired_ly = leg_base_scale_y + leg_extend_amount_y * abs(float(phase_l))
		desired_ry = leg_base_scale_y + leg_extend_amount_y * abs(float(phase_r))

	# Smooth leg scale changes
	_cur_lx = lerp(_cur_lx, desired_lx, 1.0 - exp(-scale_smooth_x * delta))
	_cur_rx = lerp(_cur_rx, desired_rx, 1.0 - exp(-scale_smooth_x * delta))
	_cur_ly = lerp(_cur_ly, desired_ly, 1.0 - exp(-scale_smooth_y * delta))
	_cur_ry = lerp(_cur_ry, desired_ry, 1.0 - exp(-scale_smooth_y * delta))

	leg_left.scale = Vector2(_cur_lx, _cur_ly)
	leg_right.scale = Vector2(_cur_rx, _cur_ry)

	# Snap visuals to integer pixels for crisp sprite rendering
	sprite.global_position = sprite.global_position.round()
	leg_left.global_position = leg_left.global_position.round()
	leg_right.global_position = leg_right.global_position.round()

	# Keep kick hitbox at the tip of the active kicking leg
	if _attack_active:
		var leg_half_length: float = leg_left.texture.get_size().x * leg_left.scale.x * 0.5
		var foot_tip: Vector2 = leg_left.global_position + Vector2.RIGHT.rotated(leg_left.global_rotation) * leg_half_length
		kick_hitbox.global_position = foot_tip


# Kick
## Apply damage and kickback to a target once per attack
func _apply_kick_to_target(target: Node) -> void:
	_kick_hit_bodies.append(target)
	target.get_node("CompDamage").take_damage(1)
	var ang: float = (get_global_mouse_position() - global_position).angle()
	target.get_node("CompBodyKickback").impact(kick_force, ang)
	_try_apply_kick_screen_shake()


## Handle kick hit on a static destructible (glass/wall) that lacks kickback components
func _apply_kick_to_static(target: Node) -> void:
	_kick_hit_bodies.append(target)
	print("Kick connected with static object: ", target.name)
	
	# actually destroy
	var ang: float = (get_global_mouse_position() - global_position).angle()
	target._instance_destroy(ang)
	
	_try_apply_kick_screen_shake()


## If a node named SingletonCamera exists (autoload or nested in the scene) and exposes add_screen_shake, trigger it.
func _try_apply_kick_screen_shake() -> void:
	var cam := get_tree().root.find_child("SingletonCamera", true, false)
	if cam != null and cam.has_method("add_screen_shake"):
		cam.call("add_screen_shake", kick_screen_shake_strength, kick_screen_shake_duration_sec)


# Squash and destroy
## Return two opposing pillar contacts that indicate a crush scenario.
func _get_pillar_squash_contacts() -> Array:
	var contacts: Array = []
	# Collect current pillar collisions
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		if collision == null:
			continue
		var pillar := _node_or_ancestor_in_group(collision.get_collider() as Node, "pillar")
		if pillar == null:
			continue
		contacts.append({"collision": collision, "pillar": pillar})
	
	if contacts.size() < 2:
		return []

	# Find two different pillars with opposing normals
	for i in contacts.size():
		for j in range(i + 1, contacts.size()):
			var first: Dictionary = contacts[i]
			var second: Dictionary = contacts[j]
			if first["pillar"] == second["pillar"]:
				continue
			var n1: Vector2 = first["collision"].get_normal()
			var n2: Vector2 = second["collision"].get_normal()
			if n1.dot(n2) <= -0.45:
				return [first, second]
	return []


## Trigger destruction flow with smear direction/location from crush contacts
func _destroy_from_pillars_squash(contact_a: Dictionary, contact_b: Dictionary) -> void:
	if _destroying_from_squash:
		return
	_destroying_from_squash = true
	
	var damage := $"../CompDamage"
	if damage == null or !damage.has_method("_instance_destroy"):
		_destroying_from_squash = false
		return

	# Build smear metadata from contact geometry and player velocity
	var normal_a: Vector2 = _get_contact_normal(contact_a)
	var pos_a: Vector2 = _get_contact_position(contact_a)
	var pos_b: Vector2 = _get_contact_position(contact_b)
	var smear_location: Vector2 = (pos_a + pos_b) * 0.5
	var smear_direction: Vector2 = -velocity.normalized() if velocity.length_squared() > 0.001 else normal_a
	
	damage.blood_smear_enabled = true
	damage.blood_smear_direction = smear_direction
	damage.blood_smear_location = smear_location
	damage._instance_destroy()


# External push
## Blend carried velocity from pillar collisions into external push state
func _update_external_push_from_pillars(delta: float) -> void:
	var now_sec: float = Time.get_ticks_msec() * 0.001
	# Keep only recent contact records
	_expire_recent_pillar_contacts(now_sec)
	var target_push: Vector2 = Vector2.ZERO
	var has_pillar_contact: bool = false
	# Build target push from pillar velocities pressing into the player
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		if collision == null:
			continue
		var pillar := _node_or_ancestor_in_group(collision.get_collider() as Node, "pillar")
		if pillar == null:
			continue
		_recent_pillar_contacts[pillar.get_instance_id()] = {
			"normal": collision.get_normal(),
			"position": collision.get_position(),
			"until": now_sec + pillar_contact_memory_sec
		}
		has_pillar_contact = true
		var pillar_body := pillar.get_node_or_null("CharacterBody2D") as CharacterBody2D
		if pillar_body == null:
			continue
		var pillar_velocity: Vector2 = pillar_body.velocity
		if pillar_velocity.length_squared() <= 0.001:
			continue
		var normal: Vector2 = collision.get_normal()
		var push_into_player: float = pillar_velocity.dot(-normal)
		if push_into_player <= 0.0:
			continue
		target_push += -normal * push_into_player * pillar_push_carry_ratio

	# Clamp aggregate push to avoid unstable magnitudes
	if target_push.length() > pillar_push_max_speed:
		target_push = target_push.normalized() * pillar_push_max_speed

	# While in contact, apply escape reduction and follow smoothing
	if has_pillar_contact:
		var input_escape: Vector2 = _input_velocity
		if target_push.length_squared() > 0.001 and input_escape.length_squared() > 0.001:
			var push_dir: Vector2 = target_push.normalized()
			var escape_against_push: float = max(0.0, -input_escape.dot(push_dir))
			if escape_against_push > 0.0:
				var reduction: float = min(target_push.length(), escape_against_push * max(0.0, pillar_push_escape_ratio))
				target_push -= push_dir * reduction
		var contact_cap: float = min(pillar_push_max_speed, max(0.0, pillar_push_contact_max_speed))
		if contact_cap > 0.0 and target_push.length() > contact_cap:
			target_push = target_push.normalized() * contact_cap
		var follow_weight: float = 1.0 - exp(-pillar_push_follow_smooth * delta)
		_external_push_velocity = _external_push_velocity.lerp(target_push, follow_weight)
	else:
		# Without contact, decay external push toward zero
		_external_push_velocity = _external_push_velocity.move_toward(
			Vector2.ZERO,
			pillar_push_decay * max(1.0, pillar_push_no_contact_decay_mult) * delta
		)


## Accept a direct pushed velocity and merge it into external push state
func receive_external_push_velocity(pushed_velocity: Vector2) -> void:
	if pushed_velocity.length_squared() <= 0.001:
		return
	var next_push: Vector2 = pushed_velocity * pillar_push_carry_ratio
	var cap_speed: float = min(pillar_push_max_speed, max(0.0, pillar_push_contact_max_speed))
	if cap_speed > 0.0 and next_push.length() > cap_speed:
		next_push = next_push.normalized() * cap_speed
	# Keep stronger push, or blend toward new push if weaker
	if next_push.length_squared() > _external_push_velocity.length_squared():
		_external_push_velocity = next_push
	else:
		_external_push_velocity = _external_push_velocity.lerp(next_push, 0.4)


## Convert force+direction input into velocity-based external push
func receive_external_push(push_force: float, push_dir: Vector2) -> void:
	if push_force <= 0.0 or push_dir.length_squared() <= 0.001:
		return
	receive_external_push_velocity(push_dir.normalized() * push_force)


# Contact helpers
## Return recent cached contacts that satisfy squash opposition test
func _get_recent_pillar_squash_contacts() -> Array:
	var contacts: Array = []
	# Rebuild contact list from the short-lived cache
	for pillar_id in _recent_pillar_contacts.keys():
		var contact: Dictionary = _recent_pillar_contacts[pillar_id]
		contacts.append({
			"pillar_id": pillar_id,
			"normal": contact.get("normal", Vector2.ZERO),
			"position": contact.get("position", global_position)
		})
	
	if contacts.size() < 2:
		return []

	# Find opposing cached normals from different pillars
	for i in contacts.size():
		for j in range(i + 1, contacts.size()):
			var first: Dictionary = contacts[i]
			var second: Dictionary = contacts[j]
			var n1: Vector2 = first["normal"]
			var n2: Vector2 = second["normal"]
			if n1.dot(n2) <= -0.45:
				return [first, second]
	return []


## Remove expired contact records from cache
func _expire_recent_pillar_contacts(now_sec: float) -> void:
	for pillar_id in _recent_pillar_contacts.keys():
		var contact: Dictionary = _recent_pillar_contacts[pillar_id]
		if now_sec >= float(contact.get("until", 0.0)):
			_recent_pillar_contacts.erase(pillar_id)


# Collision/group helpers
## Resolve collision normal from live collision entry or cached contact data
func _get_contact_normal(contact: Dictionary) -> Vector2:
	if contact.has("collision") and contact["collision"] != null:
		var collision: KinematicCollision2D = contact["collision"]
		return collision.get_normal()
	if contact.has("normal"):
		return contact["normal"]
	return Vector2.ZERO


## Resolve collision position from live collision entry or cached contact data
func _get_contact_position(contact: Dictionary) -> Vector2:
	if contact.has("collision") and contact["collision"] != null:
		var collision: KinematicCollision2D = contact["collision"]
		return collision.get_position()
	if contact.has("position"):
		return contact["position"]
	return global_position


## Return the nearest ancestor in a group, or null if not found
func _node_or_ancestor_in_group(node: Node, group: StringName) -> Node:
	var current: Node = node
	while current != null:
		if current.is_in_group(group):
			return current
		current = current.get_parent()
	return null


# Overlap resolution
## Nudge player out of pillar overlap if we are stuck
func _resolve_pillar_overlap() -> void:
	var passes: int = max(1, pillar_separation_iterations)
	var separation_step: float = max(0.1, pillar_separation_epsilon)
	# Iterate small push-out attempts to resolve corner contacts
	for _i in range(passes):
		var did_push_out: bool = false
		for j in get_slide_collision_count():
			var collision := get_slide_collision(j)
			if collision == null:
				continue
			var pillar := _node_or_ancestor_in_group(collision.get_collider() as Node, "pillar")
			if pillar == null:
				continue
			var normal: Vector2 = collision.get_normal()
			if normal.length_squared() <= 0.001:
				continue
			var nudge: Vector2 = normal.normalized() * separation_step
			var push_collision: KinematicCollision2D = move_and_collide(nudge)
			# A null collision means the nudge succeeded
			if push_collision == null:
				did_push_out = true
		if !did_push_out:
			break
