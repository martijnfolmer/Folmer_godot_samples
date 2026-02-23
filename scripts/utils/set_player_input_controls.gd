extends Node

func _ready() -> void:
	ensure_keyboard_dpad()


func ensure_keyboard_dpad() -> void:
	_ensure_action("ui_up")
	_ensure_action("ui_down")
	_ensure_action("ui_left")
	_ensure_action("ui_right")

	# WASD
	_add_key_if_missing("ui_up", KEY_W)
	_add_key_if_missing("ui_down", KEY_S)
	_add_key_if_missing("ui_left", KEY_A)
	_add_key_if_missing("ui_right", KEY_D)

	# Arrow keys
	_add_key_if_missing("ui_up", KEY_UP)
	_add_key_if_missing("ui_down", KEY_DOWN)
	_add_key_if_missing("ui_left", KEY_LEFT)
	_add_key_if_missing("ui_right", KEY_RIGHT)


func _ensure_action(action_name: StringName) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

func _add_key_if_missing(action_name: StringName, keycode: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode

	# Avoid duplicates
	for existing in InputMap.action_get_events(action_name):
		if existing is InputEventKey and (existing as InputEventKey).keycode == keycode:
			return

	InputMap.action_add_event(action_name, ev)
