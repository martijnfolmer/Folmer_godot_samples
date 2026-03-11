extends Node

signal impact_started()
signal impact_ended()
signal body_slammed(collision: KinematicCollision2D, speed: float)

@export var weight:float = 1.0
## Friction
@export var friction: float = 1.25
## If you are below this speed, we just stop
@export var stop_speed: float = 8.0
@export var body_path:NodePath
## Shake amplitude per unit of velocity (pixels) when moving from impact
@export var movement_shake_scale: float = 0.08
@export_group("Push transfer")
## Bodies in these groups can receive transferred kickback when collided with
@export var transfer_groups: Array[StringName] = [&"goblin"]
## Multiplier applied to current movement speed when transferring force
@export var transfer_force_ratio: float = 1.0
## Clamp minimum transfer force so light taps still push
@export var transfer_force_min: float = 12.0
## Clamp maximum transfer force to avoid runaway chain reactions
@export var transfer_force_max: float = 140.0
## Minimum time between transfers to the same target (seconds)
@export var transfer_cooldown_sec: float = 0.08
## Extra velocity multiplier applied after pillar-to-pillar impact (lower = stronger slowdown)
@export var pillar_hit_slowdown_mult: float = 0.2

@onready var parentBody := get_node(body_path) as CharacterBody2D
var _impact_active: bool = false
var _body_sprite: Sprite2D
var _recent_transfer_until: Dictionary = {}

func _ready() -> void:
	_body_sprite = parentBody.get_node_or_null("Sprite2D") as Sprite2D

func impact(_force: float, _ang: float) -> void:
	var safe_weight = max(weight, 0.001)
	var effective_force = _force / safe_weight
	parentBody.velocity.x = effective_force * cos(_ang)
	parentBody.velocity.y = effective_force * sin(_ang)
	_impact_active = parentBody.velocity.length_squared() > 0.0
	if _impact_active:
		impact_started.emit()

func impact_velocity(new_velocity: Vector2) -> void:
	parentBody.velocity = new_velocity
	_impact_active = parentBody.velocity.length_squared() > 0.0
	if _impact_active:
		impact_started.emit()


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
		impact_ended.emit()
		if _body_sprite:
			_body_sprite.position = Vector2.ZERO
		return

	var velocity_before_slide: Vector2 = parentBody.velocity
	var speed_before_slide: float = velocity_before_slide.length()
	parentBody.move_and_slide()
	var source_is_pillar: bool = get_parent() != null and get_parent().is_in_group("pillar")
	var collided_any_pillar: bool = false

	# Report collisions for wall-slam detection (e.g. goblin dazed state)
	for i in parentBody.get_slide_collision_count():
		var collision: KinematicCollision2D = parentBody.get_slide_collision(i)
		if source_is_pillar and _node_or_ancestor_in_group(collision.get_collider(), "pillar"):
			collided_any_pillar = true
		body_slammed.emit(collision, speed_before_slide)
		_try_transfer_push(collision, velocity_before_slide, speed_before_slide, source_is_pillar)

	# Pillars should keep their course/speed when hitting goblins.
	# Only let collision response change pillar movement after pillar-to-pillar contact.
	if source_is_pillar and !collided_any_pillar:
		parentBody.velocity = velocity_before_slide
	elif source_is_pillar and collided_any_pillar:
		parentBody.velocity *= clamp(pillar_hit_slowdown_mult, 0.0, 1.0)

	# Movement shake: harder when faster
	if _body_sprite:
		var speed: float = parentBody.velocity.length()
		var amplitude: float = speed * movement_shake_scale
		_body_sprite.position = Vector2(
			randf_range(-amplitude, amplitude),
			randf_range(-amplitude, amplitude)
		)


func _try_transfer_push(collision: KinematicCollision2D, velocity_before_slide: Vector2, speed_before_slide: float, source_is_pillar: bool) -> void:
	if collision == null:
		return
	if speed_before_slide <= 0.001:
		return

	var target: Node = _resolve_transfer_target(collision.get_collider())
	if target == null or target == self or target == parentBody or target == get_parent():
		return
	var target_kickback: Node = target.get_node_or_null("CompBodyKickback")
	if target_kickback == null:
		return

	var target_id: int = target.get_instance_id()
	var now_sec: float = Time.get_ticks_msec() * 0.001
	if _recent_transfer_until.has(target_id) and now_sec < float(_recent_transfer_until[target_id]):
		return
	_recent_transfer_until[target_id] = now_sec + transfer_cooldown_sec

	if source_is_pillar and target.is_in_group("goblin"):
		target_kickback.call("impact_velocity", velocity_before_slide)
		return

	var push_dir: Vector2 = velocity_before_slide.normalized()
	var transfer_force: float = clamp(speed_before_slide * transfer_force_ratio, transfer_force_min, transfer_force_max)
	target_kickback.call("impact", transfer_force, push_dir.angle())


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


func _node_or_ancestor_in_group(collider: Object, group: StringName) -> bool:
	if collider == null:
		return false
	var current := collider as Node
	while current != null:
		if current.is_in_group(group):
			return true
		current = current.get_parent()
	return false
