extends Node

signal impact_started()
signal impact_ended()
signal body_slammed(collision: KinematicCollision2D, speed: float)

@export var weight:float = 1.0
@export var friction: float = 1.25
@export var stop_speed: float = 8.0
@export var body_path:NodePath
@export var movement_shake_scale: float = 0.08
@export_group("Push transfer")
@export var transfer_groups: Array[StringName] = [&"goblin", &"player"]
@export var transfer_force_ratio: float = 1.0
@export var transfer_force_min: float = 12.0
@export var transfer_force_max: float = 140.0
@export var transfer_cooldown_sec: float = 0.08
@export var pillar_hit_slowdown_mult: float = 0.2

@onready var parentBody := get_node(body_path) as CharacterBody2D
var _impact_active: bool = false
var _body_sprite: Sprite2D
var _recent_transfer_until: Dictionary = {}


## Cache the optional sprite used for impact shake feedback.
func _ready() -> void:
	_body_sprite = parentBody.get_node_or_null("Sprite2D") as Sprite2D


## Apply kickback from force/angle and emit start signal when movement begins.
func impact(_force: float, _ang: float) -> void:
	# Convert force into velocity while guarding against zero weight.
	var safe_weight = max(weight, 0.001)
	var effective_force = _force / safe_weight
	parentBody.velocity.x = effective_force * cos(_ang)
	parentBody.velocity.y = effective_force * sin(_ang)
	# Mark active state and notify listeners.
	_impact_active = parentBody.velocity.length_squared() > 0.0
	if _impact_active:
		impact_started.emit()

## Apply kickback from a raw velocity vector and emit start signal if active.
func impact_velocity(new_velocity: Vector2) -> void:
	parentBody.velocity = new_velocity
	_impact_active = parentBody.velocity.length_squared() > 0.0
	if _impact_active:
		impact_started.emit()

## Return whether this component is currently driving impact movement.
func is_impact_active() -> bool:
	return _impact_active


# Physics
## Simulate friction, collisions, and push transfer while impact is active.
func _physics_process(delta: float) -> void:
	# Exit early when no kickback movement is in progress.
	if !_impact_active:
		return

	# Apply frame-based friction to impact velocity.
	parentBody.velocity *= max(0.0, 1.0 - friction * delta)

	# Stop fully once under threshold and reset visual shake offset.
	if parentBody.velocity.length_squared() <= stop_speed * stop_speed:
		parentBody.velocity = Vector2.ZERO
		_impact_active = false
		impact_ended.emit()
		if _body_sprite:
			_body_sprite.position = Vector2.ZERO
		return

	# Move body, collect collision data, and transfer impact to valid targets.
	var velocity_before_slide: Vector2 = parentBody.velocity
	var speed_before_slide: float = velocity_before_slide.length()
	parentBody.move_and_slide()
	var source_is_pillar: bool = get_parent() != null and get_parent().is_in_group("pillar")
	var collided_any_pillar: bool = false

	for i in parentBody.get_slide_collision_count():
		var collision: KinematicCollision2D = parentBody.get_slide_collision(i)
		if source_is_pillar and _node_or_ancestor_in_group(collision.get_collider(), "pillar"):
			collided_any_pillar = true
		body_slammed.emit(collision, speed_before_slide)
		_try_transfer_push(collision, velocity_before_slide, speed_before_slide, source_is_pillar)

	# Keep pillar momentum unless pillar-to-pillar collision occurred.
	if source_is_pillar and !collided_any_pillar:
		parentBody.velocity = velocity_before_slide
	elif source_is_pillar and collided_any_pillar:
		parentBody.velocity *= clamp(pillar_hit_slowdown_mult, 0.0, 1.0)

	# Apply sprite jitter proportional to remaining speed.
	if _body_sprite:
		var speed: float = parentBody.velocity.length()
		var amplitude: float = speed * movement_shake_scale
		_body_sprite.position = Vector2(
			randf_range(-amplitude, amplitude),
			randf_range(-amplitude, amplitude)
		)


# Push transfer
## Transfer impact momentum into collided targets based on rules and cooldown.
func _try_transfer_push(collision: KinematicCollision2D, velocity_before_slide: Vector2, speed_before_slide: float, source_is_pillar: bool) -> void:
	# Ignore invalid collisions and negligible source speed.
	if collision == null:
		return
	if speed_before_slide <= 0.001:
		return

	# Resolve target and capabilities (kickback component or push receiver).
	var target: Node = _resolve_transfer_target(collision.get_collider())
	if target == null or target == self or target == parentBody or target == get_parent():
		return
	var target_kickback: Node = target.get_node_or_null("CompBodyKickback")
	var target_push_receiver: Node = _resolve_push_receiver(target)
	if target_kickback == null and target_push_receiver == null:
		return

	# Prevent repeated transfers to the same target within cooldown window.
	var target_id: int = target.get_instance_id()
	var now_sec: float = Time.get_ticks_msec() * 0.001
	if _recent_transfer_until.has(target_id) and now_sec < float(_recent_transfer_until[target_id]):
		return
	_recent_transfer_until[target_id] = now_sec + transfer_cooldown_sec

	# Preserve pillar-driven velocity on pillar->goblin/player collisions.
	if source_is_pillar and target.is_in_group("goblin"):
		if target_kickback != null:
			target_kickback.call("impact_velocity", velocity_before_slide)
		return
	if source_is_pillar and target.is_in_group("player"):
		if target_kickback != null:
			target_kickback.call("impact_velocity", velocity_before_slide)
		elif target_push_receiver != null:
			target_push_receiver.call("receive_external_push_velocity", velocity_before_slide)
		return

	# Compute generic transfer impulse and deliver to supported API.
	var push_dir: Vector2 = velocity_before_slide.normalized()
	var transfer_force: float = clamp(speed_before_slide * transfer_force_ratio, transfer_force_min, transfer_force_max)
	if target_kickback != null:
		target_kickback.call("impact", transfer_force, push_dir.angle())
	elif target_push_receiver != null:
		target_push_receiver.call("receive_external_push", transfer_force, push_dir)


# Helpers
## Walk up collider ancestry and return first node in configured transfer groups.
func _resolve_transfer_target(collider: Object) -> Node:
	if collider == null:
		return null
	var node := collider as Node
	if node == null:
		return null
	var current: Node = node
	while current != null:
		for group_name in transfer_groups:
			if !String(group_name).is_empty() and current.is_in_group(StringName(group_name)):
				return current
		current = current.get_parent()
	return null


## Find a node in target ancestry that supports external push methods.
func _resolve_push_receiver(target: Node) -> Node:
	var current: Node = target
	while current != null:
		if current.has_method("receive_external_push_velocity") or current.has_method("receive_external_push"):
			return current
		current = current.get_parent()
	return null


## Return true when collider or any ancestor belongs to a given group.
func _node_or_ancestor_in_group(collider: Object, group: StringName) -> bool:
	if collider == null:
		return false
	var current := collider as Node
	while current != null:
		if current.is_in_group(group):
			return true
		current = current.get_parent()
	return false
