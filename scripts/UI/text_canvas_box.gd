extends Control
class_name TextCanvasBox


enum txtState {MOVE_IN, MOVE_OUT, IDLE, SCROLLING, COMPLETE, NEXTLINE}
enum scaleState {SCALE_UP, SCALE_DOWN}


var PROCESS_TEXT: bool = false # check the text for changing font scales and usch


## Full texts to show, revealed one character at a time
@export var display_texts: Array[String] = ["Sample text"]:
	set(value):
		display_texts = value
		_current_text_index = 0
		_current_char_index = 0
		_apply_text()

## How fast to cycle through the next character
@export var update_interval: float = 0.1
## How far to move off screen (x coordinate)
@export var diff_x: float = 0.0
## how far to move off screen (y coordinate)
@export var diff_y: float = 160.0

@export_group("Scaling and Value change when talking")
## scale for the portrait when it is not the one talking
@export var scale_start: float = 0.8
## scale for the portrait when it is the one talking
@export var scale_end: float = 1.0
## how fast the scale changes
@export var scale_time: float = 0.1
## how much to darken the portrait when not talking
@export var modulate_value: float = 0.7

@export_group("Shaking the portrait when [shake] tag is used")
## How long to shake if the [shake] tag is used in txt
@export var shake_timer: float = 3.0
## Maximum shake
@export var shake_tot: float = 50

@export_group("Rotating the portrait when [rotate] tag is used")
## How long to rotate if the [rotate] tag is used in txt
@export var rotate_timer: float = 1.0
## Maximum amplitude (degrees)
@export var rotate_amplitude: float = 30
## How fast to move a single sinus cycle
@export var rotate_time_per_cycle: float = 0.5

@export_group("Font sizes for [big] and [small] tags")
## Font size when we yell
@export var font_big_size: int = 50
## Font size when we whisper
@export var font_small_size: int = 20
## Font size for normal conversation
@export var font_normal_size: int = 40

@export_group("HUD layout (when parent is CanvasLayer)")
@export var hud_margin_x: float = 30.0
@export var hud_margin_bottom: float = 20.0
@export var hud_bar_height: float = 200.0


var _label: Label
var _timer: Timer
var _current_text_index: int = 0
var _current_char_index: int = 0

var _sfx: Node
var _tick_sound: String = "hit1" # the sound that each letter makes

var move_in_t1: float = 0.00
var move_in_t2: float = 0.5
var move_in_y1: float
var move_in_y2: float
var move_in_x1: float
var move_in_x2: float

var move_out_t1: float = 0.00
var move_out_t2: float = 0.5
var move_out_y1: float
var move_out_y2: float
var move_out_x1: float
var move_out_x2: float

# scaling when talking or not
var p1_scale: float = scale_start
var p2_scale: float = scale_start
var p1_scale_t: float = 0.0
var p2_scale_t: float = 0.0
var p1_scale_state: scaleState = scaleState.SCALE_DOWN
var p2_scale_state: scaleState = scaleState.SCALE_DOWN

# turning brighter and darker when talking or not
var p1_modulate_v: float = modulate_value
var p2_modulate_v: float = modulate_value

# Shaking a portrait if the [shake] tag is used
var p1_shake_timer: float = 0.0
var p2_shake_timer: float = 0.0

# rotating the portrait if the [rotate] tag is used
var p1_rotate_timer: float = 0.0
var p2_rotate_timer: float = 0.0

# The current state of the textbox
var _state: txtState = txtState.IDLE


###################################
## Lifecycle
###################################

