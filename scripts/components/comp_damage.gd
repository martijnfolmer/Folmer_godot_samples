extends Node

@export_group("Health")
@export var hp_total: int = 10

@export_group("Shake")
@export var shake_intensity: float = 8.0
@export var shake_duration: float = 0.4
@export var shake_frequency: float = 30.0

@export_group("Blood smear")
@export var blood_smear_enabled: bool = true
@export var blood_smear_color: Color = Color.GREEN

const DEFAULT_BLOOD_SMEAR_SCENE := preload("res://scenes/Samples/particles/partBloodSmearGreenPersistent.tscn")

var hp_c: int
var _shake_timer: float = 0.0
var _origin_pos: Vector2

var blood_smear_scene: PackedScene
var blood_smear_direction = null
var blood_smear_location = null

################
# Initialization
################
## Initialize health state and default blood smear resource.
func _ready() -> void:
	# Start with full health and disable shake processing until needed.
	hp_c = hp_total
	set_process(false)

	# Use the default smear scene when none was injected in-editor.
	if blood_smear_scene == null:
		blood_smear_scene = DEFAULT_BLOOD_SMEAR_SCENE

#################################################################
# Processing
##################################################################

func _process(delta: float) -> void:
	
	# Shake if we are damaged
	_shaking(delta)




################
# Shake feedback
################
## Begin the short random shake effect on the parent node.
func _start_shake() -> void:
	# Capture original position so it can be restored when shake ends.
	_origin_pos = get_parent().position
	_shake_timer = shake_duration
	set_process(true)

## Update the active shake effect and decay amplitude over time.
func _shaking(delta: float) -> void:
	_shake_timer -= delta
	if _shake_timer <= 0.0:
		get_parent().position = _origin_pos
		set_process(false)
		return

	# Compute decayed random offset and apply to parent.
	var decay: float = _shake_timer / shake_duration
	var amplitude: float = shake_intensity * decay
	var offset := Vector2(
		randf_range(-amplitude, amplitude),
		randf_range(-amplitude, amplitude)
	)
	get_parent().position = _origin_pos + offset


###################
# Getting damaged
###################

## Apply damage and trigger shake or destruction depending on remaining HP.
func take_damage(amount: int) -> void:
	if amount == 0:
		return
	
	# Reduce health first, then branch to death or hit feedback.
	hp_c -= amount
	if hp_c <= 0:
		_instance_destroy()
		return
	_start_shake()


###############################
# Destruction of the instance
###############################
## Spawn configured blood smear and delete the owning entity hierarchy.
func _instance_destroy() -> void:
	
	# Find out where the blood smear should be
	if blood_smear_location == null:
		var sibling = get_characterbody2d_sibling()
		if sibling == null:
			blood_smear_location = get_parent().global_position
		else:
			blood_smear_location = sibling.global_position

	# Spawn directional or omni smear depending on available direction
	if blood_smear_direction == null:
		spawn_blood_smear(blood_smear_location, blood_smear_color)
	else:
		spawn_blood_smear_directional(blood_smear_location, blood_smear_direction, blood_smear_color)

	# Free parent and children to remove this full entity instance.
	var parent := get_parent()
	for child in parent.get_children():
		child.queue_free()
	parent.queue_free()



##############
# Generate Blood smear upon death
#############

## Spawn a directional blood smear effect aligned away from impact direction.
func spawn_blood_smear_directional(global_pos: Vector2, away_dir: Vector2, color: Color = Color.GREEN) -> void:
	# Respect effect enable flag and scene availability.
	if blood_smear_scene == null or not blood_smear_enabled:
		return
	var instance := blood_smear_scene.instantiate()
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
			instance.process_material.color = color

## Spawn an omni-directional blood smear effect at a world position.
func spawn_blood_smear(global_pos: Vector2, color: Color = Color.GREEN) -> void:
	# Respect effect enable flag and scene availability.
	if blood_smear_scene == null or not blood_smear_enabled:
		return
	var instance := blood_smear_scene.instantiate()
	var parent := get_tree().current_scene
	if parent:
		# Spawn effect and place it at the requested position.
		parent.add_child(instance)
		instance.global_position = global_pos
		# Configure particle parameters for a full circular spread.
		if instance is GPUParticles2D and instance.process_material != null:
			instance.process_material = instance.process_material.duplicate(true)
			instance.process_material.spread = 360.0
			instance.process_material.color = color
		instance.amount = 150


###########
# Helpers
###########
## Return the first CharacterBody2D sibling under the same parent, if any.
func get_characterbody2d_sibling() -> CharacterBody2D:
	var parent := get_parent()
	if parent == null:
		return null

	for child in parent.get_children():
		if child != self and child is CharacterBody2D:
			return child

	return null
