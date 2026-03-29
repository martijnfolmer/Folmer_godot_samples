extends Node2D


const glassShardParticles_scene := preload("res://scenes/Samples/Particles/partGlassShards.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("glass")

func _instance_destroy(_dir : float) ->void:
	
	# create glass shards
	var direction = Vector2(cos(_dir), sin(_dir))
	
	# Normalize the vector (optional, but ensures length = 1)
	direction = direction.normalized()
	spawn_glass_shards(global_position, direction, Color.WHITE)
	
	 #Free children
	for child in get_children():
		child.queue_free()
	queue_free()



## Spawn a directional blood smear effect aligned away from impact direction.
func spawn_glass_shards(global_pos: Vector2, away_dir: Vector2, color: Color = Color.GREEN) -> void:
	# Respect effect enable flag and scene availability.
	if glassShardParticles_scene == null:
		return
	var instance := glassShardParticles_scene.instantiate()
	var parent := get_tree().current_scene
	if parent:
		# Spawn and initialize directional impact behavior.
		parent.add_child(instance)
		if instance.has_method("setup_impact"):
			instance.call("setup_impact", global_pos, away_dir)
		else:
			instance.global_position = global_pos

		# Duplicate particle material so per-instance tint changes are isolated.
		if instance is GPUParticles2D and instance.process_material != null:
			instance.process_material = instance.process_material.duplicate(true)
			if instance.process_material is ParticleProcessMaterial:
				var shard_mat := instance.process_material as ParticleProcessMaterial
				shard_mat.color = color
				shard_mat.scale_min *= 0.3
				shard_mat.scale_max *= 0.3
