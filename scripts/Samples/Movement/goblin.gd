extends Node2D
##TODO: give the goblin a visual status effect when dazed. Little knights around the th head on horses?
##TODO: rotate collision When adding rotation (e.g. facing the player), rotate $CharacterBody2D so that sprite and collisionshape rotate
## Same kick behavior as pillar, root stays fixed, CharacterBody2D moves (and sprite follows).
## When kicked, goblin enters dazed state, if it slams a wall at sufficient speed, it becomes a blood smear.

const DEFAULT_BLOOD_SMEAR_SCENE := preload("res://scenes/Samples/particles/partBloodSmearGreenPersistent.tscn")

@export_group("Wall slam")
## Minimum speed when hitting a wall to turn into a blood smear (while dazed)
@export var wall_slam_speed_min: float = 150.0
## Colliders in this group count as walls (empty = only use treat_static_as_wall)
@export var wall_collision_group: String = "pillar"
## StaticBody2D nodes count as walls even without wall_collision_group
@export var treat_static_as_wall: bool = true
## Scene to spawn at impact point when goblin smears (particles, decal, etc.)
@export var blood_smear_scene: PackedScene

var _dazed: bool = false

func _ready() -> void:
	add_to_group("goblin")
	if blood_smear_scene == null:
		blood_smear_scene = DEFAULT_BLOOD_SMEAR_SCENE

	var kickback := get_node_or_null("CompBodyKickback")
	if kickback:
		kickback.impact_started.connect(_on_impact_started)
		kickback.impact_ended.connect(_on_impact_ended)
		kickback.body_slammed.connect(_on_body_slammed)


func _on_impact_started() -> void:
	_dazed = true


func _on_impact_ended() -> void:
	if is_instance_valid(self):
		_dazed = false


func _on_body_slammed(collision: KinematicCollision2D, speed: float) -> void:
	if !_dazed or speed < wall_slam_speed_min or !_is_wall(collision):
		return
	
	# Destroy the instance
	$CompDamage.blood_smear_enabled = true
	$CompDamage.blood_smear_direction = collision.get_normal()
	$CompDamage.blood_smear_location = collision.get_position()
	$CompDamage._instance_destroy()
	
	#_spawn_blood_smear(collision.get_position(), collision.get_normal())
	# Delete the goblin
	#queue_free()


# Check collision with a wall like object 
# TODO: dynamically make it so we can check multiple groups, walls and pillars and other goblins
func _is_wall(collision: KinematicCollision2D) -> bool:
	var collider := collision.get_collider()
	if collider == null:
		return false
	# Goblin collisions should never trigger smear death.
	if _node_or_ancestor_in_group(collider, "goblin"):
		return false
	if treat_static_as_wall and collider is StaticBody2D:
		return true
	if wall_collision_group.is_empty():
		return false
	return _node_or_ancestor_in_group(collider, wall_collision_group)

# Check if parent is in group
func _node_or_ancestor_in_group(node: Node, group: String) -> bool:
	var current: Node = node
	while current != null:
		if current.is_in_group(group):
			return true
		current = current.get_parent()
	return false

func _spawn_blood_smear(global_pos: Vector2, away_dir: Vector2) -> void:
	if blood_smear_scene == null:
		return
	var instance := blood_smear_scene.instantiate()
	var parent := get_tree().current_scene
	if parent:
		parent.add_child(instance)
		if instance.has_method("setup_impact"):
			instance.call("setup_impact", global_pos, away_dir)
		else:
			instance.global_position = global_pos
