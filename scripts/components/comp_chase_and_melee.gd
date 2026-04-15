extends Node

"""
	For the enemy that needs to chase a player, get into melee range, and attack
	
		- If we are not dazed
			- check if player exists
			- if player near us, go to windup up attacking (stop Astar)
			- flash enemy color
			- 

"""

@export var distance_to_player_for_attack : float = 100

# From goblin state
# Checking whether the goblin is on the cell or falling off (works with comp_on_cell_overlap)
enum GroundState {
	ON_CELL,			# on top o the cell
	FALLING,			# falling of the edge
}

# From goblin state
# checking what the attacking status is of the goblin (works with comp_chase_melee)
enum AttackState {
	CHASE,			# we are either idle or chasing
	WINDING_UP,		# we are winding up the attack
	ATTACKING,		# we are doing the attack
	RELOAD,			# small idle window when slowing down
}


var _goblin_root: Node
var _goblin_body: Node

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_goblin_root = get_parent()
	_goblin_body = _goblin_root.get_node_or_null("CharacterBody2D") 
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	# Get goblin stats
	var goblin_dazed = _is_goblin_dazed()
	var goblin_grounded_status = _goblin_grounded_status()
	var goblin_attack_status = _goblin_attack_status()
	
	# get player
	var player = _get_player_body()
	
	# Goblin state machine

	# if player no longer exists, do nothing
	if player == null:
		return
	
	# if goblin is dazed or falling, do nothing
	if goblin_dazed or goblin_grounded_status == GroundState.FALLING:
		return
	
	
	if goblin_attack_status == AttackState.CHASE:
		
		var dist_player = _distance_to_player(player)
		
		#if dist_player <= distance_to_player_for_attack:
			# set attack state for goblin function
			# do it here
	
	# If chase, we do the A star
	# if we are close to the player (find player (export size))
	# if winding up, flash color and make arm move towards player
	# if attacking, check collision
	
	
	
	



## return true if the goblin this component is attached to is dazed
func _is_goblin_dazed() -> bool:
	if _goblin_root == null:
		return false
	return _goblin_root.has_method("is_dazed") and _goblin_root.call("is_dazed")


## Check if the player body exists
func _get_player_body() -> CharacterBody2D:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	for node in players:
		if node is CharacterBody2D:
			return node as CharacterBody2D
	return null



## checking goblin status : whether we are on the cell or not
func _goblin_grounded_status() -> GroundState:
	if _goblin_root == null:
		return GroundState.ON_CELL
	
	if _goblin_root.has_method("get_ground_state"):
		return _goblin_root.call("get_ground_state")
		
	return GroundState.ON_CELL

## checking goblin status : what part of the attack we are at.
func _goblin_attack_status() -> AttackState:
	if _goblin_root == null:
		return AttackState.CHASE
		
	if _goblin_root.has_method("get_attack_state"):
		return _goblin_root.call("get_attack_state")
	
	return AttackState.CHASE
	

## Get distance to player
func _distance_to_player(_player : CharacterBody2D) -> float:
	
	var dist = _player.global_position.distance_to(_goblin_body.global_position)
	return dist

	
	
