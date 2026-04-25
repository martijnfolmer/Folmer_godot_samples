extends Node2D


const wallShardParticles_scene := preload("res://scenes/Samples/Particles/partWallShards.tscn")
const debris_scene := preload("res://scenes/Samples/Environment/debris.tscn")

@export_group("debris spawn")
## set to true if we spawn debris
@export var spawn_debris: bool = true
@export_range(1, 32, 1) var debris_spawn_count: int = 7
@export var debris_speed_min: float = 110.0
@export var debris_speed_max: float = 190.0
@export var debris_spread_degrees: float = 28.0
@export var debris_spawn_offset: float = 4.0

##set to ture if we spawn particles
@export var spawn_particles: bool = true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("wall")

func _instance_destroy(_dir : float) ->void:
	
	# create wall shards
	var direction := Vector2(cos(_dir), sin(_dir))
	direction = direction.normalized()
	
	if spawn_particles:
		spawn_wall_shards(global_position, direction)
	if spawn_debris:
		spawn_wall_debris(global_position, direction)
	
	 #Free children
	for child in get_children():
		child.queue_free()
	queue_free()



## Spawn a directional blood smear effect aligned away from impact direction.
func spawn_wall_shards(global_pos: Vector2, away_dir: Vector2) -> void:
	# Respect effect enable flag and scene availability.
	if wallShardParticles_scene == null:
		return
	var instance := wallShardParticles_scene.instantiate()
	var parent := get_tree().current_scene
	if parent:
		# Spawn and initialize directional impact behavior.
		parent.add_child(instance)
		if instance.has_method("setup_impact"):
			instance.call("setup_impact", global_pos, away_dir)
		else:
			instance.global_position = global_pos

		# Duplicate particle material so per-instance tint changes are isolated (important for blood)
		if instance is GPUParticles2D and instance.process_material != null:
			instance.process_material = instance.process_material.duplicate(true)


func spawn_wall_debris(global_pos: Vector2, away_dir: Vector2) -> void:
	if debris_scene == null:
		return

	var parent := get_tree().current_scene
	if parent == null:
		return

	var launch_base := away_dir.normalized()
	if launch_base.length_squared() <= 0.0:
		launch_base = Vector2.RIGHT

	for i in debris_spawn_count:
		var instance := debris_scene.instantiate()
		if instance == null:
			continue

		if instance is Node2D:
			var launch_dir := launch_base.rotated(deg_to_rad(randf_range(-debris_spread_degrees, debris_spread_degrees)))
			var launch_speed := randf_range(debris_speed_min, debris_speed_max)

			if instance.has_method("setup_launch"):
				instance.call("setup_launch", launch_dir, launch_speed, 0)

			parent.add_child(instance)
			instance.global_position = global_pos + launch_dir * debris_spawn_offset

			if !instance.has_method("setup_launch") and instance.has_method("add_velocity"):
				instance.call("add_velocity", launch_dir * launch_speed)
		else:
			parent.add_child(instance)
