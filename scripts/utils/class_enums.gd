# res://scripts/globals/gl_enums.gd
class_name Enums

# for players and goblins, whether we are on top of the cell
enum GroundState {
	ON_CELL,			# on top o the cell
	FALLING,			# falling of the edge
}

# From goblin state
# checking what the attacking status is of the goblin (works with comp_chase_melee)
enum AttackState {
	IDLE,        # We are idle (patrolling)
	CHASE,       # we are either chasing
	WINDING_UP,  # we are winding up the attack
	ATTACKING,   # we are doing the attack
	RELOAD,      # small idle window when slowing down
}
