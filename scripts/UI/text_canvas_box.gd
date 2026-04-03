# TextCanvasBox.gd
extends Control
class_name TextCanvasBox

## Text shown inside the panel box.
@export var display_text: String = "Sample text":
	set(value):
		display_text = value
		_apply_text()

var _label: Label


func _ready() -> void:
	_label = %Label
	_apply_text()


func set_box_text(text: String) -> void:
	display_text = text


func _apply_text() -> void:
	var label: Label = _label
	if label == null and is_inside_tree():
		label = get_node_or_null("MarginContainer/Label") as Label
		_label = label
	if label:
		label.text = display_text
