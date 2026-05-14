extends Node2D
class_name SelectionRect

@export var topLeft: Vector2 = Vector2.ZERO
@export var bottomRight: Vector2 = Vector2(200, 120)

@export var rect_color: Color = Color(0.2, 0.7, 1.0, 0.25)
@export var border_color: Color = Color(0.2, 0.7, 1.0, 1.0)


var rect: Rect2 = Rect2(topLeft, Vector2(topLeft.x - bottomRight.x, topLeft.y - bottomRight.y))


func _ready() -> void:
	rect = Rect2(topLeft, Vector2(bottomRight.x - topLeft.x, bottomRight.y - topLeft.y))


func _draw() -> void:
	var local_rect := rect.abs()

	draw_rect(local_rect, rect_color, true)
	draw_rect(local_rect, border_color, false, 2.0)
	
	#print(rect)

func set_rect_from_points(a: Vector2, b: Vector2) -> void:
	# Points are in this node's local coordinate space.
	rect = Rect2(a, b - a).abs()
	queue_redraw()


func get_global_rect() -> Rect2:
	var local_rect := rect.abs()

	var global_top_left := to_global(local_rect.position)
	var global_bottom_right := to_global(local_rect.end)

	return Rect2(global_top_left, global_bottom_right - global_top_left).abs()


func get_global_top_left() -> Vector2:
	return get_global_rect().position


func get_global_bottom_right() -> Vector2:
	return get_global_rect().end
