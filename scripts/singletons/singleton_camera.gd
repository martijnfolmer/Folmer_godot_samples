extends Node2D

@export var target_group: StringName = &"player"
@export var follow_speed: float = 1200.0
@export var screen_margin_fraction: float = 1.0 / 6.0

@onready var camera: Camera2D = $Camera2D

var _target: Node2D

var _shake_time_left: float = 0.0
var _shake_duration: float = 0.0
var _shake_magnitude: float = 0.0


func _ready() -> void:
	camera.make_current()
	_resolve_target()


## Stack or intensify shake: keeps the stronger magnitude and longer remaining duration.
func add_screen_shake(magnitude_pixels: float, duration_sec: float) -> void:
	if duration_sec <= 0.0:
		return
	_shake_magnitude = maxf(_shake_magnitude, magnitude_pixels)
	_shake_duration = maxf(_shake_duration, duration_sec)
	_shake_time_left = maxf(_shake_time_left, duration_sec)


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

	if _target != null and is_instance_valid(_target):
		var rect := get_viewport().get_visible_rect()
		var w: float = rect.size.x
		var h: float = rect.size.y

		var player_pos := _target.global_position
		var aim := get_global_mouse_position() - player_pos
		if aim.length_squared() > 0.0001:
			aim = aim.normalized()

		var z := camera.zoom
		var framing := Vector2(
			w * aim.x * screen_margin_fraction / z.x,
			h * aim.y * screen_margin_fraction / z.y
		)
		var desired := player_pos + framing
		global_position = global_position.move_toward(desired, follow_speed * delta)

	if _shake_time_left > 0.0:
		_shake_time_left = maxf(_shake_time_left - delta, 0.0)
		if _shake_time_left <= 0.0:
			camera.offset = Vector2.ZERO
			_shake_magnitude = 0.0
			_shake_duration = 0.0
		else:
			var strength: float = clampf(
				_shake_time_left / maxf(_shake_duration, 0.0001),
				0.0,
				1.0
			)
			var ang := randf() * TAU
			camera.offset = Vector2.from_angle(ang) * _shake_magnitude * strength


#TODO: TESTING: make screenshake happen
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_B:
			add_screen_shake(50, 3)
