extends Node2D

@export_group("Wall slam")
@export var wall_slam_speed_min: float = 150.0
@export var wall_collision_group: String = "pillar"
@export var treat_static_as_wall: bool = true
@export var blood_smear_scene: PackedScene

@export_group("Dazed orbit visuals")
@export var dazed_orbit_enabled: bool = true
@export var dazed_orbit_texture: Texture2D = preload("res://png/particles/partWhiteSquare64x64.png")
@export var dazed_orbit_count: int = 4
@export var dazed_orbit_radius: float = 36.0
@export var dazed_orbit_speed: float = 4.5
@export var dazed_orbit_scale: float = 0.2

var _dazed: bool = false
var _dazed_orbit_sprites: Array[Sprite2D] = []
var _dazed_orbit_phase: float = 0.0

# Lifecycle
## Register goblin group membership and hook kickback events.
func _ready() -> void:
	add_to_group("goblin")

	# Bind kickback signals from CompBodyKickBack used for dazed state and slam death.
	var kickback := get_node_or_null("CompBodyKickback")
	if kickback:
		kickback.impact_started.connect(_on_impact_started)	# reads the signal impact_started
		kickback.impact_ended.connect(_on_impact_ended)		# reads the signal impact_ended
		kickback.body_slammed.connect(_on_body_slammed)		# reads the signal on_body_slammed

	set_process(true)


## Update dazed orbit positions each frame while visuals are active.
func _process(delta: float) -> void:
	if !_dazed or _dazed_orbit_sprites.is_empty():
		return
	_update_dazed_orbit_visuals(delta)





# Kickback handlers
## Enter dazed state and start orbit visuals when kickback begins.
func _on_impact_started() -> void:
	_dazed = true
	_start_dazed_orbit_visuals()


## Exit dazed state and clear orbit visuals after kickback ends.
func _on_impact_ended() -> void:
	if is_instance_valid(self):
		_dazed = false
		_stop_dazed_orbit_visuals()


# Wall slam
## Convert a dazed wall slam above threshold speed into destruction.
func _on_body_slammed(collision: KinematicCollision2D, speed: float) -> void:
	# Ignore non-dazed, low-speed, or non-wall impacts.
	if !_dazed or speed < wall_slam_speed_min or !_is_wall(collision):
		return

	# Pass impact direction/position to damage component, then destroy.
	$CompDamage.blood_smear_enabled = true
	$CompDamage.blood_smear_direction = collision.get_normal()
	$CompDamage.blood_smear_location = collision.get_position()
	$CompDamage._instance_destroy()


## Return true when collision should count as a wall impact.
func _is_wall(collision: KinematicCollision2D) -> bool:
	# Resolve collider and filter out goblin-on-goblin impacts.
	var collider := collision.get_collider()
	if collider == null:
		return false
	if _node_or_ancestor_in_group(collider, "goblin"):
		return false
	if treat_static_as_wall and collider is StaticBody2D:
		return true
	if wall_collision_group.is_empty():
		return false
	return _node_or_ancestor_in_group(collider, wall_collision_group)

## Public helper used by other scripts to check goblin dazed state.
func is_dazed() -> bool:
	return _dazed


# Dazed orbit visuals
## Spawn orbit sprites around the goblin body for dazed feedback.
func _start_dazed_orbit_visuals() -> void:
	if !dazed_orbit_enabled or dazed_orbit_texture == null:
		return
	if !_dazed_orbit_sprites.is_empty():
		return

	# Create and configure orbit sprites.
	var count: int = max(1, dazed_orbit_count)
	for i in range(count):
		var sprite := Sprite2D.new()
		sprite.texture = dazed_orbit_texture
		sprite.scale = Vector2.ONE * max(0.01, dazed_orbit_scale)
		sprite.z_index = 100
		add_child(sprite)
		_dazed_orbit_sprites.append(sprite)

	_dazed_orbit_phase = 0.0
	_update_dazed_orbit_visuals(0.0)


## Remove all active dazed orbit sprites.
func _stop_dazed_orbit_visuals() -> void:
	for sprite in _dazed_orbit_sprites:
		if is_instance_valid(sprite):
			sprite.queue_free()
	_dazed_orbit_sprites.clear()


## Recompute orbit sprite positions and facing from center and phase.
func _update_dazed_orbit_visuals(delta: float) -> void:
	# Use CharacterBody2D as center when available.
	var body := get_node_or_null("CharacterBody2D") as Node2D
	var center: Vector2 = body.global_position if body != null else global_position
	var count: int = _dazed_orbit_sprites.size()
	if count == 0:
		return

	# Advance phase and place each sprite on the orbit circle.
	_dazed_orbit_phase += delta * dazed_orbit_speed
	for i in range(count):
		var sprite: Sprite2D = _dazed_orbit_sprites[i]
		if !is_instance_valid(sprite):
			continue
		var angle: float = _dazed_orbit_phase + (TAU * float(i) / float(count))
		sprite.global_position = center + Vector2(cos(angle), sin(angle)) * dazed_orbit_radius
		sprite.rotation = angle + PI * 0.5


# Helpers
## Return true when node or any ancestor belongs to the given group.
func _node_or_ancestor_in_group(node: Node, group: String) -> bool:
	var current: Node = node
	while current != null:
		if current.is_in_group(group):
			return true
		current = current.get_parent()
	return false
