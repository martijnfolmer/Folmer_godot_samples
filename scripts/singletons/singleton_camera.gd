extends Node2D

@export var target_group: StringName = &"player"
@export var follow_speed: float = 1200.0
@export var screen_margin_fraction: float = 1.0 / 6.0

@onready var camera: Camera2D = $Camera2D

var _target: Node2D


func _ready() -> void:
	camera.make_current()
	_resolve_target()

## Find the first player node in the tree
func _resolve_target() -> void:
	var n := get_tree().get_first_node_in_group(target_group)
	if n is Node2D:
		_target = n as Node2D
	else:
		_target = null


func _physics_process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_resolve_target()
		if _target == null:
			return

	var rect := get_viewport().get_visible_rect()
	var w: float = rect.size.x
	var h: float = rect.size.y

	var player_pos := _target.global_position
	var aim := get_global_mouse_position() - player_pos
	if aim.length_squared() > 0.0001:
		aim = aim.normalized()

	var z := camera.zoom
	var offset := Vector2(
		w * aim.x * screen_margin_fraction / z.x,
		h * aim.y * screen_margin_fraction / z.y
	)
	var desired := player_pos + offset
	
	global_position = global_position.move_toward(desired, follow_speed * delta)
