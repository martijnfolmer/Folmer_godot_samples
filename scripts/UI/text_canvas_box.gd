# TextCanvasBox.gd
extends Control
class_name TextCanvasBox



enum txtState {MOVE_IN, MOVE_OUT, IDLE, SCROLLING, COMPLETE, NEXTLINE}

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

#todo:
'''
	after move out, we destroy
	after text is over, we start the move out (done)
	Create a set_output, where we set the output based on current position and diff
	
'''


# The current state of the 
var _state: txtState = txtState.IDLE

func _ready() -> void:
	_label = %Label

	# Add a new timer as a child
	_timer = Timer.new()
	_timer.wait_time = update_interval
	_timer.autostart = false
	_timer.one_shot = false
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)

	_apply_text()
	
	# Moving in
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
	
func _process(delta) -> void:
	
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
			label.text = current_text.substr(0, _current_char_index)


# Primary keypress somewhere
func _unhandled_input(event: InputEvent) -> void:
	if _is_space_pressed(event):
		# if we are idle, start it (we haven't started the text yet)
		if _state == txtState.IDLE:
			_timer.start()
			_state = txtState.SCROLLING
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

## Return true when the key event is a non-repeated Space press.
func _is_space_pressed(event: InputEvent) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE
