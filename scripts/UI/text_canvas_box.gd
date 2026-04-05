# TextCanvasBox.gd
extends Control
class_name TextCanvasBox


enum txtState {MOVE_IN, MOVE_OUT, IDLE, SCROLLING, COMPLETE, NEXTLINE}
enum scaleState {SCALE_UP, SCALE_DOWN}

var PROCESS_TEXT: bool = false

## Full texts to show, revealed one character at a time
@export var display_texts: Array[String] = ["Sample text"]:
	set(value):
		display_texts = value
		_current_text_index = 0
		_current_char_index = 0
		_apply_text()

@export var update_interval: float = 0.1
@export var diff_x: float = 0.0
@export var diff_y: float = 160.0

@export var scale_start: float = 0.8
@export var scale_end: float = 1.0
## how fast the scale changes
@export var scale_time: float = 0.1
## how much to darken the portrait when not talking
@export var modulate_value: float = 0.7

@export var font_big_size : int = 50
@export var font_small_size : int = 20
@export var font_normal_size : int = 40


var _label: Label
var _timer: Timer
var _current_text_index: int = 0
var _current_char_index: int = 0

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

var p1_scale: float = scale_start
var p2_scale: float = scale_start
var p1_scale_t : float = 0.0
var p2_scale_t : float = 0.0
var p1_scale_state : scaleState = scaleState.SCALE_DOWN
var p2_scale_state : scaleState = scaleState.SCALE_DOWN

var p1_modulate_v: float = modulate_value
var p2_modulate_v: float = modulate_value

#todo:
'''
	after move out, we destroy
	after text is over, we start the move out (done)
	Create a set_output, where we set the output based on current position and diff
	2 portraits (scaling)
'''


# The current state of the 
var _state: txtState = txtState.IDLE

func _ready() -> void:
	_label = %Label
	_label.add_theme_font_size_override("font_size", font_normal_size)
	
	# Timer which governs how fast text
	_timer = Timer.new()
	_timer.wait_time = update_interval
	_timer.autostart = false
	_timer.one_shot = false
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)
	_apply_text()
	
	# Moving in and out
	move_in_x1 = position.x + diff_x
	move_in_y1 = position.y + diff_y
	move_in_x2 = position.x
	move_in_y2 = position.y 
	
	move_out_x1 = position.x
	move_out_y1 = position.y
	move_out_x2 = position.x + diff_x
	move_out_y2 = position.y + diff_y
	
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
	
func _process(delta) -> void:
	
	# Move the text box in and out of view
	_process_move_in_out(delta)
	
	# scale the portraits based on who is talking, along with darkening/lightening
	_process_portrait_scale(delta)


func _process_move_in_out(delta : float) -> void:
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

func _process_portrait_scale(delta : float) -> void:
	
	# scale to the minimum
	if p1_scale_state == scaleState.SCALE_DOWN:
		p1_scale_t = move_toward(p1_scale_t, 0, delta)
	# scale to maximum
	else:
		p1_scale_t = move_toward(p1_scale_t, scale_time, delta)
	p1_scale = Easing.linear_lerp(p1_scale_t, scale_time, scale_start, scale_end);
	p1_modulate_v = Easing.linear_lerp(p1_scale_t, scale_time, modulate_value, 1.0);
	$P1.scale = Vector2(p1_scale, p1_scale)
	$P1.modulate = Color(p1_modulate_v, p1_modulate_v, p1_modulate_v, 1.0)
	
	
	# scale to the minimum
	if p2_scale_state == scaleState.SCALE_DOWN:
		p2_scale_t = move_toward(p2_scale_t, 0, delta)
	# scale to the maximum
	else:
		p2_scale_t = move_toward(p2_scale_t, scale_time, delta)
	p2_scale = Easing.linear_lerp(p2_scale_t, scale_time, scale_start, scale_end);
	p2_modulate_v = Easing.linear_lerp(p2_scale_t, scale_time, modulate_value, 1.0);
	$P2.scale = Vector2(-p2_scale, p2_scale)
	$P2.modulate = Color(p2_modulate_v, p2_modulate_v, p2_modulate_v, 1.0)
	



func set_box_texts(texts: Array[String]) -> void:
	display_texts = texts
	_current_text_index = 0
	_current_char_index = 0
	_apply_text()


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
	else:
		_state = txtState.COMPLETE
		_timer.stop()

	_apply_text()


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

func _process_txt(txt: String) -> void:

	if txt.contains("[p2]"):
		p1_scale_state = scaleState.SCALE_DOWN
		p2_scale_state = scaleState.SCALE_UP
	elif txt.contains("[p1]"):
		p1_scale_state = scaleState.SCALE_UP
		p2_scale_state = scaleState.SCALE_DOWN

	if txt.contains("[big]"):
		_label.add_theme_font_size_override("font_size", font_big_size)
	elif txt.contains("[small]"):
		_label.add_theme_font_size_override("font_size", font_small_size)
	else:
		_label.add_theme_font_size_override("font_size", font_normal_size)

# Primary keypress somewhere
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

## Return true when the key event is a non-repeated Space press.
func _is_space_pressed(event: InputEvent) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE


func _clean_txt(txt: String) -> String:
	txt = txt.replace("[p1]", "")
	txt = txt.replace("[p2]", "")
	txt = txt.replace("[big]", "")
	txt = txt.replace("[small]", "")
	
	return txt
