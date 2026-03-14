extends Node2D
class_name Cell

"""
	Cells, which are part of a grid (like a chessboard)
	
	Cells can have different celltypes and have a mouse_over/mouse_exited event
"""

@onready var sprite: Sprite2D = $Sprite2D
@onready var area: Area2D = $Area2D

enum CellType { EMPTY, ROAD, ROCK }

var grid_x: int
var grid_y: int
var cell_type: CellType = CellType.EMPTY
var mouse_over: bool = false

func init(x: int, y: int, w: int, h: int, t: CellType = CellType.EMPTY) -> void:
	grid_x = x
	grid_y = y
	set_type(t)
	
	# resize the square cell to be right size
	resize(w, h)

func _ready() -> void:
	add_to_group("cells")
	area.mouse_entered.connect(_on_mouse_entered)
	area.mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	mouse_over = true
	var gs := GlobalGrid.grid_state
	if gs:
		gs.hover_cell = self
		gs.hover_cell_coor = Vector2(grid_x, grid_y)
		pass
	sprite.modulate = Color.YELLOW

func _on_mouse_exited() -> void:
	mouse_over = false
	sprite.modulate = Color.WHITE

func set_type(t: CellType) -> void:
	cell_type = t
	# match cell_type:
	# 	CellType.EMPTY: ...
	# 	CellType.ROAD:  ...
	# 	CellType.ROCK:  ...

func resize(w: int, h: int) -> void:

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
	area.scale = Vector2(float(w) / tex_size.x, float(h) / tex_size.y)
