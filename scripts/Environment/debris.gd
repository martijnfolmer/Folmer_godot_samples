extends Node2D

@export_enum("wall", "glass") var cat = 0

@export_group("wall textures")
@export var sprite_wall_1 : Texture2D
@export var sprite_wall_2 : Texture2D
@export var sprite_wall_3 : Texture2D

@export_group("glass textures")
@export var sprite_glass_1 : Texture2D
@export var sprite_glass_2 : Texture2D
@export var sprite_glass_3 : Texture2D

@export_group("visual")
## Spawn scale used the moment debris appears.
@export var ini_scale : float = 0.5
## Scale reached shortly after spawn.
@export var target_scale: float = 0.1
## Duration for scale settle phase.
@export var scale_settle_duration_sec: float = 0.5
## Random initial spin range.
@export var initial_spin_speed_min: float = -12.0
@export var initial_spin_speed_max: float = 12.0

@export_group("movement")
## Translation friction while ON_CELL.
@export var friction : float = 0.9
## minimum velocity, below which it stops
@export var min_velocity : float = 1.0
## Rotation friction while ON_CELL.
@export var rotation_friction: float = 0.9
## minimum rotation, below which it stops
@export var min_angular_velocity: float = 1.0

@export_group("falling")
@export var falling_rotation_step: float = 0.1
@export var falling_scale_step: float = 0.01

@export_group("cell overlap")
@export_flags_2d_physics var floor_collision_mask: int = 2

@export_group("Collisions")
@export var body_path : NodePath
@onready var parentBody := get_node_or_null(body_path) as CharacterBody2D

var sprite: Sprite2D
var texture_1 : Texture2D
var texture_2 : Texture2D
var texture_3 : Texture2D

var velocity : Vector2 = Vector2.ZERO
var angular_velocity: float = 0.0
var _has_launch_velocity: bool = false
var _launch_velocity: Vector2 = Vector2.ZERO
var _scale_settle_elapsed: float = 0.0
var _scale_settle_done: bool = false
var _collision_checks_enabled: bool = true

var _state : Enums.GroundState = Enums.GroundState.ON_CELL

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("debris")

	_create_debris_sprite()
	_set_scale(ini_scale)
	rotation = 0.0
	if sprite != null:
		sprite.rotation = randf() * 2.0 * PI
	angular_velocity = randf_range(initial_spin_speed_min, initial_spin_speed_max)

	if _has_launch_velocity:
		velocity += _launch_velocity
		_has_launch_velocity = false
	else:
		velocity = Vector2(
			(randf() * 2.0 - 1.0) * 100.0,
			(randf() * 2.0 - 1.0) * 100.0
		)

func setup_launch(away_dir: Vector2, launch_speed: float, debris_cat: int = -1) -> void:
	var launch_dir := away_dir.normalized()
	if !launch_dir.is_finite() or launch_dir.length_squared() <= 0.0:
		launch_dir = Vector2.RIGHT

	_launch_velocity = launch_dir * maxf(0.0, launch_speed)
	_has_launch_velocity = true

	if debris_cat >= 0:
		cat = debris_cat
		if sprite != null:
			_set_debris_sprite()

	if is_node_ready():
		velocity += _launch_velocity
		_has_launch_velocity = false


func _create_debris_sprite() -> void:
	# get the sprite2D
	sprite = get_node_or_null("CharacterBody2D/Sprite2D")
	if sprite == null:
		sprite = get_node_or_null("Sprite2D")

	if sprite == null:
		sprite = Sprite2D.new()
		if parentBody != null:
			parentBody.add_child(sprite)
		else:
			add_child(sprite)

	_ensure_sprite_pivot()
	_set_debris_sprite()

func _set_debris_sprite() -> void:
	
	if cat ==0:
		texture_1 = sprite_wall_1
		texture_2 = sprite_wall_2
		texture_3 = sprite_wall_3
	else:
		texture_1 = sprite_glass_1
		texture_2 = sprite_glass_2
		texture_3 = sprite_glass_3
	
	
	# edge case if we set no sprites
	if texture_1 == null and texture_2 == null and texture_3 == null:
		return
	
	# choose a random sprite from the texture 2D	
	sprite.texture = texture_1
	
	var all_sprites = []
	if texture_1!= null:
		all_sprites.append(texture_1)
	if texture_2 != null:
		all_sprites.append(texture_2)
	if texture_3 != null:
		all_sprites.append(texture_3)
	
	var choice_index = randi() % all_sprites.size()
	sprite.texture = all_sprites[choice_index]
	_ensure_sprite_pivot()

