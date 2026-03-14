extends Node2D

"""
	Spawn a grid of size WxH, starting at top left coordinate x1,y1.
	
	This script is attached to a Node2D, which will contain all of the cell objects as its children
	
	There should only be one of these instances (singleton)
"""

## width of the grid
@export var W: int = 3
## height of the grid
@export var H: int = 6
## top left x coordinate
@export var x1: float = 100.0
## top left y coordinate
@export var y1: float = 100.0
# Size of the cell (can be larger or smaller than the actuall cell)
@export var cell_size: Vector2 = Vector2(100.0, 100.0)
## the cell that we are spawning
@export var cell_scene: PackedScene
## If set to true, we clear all existing cells as well (which should be part of our cell group)
@export var clear_existing_on_ready: bool = true
## Depth of the cells, so they show up below the other actors
@export var floor_z_index: int = -100


func _ready() -> void:
	z_index = floor_z_index			# Z-index is in what order we draw it
	spawn_grid(clear_existing_on_ready)

## Spawn a group of cells of WxH
func spawn_grid(clear_existing: bool = true) -> void:
	if cell_scene == null:
		push_warning("Grid spawn skipped: no cell_scene provided.")
		return

	# If set to true, we delete any existing cells
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