## Set up label, timer, layout, portrait defaults, and textbox entrance state.
func _ready() -> void:
	# Get the label child node
	_label = %Label
	_label.add_theme_font_size_override("font_size", font_normal_size)

	# Get the sfx singleton
	_sfx = _get_sfx_singleton()

	# Timer which governs how fast text
	_timer = Timer.new()
	_timer.wait_time = update_interval
	_timer.autostart = false
	_timer.one_shot = false
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)
	_apply_text()

	if _is_hud_canvas():
		set_anchors_preset(Control.LayoutPreset.PRESET_TOP_LEFT)
		_layout_hud_in_viewport()
		get_viewport().size_changed.connect(_on_viewport_size_changed)

	_refresh_move_keyframes()

	position.x = move_in_x1
	position.y = move_in_y1
	_state = txtState.MOVE_IN

	# scale of the portrait left and right
	$P1.scale.x = p1_scale
	$P1.scale.y = p1_scale

	$P2.scale.x = -p2_scale
	$P2.scale.y = p2_scale

	$P1.modulate = Color(modulate_value, modulate_value, modulate_value, 1.0)
	$P2.modulate = Color(modulate_value, modulate_value, modulate_value, 1.0)


## Update textbox movement, portrait scaling, shaking, and rotation every frame.
func _process(delta: float) -> void:
	# Move the text box in and out of view
	_process_move_in_out(delta)

	# scale the portraits based on who is talking, along with darkening/lightening
	_process_portrait_scale(delta)

	# Shaking if [shake] tag was passed on
	_process_shaking(delta)

	# rotating if [rotate] tag was passed on
	_process_rotate(delta)


## Handle player input for starting, skipping, and advancing dialogue.
func _unhandled_input(event: InputEvent) -> void:
	if _is_space_pressed(event):
		# if we are idle, start it (we haven't started the text yet)
		if _state == txtState.IDLE:
			_timer.start()
			_state = txtState.SCROLLING
			PROCESS_TEXT = true
		# we are currently scrolling the text, but we want to end the next line
		elif _state == txtState.SCROLLING:
			_timer.stop()
			_current_char_index = -1
			_apply_text()
			_state = txtState.COMPLETE
		elif _state == txtState.COMPLETE:
			_current_text_index += 1
			_current_char_index = 0
			_timer.start()
			_state = txtState.SCROLLING
			PROCESS_TEXT = true


###################################
## Layout / HUD
###################################

## Return true if this textbox is placed under a CanvasLayer HUD parent.
func _is_hud_canvas() -> bool:
	return get_parent() is CanvasLayer


## Position and size the textbox inside the viewport as a HUD element.
func _layout_hud_in_viewport() -> void:
	var vp := get_viewport().get_visible_rect().size
	var inner_width: float = maxf(0.0, vp.x - hud_margin_x * 2.0)
	size = Vector2(inner_width, hud_bar_height)
	position = Vector2(hud_margin_x, vp.y - hud_bar_height - hud_margin_bottom)


## Refresh movement keyframes based on the current textbox position.
func _refresh_move_keyframes() -> void:
	move_in_x1 = position.x + diff_x
	move_in_y1 = position.y + diff_y
	move_in_x2 = position.x
	move_in_y2 = position.y

	move_out_x1 = position.x
	move_out_y1 = position.y
	move_out_x2 = position.x + diff_x
	move_out_y2 = position.y + diff_y


## Re-layout and re-anchor the textbox when the viewport size changes.
func _on_viewport_size_changed() -> void:
	if not _is_hud_canvas():
		return

	_layout_hud_in_viewport()
	_refresh_move_keyframes()

	if _state == txtState.IDLE or _state == txtState.SCROLLING or _state == txtState.COMPLETE:
		position.x = move_in_x2
		position.y = move_in_y2


###################################
## Dialogue setup
###################################

## Pass on the conversation, [p1],[p2],[small],[large],[rotate],[shake]
func set_box_texts(texts: Array[String]) -> void:
	display_texts = texts
	_current_text_index = 0
	_current_char_index = 0
	_apply_text()


###################################
## Text progression
###################################

