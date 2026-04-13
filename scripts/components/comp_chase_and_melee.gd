extends Node

"""
	For the enemy that needs to chase a player, get into melee range, and attack
	
		- If we are not dazed
			- check if player exists
			- if player near us, go to windup up attacking (stop Astar)
			- flash enemy color
			- 

"""
var _goblin_root: Node

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_goblin_root = get_parent()
	
	"""
	_goblin_root = get_parent()
	var cell_overlap := get_node_or_null(cell_overlap_path)
	if cell_overlap:
		cell_overlap.left_cell.connect(_on_overlap_left_cell)
		cell_overlap.on_cell_state_changed.connect(_on_overlap_cell_state_changed)
	
	"""
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	

func _check_dazed(delta: float) -> void:
	pass

func _is_goblin_dazed() -> bool:
	if _goblin_root == null:
		return false
	return _goblin_root.has_method("is_dazed") and _goblin_root.call("is_dazed")



# checking goblin status
	
	
