extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var polygon := PackedVector2Array([
		Vector2(0, 0),
		Vector2(4, 0),
		Vector2(4, 3),
		Vector2(0, 3)
	])

	print(Geom2Util.polygon_area(polygon)) # 12.0

	polygon = PackedVector2Array([
		Vector2(0, 0),
		Vector2(4, 0),
		Vector2(4, 4),
		Vector2(0, 4)
	])
	print(Geom2Util.polygon_area(polygon)) # 16.0


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
