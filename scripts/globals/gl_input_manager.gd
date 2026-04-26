extends Node

"""
	Usage : 
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
"""


# Choose what you want to add
@export var add_keys := true
@export var add_mouse_buttons := true

func _ready() -> void:
	ensure_default_inputs(add_keys, add_mouse_buttons)

func ensure_default_inputs(use_keys: bool = true, use_mouse: bool = true) -> void:
	ensure_actions()

	if use_keys:
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

		# TODO: Remove testing input key presses
		_add_key_if_missing("ui_test_space", KEY_SPACE)
		_add_key_if_missing("ui_test_v", KEY_V)
		_add_key_if_missing("ui_test_k", KEY_K)
		_add_key_if_missing("ui_test_b", KEY_B)
		

	if use_mouse:
		_add_mouse_button_if_missing("ui_primary_action", MOUSE_BUTTON_LEFT)

func ensure_actions() -> void:
	_ensure_action("ui_up")
	_ensure_action("ui_down")
	_ensure_action("ui_left")
	_ensure_action("ui_right")
	_ensure_action("ui_primary_action")
	
	# TODO: Remove testing input key presses
	_ensure_action("ui_test_space")
	_ensure_action("ui_test_v")
	_ensure_action("ui_test_k")
	_ensure_action("ui_test_b")
	
	

func _ensure_action(action_name: StringName) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

func _add_key_if_missing(action_name: StringName, keycode: Key) -> void:
	# Avoid duplicates
	for existing in InputMap.action_get_events(action_name):
		if existing is InputEventKey and (existing as InputEventKey).keycode == keycode:
			return

	var ev := InputEventKey.new()
	ev.keycode = keycode
	InputMap.action_add_event(action_name, ev)

func _add_mouse_button_if_missing(action_name: StringName, mouse_button: MouseButton) -> void:
	# Avoid duplicates
	for existing in InputMap.action_get_events(action_name):
		if existing is InputEventMouseButton and (existing as InputEventMouseButton).button_index == mouse_button:
			return

	var ev := InputEventMouseButton.new()
	ev.button_index = mouse_button
	InputMap.action_add_event(action_name, ev)
