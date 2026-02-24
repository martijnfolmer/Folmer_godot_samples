extends Node2D
class_name Cell

@onready var sprite: Sprite2D = null

enum CellType { EMPTY, ROAD, ROCK }

var grid_x: int
var grid_y: int
var cell_type: CellType = CellType.EMPTY

func init(x: int, y: int, w: int, h: int, t: CellType = CellType.EMPTY) -> void:
	grid_x = x
	grid_y = y
	set_type(t)
	
	# resize the square cell to be right size
	resize(w, h)

func set_type(t: CellType) -> void:
	cell_type = t
	# match cell_type:
	# 	CellType.EMPTY: ...
	# 	CellType.ROAD:  ...
	# 	CellType.ROCK:  ...

func resize(w: int, h: int) -> void:
	if sprite == null:
		sprite = _find_first_sprite2d(self)
	
	if sprite == null:
		push_warning("resize(): No Sprite2D found.")
		return

	if sprite.texture == null:
		push_warning("resize(): Sprite2D has no texture.")
		return

	var tex_size: Vector2 = sprite.texture.get_size()
	if tex_size.x == 0.0 or tex_size.y == 0.0:
		push_warning("resize(): Texture size is zero.")
		return

	sprite.scale = Vector2(float(w) / tex_size.x, float(h) / tex_size.y)

func _find_first_sprite2d(root: Node) -> Sprite2D:
	for c in root.get_children():
		if c is Sprite2D:
			return c
		var found := _find_first_sprite2d(c)
		if found != null:
			return found
	return null
	