## Reveal the next character, complete the line, or move the textbox out when done.
func _on_timer_timeout() -> void:
	if display_texts.is_empty():
		return

	if _current_text_index >= len(display_texts):
		_apply_text()
		_state = txtState.MOVE_OUT
		return

	var current_text: String = display_texts[_current_text_index]

	if _current_char_index < current_text.length():
		_current_char_index += 1

		# play the tikking sound
		if _sfx != null and _sfx.has_method("play_sfx_rand_pitch"):
			_sfx.play_sfx_rand_pitch(_tick_sound)
	else:
		_state = txtState.COMPLETE
		_timer.stop()

	_apply_text()


## Apply the currently visible portion of the active text to the label.
func _apply_text() -> void:
	var label: Label = _label
	if label == null and is_inside_tree():
		label = get_node_or_null("MarginContainer/Label") as Label
		_label = label

	if label:
		if display_texts.is_empty():
			label.text = ""
		else:
			if _current_text_index >= len(display_texts):
				label.text = ""
				_state = txtState.MOVE_OUT
				return

			var current_text: String = display_texts[_current_text_index]

			# find out what changes we need to make to the portraits, font, etc
			if PROCESS_TEXT:
				_process_txt(current_text)
				PROCESS_TEXT = false

			# we process the text here
			current_text = _clean_txt(current_text)

			label.text = current_text.substr(0, _current_char_index)


## Parse speaker and effect tags to update portrait state and font size.
func _process_txt(txt: String) -> void:
	if txt.contains("[p2]"):
		p1_scale_state = scaleState.SCALE_DOWN
		p2_scale_state = scaleState.SCALE_UP

		if txt.contains("[shake]"):
			p2_shake_timer = shake_timer
		if txt.contains("[rotate]"):
			p2_rotate_timer = rotate_timer

	elif txt.contains("[p1]"):
		p1_scale_state = scaleState.SCALE_UP
		p2_scale_state = scaleState.SCALE_DOWN

		if txt.contains("[shake]"):
			p1_shake_timer = shake_timer
		if txt.contains("[rotate]"):
			p1_rotate_timer = rotate_timer

	if txt.contains("[big]"):
		_label.add_theme_font_size_override("font_size", font_big_size)
	elif txt.contains("[small]"):
		_label.add_theme_font_size_override("font_size", font_small_size)
	else:
		_label.add_theme_font_size_override("font_size", font_normal_size)


## Clear out the instructions
func _clean_txt(txt: String) -> String:
	txt = txt.replace("[p1]", "")
	txt = txt.replace("[p2]", "")
	txt = txt.replace("[big]", "")
	txt = txt.replace("[small]", "")
	txt = txt.replace("[shake]", "")
	txt = txt.replace("[rotate]", "")

	return txt


###################################
## Visual effects
###################################

## Move the textbox in and out of the screen.
func _process_move_in_out(delta: float) -> void:
	# Moving in and out of the view
	if _state == txtState.MOVE_IN:
		move_in_t1 = min(move_in_t2, move_in_t1 + delta)
		position.x = Easing.linear_lerp(move_in_t1, move_in_t2, move_in_x1, move_in_x2)
		position.y = Easing.linear_lerp(move_in_t1, move_in_t2, move_in_y1, move_in_y2)
		if move_in_t1 >= move_in_t2:
			_state = txtState.IDLE
	# Moving out afterwards
	elif _state == txtState.MOVE_OUT:
		move_out_t1 = min(move_out_t2, move_out_t1 + delta)
		position.x = Easing.linear_lerp(move_out_t1, move_out_t2, move_out_x1, move_out_x2)
		position.y = Easing.linear_lerp(move_out_t1, move_out_t2, move_out_y1, move_out_y2)
		if move_out_t1 >= move_out_t2:
			_state = txtState.IDLE

			# destroy the text box
			_instance_destroy()


