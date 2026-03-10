extends GPUParticles2D

@export var wall_push_offset: float = 6.0

func _ready() -> void:
	# Emit once. Particles use high damping and long lifetime, so they settle and remain visible.
	one_shot = true
	restart()
	emitting = true


func setup_impact(impact_global_pos: Vector2, away_from_surface: Vector2) -> void:
	var away_dir := away_from_surface.normalized()
	if away_dir.length_squared() == 0.0:
		away_dir = Vector2.RIGHT

	global_position = impact_global_pos + away_dir * wall_push_offset
	rotation = away_dir.angle()