func _ensure_sprite_pivot() -> void:
	if sprite == null:
		return
	sprite.centered = true
	sprite.offset = Vector2.ZERO

func _set_scale(_scale: float) -> void:
	if sprite != null:
		sprite.scale = Vector2(_scale, _scale)
	else:
		scale = Vector2(_scale, _scale)


func _process(delta: float) -> void:
	if _state == Enums.GroundState.ON_CELL:
		_process_scale_settle(delta)
		_refresh_floor_state()

	_process_velocity_and_rotation(delta)
	_process_falling()


func _process_scale_settle(delta: float) -> void:
	if _scale_settle_done:
		return

	if scale_settle_duration_sec <= 0.0:
		_set_scale(target_scale)
		_scale_settle_done = true
		return

	_scale_settle_elapsed = minf(scale_settle_duration_sec, _scale_settle_elapsed + delta)
	var t := _scale_settle_elapsed / scale_settle_duration_sec
	_set_scale(lerpf(ini_scale, target_scale, t))
	if t >= 1.0:
		_scale_settle_done = true


func _process_velocity_and_rotation(delta: float) -> void:
	
	if _state == Enums.GroundState.ON_CELL:
		velocity -= velocity * friction * delta
		angular_velocity -= angular_velocity * rotation_friction * delta

	if velocity.length() <= min_velocity:
		velocity = Vector2.ZERO
	if absf(angular_velocity) <= min_angular_velocity:
		angular_velocity = 0.0

	if sprite != null:
		sprite.rotation += angular_velocity * delta

	if _state != Enums.GroundState.ON_CELL:
		return
	if velocity == Vector2.ZERO:
		return

	if parentBody == null:
		position += velocity * delta
		return

	var motion := velocity * delta
	if !_collision_checks_enabled:
		position += motion
		return

	var collision := parentBody.move_and_collide(motion)
	_sync_root_to_body()
	if collision != null:
		velocity = Vector2.ZERO
		angular_velocity = 0.0
		_collision_checks_enabled = false


func _process_falling() -> void:
	if _state == Enums.GroundState.ON_CELL:
		return

	if sprite != null:
		sprite.rotation += falling_rotation_step
	else:
		rotation += falling_rotation_step

	if sprite != null:
		sprite.scale.x = move_toward(sprite.scale.x, 0.0, falling_scale_step)
		sprite.scale.y = move_toward(sprite.scale.y, 0.0, falling_scale_step)
		if sprite.scale.x <= 0.01:
			queue_free()
		return

	scale.x = move_toward(scale.x, 0.0, falling_scale_step)
	scale.y = move_toward(scale.y, 0.0, falling_scale_step)
	if scale.x <= 0.01:
		queue_free()


func _refresh_floor_state() -> void:
	if _state != Enums.GroundState.ON_CELL:
		return
	if !_is_colliding_with_cell_square():
		_state = Enums.GroundState.FALLING


func _sync_root_to_body() -> void:
	if parentBody == null:
		return
	if parentBody.position != Vector2.ZERO:
		global_position += parentBody.position
		parentBody.position = Vector2.ZERO


## Return true when this debris overlaps a cell_square area.
func _is_colliding_with_cell_square() -> bool:
	if floor_collision_mask == 0:
		return false

	var world := get_world_2d()
	if world == null:
		return false

	var query := PhysicsPointQueryParameters2D.new()
	if parentBody != null:
		query.position = parentBody.global_position
	else:
		query.position = global_position
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = floor_collision_mask

	var hits := world.direct_space_state.intersect_point(query, 8)
	for hit in hits:
		var collider = hit.get("collider")
		if collider is Area2D and _is_cell_area(collider):
			return true

	return false


func _is_cell_area(area: Area2D) -> bool:
	return _node_or_ancestor_in_group(area, "cell_floor") != null


func _node_or_ancestor_in_group(node: Node, group_name: StringName) -> Node:
	var current: Node = node
	while current != null:
		if current.is_in_group(group_name):
			return current
		current = current.get_parent()
	return null