## Scale the portraits and change their brightness depending on the active speaker.
func _process_portrait_scale(delta: float) -> void:
	# scale to the minimum
	if p1_scale_state == scaleState.SCALE_DOWN:
		p1_scale_t = move_toward(p1_scale_t, 0, delta)
	# scale to maximum
	else:
		p1_scale_t = move_toward(p1_scale_t, scale_time, delta)

	p1_scale = Easing.linear_lerp(p1_scale_t, scale_time, scale_start, scale_end)
	p1_modulate_v = Easing.linear_lerp(p1_scale_t, scale_time, modulate_value, 1.0)
	$P1.scale = Vector2(p1_scale, p1_scale)
	$P1.modulate = Color(p1_modulate_v, p1_modulate_v, p1_modulate_v, 1.0)

	# scale to the minimum
	if p2_scale_state == scaleState.SCALE_DOWN:
		p2_scale_t = move_toward(p2_scale_t, 0, delta)
	# scale to maximum
	else:
		p2_scale_t = move_toward(p2_scale_t, scale_time, delta)

	p2_scale = Easing.linear_lerp(p2_scale_t, scale_time, scale_start, scale_end)
	p2_modulate_v = Easing.linear_lerp(p2_scale_t, scale_time, modulate_value, 1.0)
	$P2.scale = Vector2(-p2_scale, p2_scale)
	$P2.modulate = Color(p2_modulate_v, p2_modulate_v, p2_modulate_v, 1.0)


## Update the active shake effect and decay amplitude over time.
func _process_shaking(delta: float) -> void:
	if p1_shake_timer > 0:
		p1_shake_timer = max(p1_shake_timer - delta, 0)
		if p1_shake_timer <= 0.0:
			$P1.offset = Vector2(0.0, 0.0)
		else:
			## Compute decayed random offset and apply to parent.
			var decay: float = p1_shake_timer / shake_timer
			var amplitude: float = shake_tot * decay
			$P1.offset = Vector2(
				randf_range(-amplitude, amplitude),
				randf_range(-amplitude, amplitude)
			)

	if p2_shake_timer > 0:
		p2_shake_timer = max(p2_shake_timer - delta, 0)
		if p2_shake_timer <= 0.0:
			$P2.offset = Vector2(0.0, 0.0)
		else:
			## Compute decayed random offset and apply to parent.
			var decay: float = p2_shake_timer / shake_timer
			var amplitude: float = shake_tot * decay
			$P2.offset = Vector2(
				randf_range(-amplitude, amplitude),
				randf_range(-amplitude, amplitude)
			)


## Rotate the portrait when the [rotate] tag is used.
func _process_rotate(delta: float) -> void:
	if p1_rotate_timer > 0:
		p1_rotate_timer = max(p1_rotate_timer - delta, 0)
		if p1_rotate_timer <= 0.0:
			$P1.rotation_degrees = 0
		else:
			$P1.rotation_degrees = p1_rotate_timer / rotate_timer * rotate_amplitude * sin(2 * PI / rotate_time_per_cycle * (1 - p1_rotate_timer / rotate_timer))

	if p2_rotate_timer > 0:
		p2_rotate_timer = max(p2_rotate_timer - delta, 0)
		if p2_rotate_timer <= 0.0:
			$P2.rotation_degrees = 0
		else:
			$P2.rotation_degrees = p2_rotate_timer / rotate_timer * rotate_amplitude * sin(2 * PI / rotate_time_per_cycle * (1 - p2_rotate_timer / rotate_timer))


###################################
## Helpers
###################################

## Destroy this text box and all of its children.
func _instance_destroy() -> void:
	queue_free()


## Return the SingletonSfx node if it exists in the scene tree.
func _get_sfx_singleton() -> Node:
	for node in get_tree().root.get_children():
		for childNode in node.get_children():
			if childNode.name == "SingletonSfx":
				return childNode
	return null


## Return true when the key event is a non-repeated Space press.
func _is_space_pressed(event: InputEvent) -> bool:
	return Input.get_action_strength("ui_test_space")
