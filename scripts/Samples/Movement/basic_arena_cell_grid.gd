extends Node2D

@export var W: int = 3
@export var H: int = 6
@export var x1: float = 100.0
@export var y1: float = 100.0
@export var cell_size: Vector2 = Vector2(100.0, 100.0)
@export var cell_scene: PackedScene
@export var clear_existing_on_ready: bool = true
@export var floor_z_index: int = -100


func _ready() -> void:
	z_index = floor_z_index
	spawn_grid(clear_existing_on_ready)


func spawn_grid(clear_existing: bool = true) -> void:
	if cell_scene == null:
		push_warning("Grid spawn skipped: no cell_scene provided.")
		return

	if clear_existing:
		for child in get_children():
			child.queue_free()

	for gy in range(H):
		for gx in range(W):
			var cell := cell_scene.instantiate() as Node2D
			if cell == null:
				push_warning("Grid spawn skipped: cell_scene root is not Node2D.")
				return

			add_child(cell)
			cell.position = Vector2(x1 + gx * cell_size.x, y1 + gy * cell_size.y)

			if cell.has_method("init"):
				cell.call("init", gx, gy, int(cell_size.x), int(cell_size.y))
