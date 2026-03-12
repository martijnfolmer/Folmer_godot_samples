extends Node

@export_group("Health")
## Maximum hit points
@export var hp_total: int = 10

@export_group("Shake")
## Initial pixel offset amplitude when damaged
@export var shake_intensity: float = 8.0
## How long the shake lasts (seconds)
@export var shake_duration: float = 0.4
## Oscillations per second during shake
@export var shake_frequency: float = 30.0

const DEFAULT_BLOOD_SMEAR_SCENE := preload("res://scenes/Samples/particles/partBloodSmearGreenPersistent.tscn")


var hp_c: int
var _shake_timer: float = 0.0
var _origin_pos: Vector2

# Blood smear after death
var blood_smear_scene: PackedScene		# the particles which are the blood smear
var blood_smear_enabled: bool = true		# if set to true, we create the blood smear on death
var blood_smear_direction = null			# Direction of the blood smear
var blood_smear_location = null			# Location of the blood smear

func _ready() -> void:
	hp_c = hp_total
	set_process(false)
	
	# Set the default blood smear scene
	if blood_smear_scene == null:
		blood_smear_scene = DEFAULT_BLOOD_SMEAR_SCENE

func take_damage(amount: int) -> void:
	if amount == 0:
		return
	hp_c -= amount
	if hp_c <= 0:
		_instance_destroy()
		return
	_start_shake()

func _start_shake() -> void:
	_origin_pos = get_parent().position
	_shake_timer = shake_duration
	set_process(true)

func _process(delta: float) -> void:
	_shake_timer -= delta
	if _shake_timer <= 0.0:
		get_parent().position = _origin_pos
		set_process(false)
		return

	var decay: float = _shake_timer / shake_duration
	var amplitude: float = shake_intensity * decay
	var offset := Vector2(
		randf_range(-amplitude, amplitude),
		randf_range(-amplitude, amplitude)
	)
	get_parent().position = _origin_pos + offset

func _instance_destroy() -> void:
	
	
	# create the blood smear upon death
	if blood_smear_location == null:
		var sibling = get_characterbody2d_sibling()
		if sibling == null:
			blood_smear_location = get_parent().global_position
		else:
			blood_smear_location = sibling.global_position

	# either spawn omni-directional or directional blood smear
	if blood_smear_direction == null:
		spawn_blood_smear(blood_smear_location)
	else:
		spawn_blood_smear_directional(blood_smear_location, blood_smear_direction)

	# queue free self and all others
	var parent := get_parent()
	for child in parent.get_children():
		child.queue_free()
	parent.queue_free()


################################
# Find siblings
################################
func get_characterbody2d_sibling() -> CharacterBody2D:
	var parent := get_parent()
	if parent == null:
		return null

	for child in parent.get_children():
		if child != self and child is CharacterBody2D:
			return child

	return null




#################################
# Blood smear after death
#################################
	
# directional blood splatter
func spawn_blood_smear_directional(global_pos: Vector2, away_dir: Vector2) -> void:
	
	# if the blood smear exists
	if blood_smear_scene == null or not blood_smear_enabled:
		return
	var instance := blood_smear_scene.instantiate()
	var parent := get_tree().current_scene
	if parent:
		parent.add_child(instance)
		if instance.has_method("setup_impact"):
			instance.call("setup_impact", global_pos, away_dir)
		else:
			instance.global_position = global_pos
		
		# create color
		if instance.has_method("setup_color"):
			instance.call("setup_color", Color.GREEN)
			

# Omni directional blood splatter
func spawn_blood_smear(global_pos: Vector2) -> void:
	
	# if the blood smear exists
	if blood_smear_scene == null or not blood_smear_enabled:
		return
	var instance := blood_smear_scene.instantiate()
	var parent := get_tree().current_scene
	if parent:
		parent.add_child(instance)
		instance.global_position = global_pos
	
