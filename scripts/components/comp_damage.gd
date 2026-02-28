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

var hp_c: int
var _shake_timer: float = 0.0
var _origin_pos: Vector2

func _ready() -> void:
	hp_c = hp_total
	set_process(false)

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
	var parent := get_parent()
	for child in parent.get_children():
		child.queue_free()
	parent.queue_free()
