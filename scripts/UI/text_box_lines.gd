extends Control

signal finished
signal line_started(index: int)

@export var tick_interval: float = 0.03
@export var chars_per_tick: int = 1
@export var advance_action: StringName = &"ui_accept"

@onready var _label: Label = %Label
@onready var _type_timer: Timer = %TypeTimer

var _lines: PackedStringArray = []
var _line_index: int = 0
var _active: bool = false
var _typing: bool = false


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	_type_timer.one_shot = false
	_type_timer.timeout.connect(_on_type_timer_timeout)
	_sync_timer_wait_time()
	visible = false
	_label.visible_characters = -1


func _sync_timer_wait_time() -> void:
	_type_timer.wait_time = maxf(tick_interval, 0.001)


## Shows the control and types out each non-empty entry. Empty or whitespace-only strings are skipped.
func start_lines(lines: PackedStringArray) -> void:
	_lines = lines.duplicate()
	_line_index = 0
	_active = true
	_sync_timer_wait_time()
	visible = true
	_type_timer.stop()
	grab_focus()
	_begin_current_line()


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if not event.is_action_pressed(advance_action):
		return
	get_viewport().set_input_as_handled()
	_on_advance_pressed()


func _on_advance_pressed() -> void:
	if _typing:
		_skip_current_line()
	else:
		_line_index += 1
		_begin_current_line()


func _skip_current_line() -> void:
	_typing = false
	_type_timer.stop()
	_label.visible_characters = -1


func _on_type_timer_timeout() -> void:
	if not _typing or not _active:
		return
	var total: int = _label.get_total_character_count()
	if total <= 0:
		_typing = false
		_type_timer.stop()
		_label.visible_characters = -1
		return
	var next_v: int = _label.visible_characters
	if next_v < 0:
		next_v = total
	else:
		next_v = mini(next_v + chars_per_tick, total)
	_label.visible_characters = next_v
	if next_v >= total:
		_typing = false
		_label.visible_characters = -1
		_type_timer.stop()


func _begin_current_line() -> void:
	while _line_index < _lines.size():
		var line: String = _lines[_line_index]
		if line.strip_edges().is_empty():
			_line_index += 1
			continue
		line_started.emit(_line_index)
		_label.text = line
		var total: int = _label.get_total_character_count()
		if total <= 0:
			_label.visible_characters = -1
			_typing = false
			_type_timer.stop()
			return
		_label.visible_characters = 0
		_typing = true
		_type_timer.start()
		return
	_finish()


func _finish() -> void:
	if not _active:
		return
	_active = false
	_typing = false
	_type_timer.stop()
	visible = false
	_label.text = ""
	_label.visible_characters = -1
	finished.emit()
