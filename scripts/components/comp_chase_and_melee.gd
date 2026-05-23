extends Node



@export_group("Melee range")
## Maximum distance from the goblin body to the player at which CHASE transitions into WINDING_UP.
@export var distance_to_player_for_attack: float = 100.0

@export_group("Attack timing")
## How long the windup lasts before the strike (SpriteChest flash runs during this window).
@export var windup_duration_sec: float = 1.0
## How long the punch extends toward the player and hit checks are active.
@export var attack_duration_sec: float = 0.28
## Cooldown after a strike before attack state returns to CHASE.
@export var reload_duration_sec: float = 1.0

@export_group("Attack motion / hit")
## How far the right arm moves in chest-local space at full extension toward the player.
@export var punch_arm_reach_px: float = 100.0
## Maximum distance from the right arm sprite to the player body center to count as a hit.
@export var melee_hit_radius_px: float = 72.0
## Minimum strike progress from 0 to 1 (phase time divided by attack duration) before a hit can register.
@export var melee_hit_min_strike_t: float = 0.35
## HP removed from the player when a melee hit connects, using CompDamage.take_damage when that node exists.
@export var melee_damage: int = 1
## Force argument to CompBodyKickback.impact on the player when a hit connects, if that component exists.
@export var melee_kickback_force: float = 90.0

@export_group("Windup flash")
## Target tint blended with each sprite’s normal modulate during windup (pulses with a sine wave).
@export var windup_flash_color: Color = Color(0.0, 0.559, 0.812, 1.0)

@export_group("Chase path")
## Countdown in CHASE; when it drops below zero it resets and calls CompPathfindingAstar.refind_path().
@export var chase_repath_interval_sec: float = 0.5
## First path waypoint farther than this from the body is used as the facing target (pixels).
@export var chase_waypoint_advance_epsilon_px: float = 4.0
## Max rotation per second toward the path while chasing (radians).
@export var chase_rotation_speed_rad: float = 5.0
## speed with which we go down the path
@export var chase_path_speed: float = 5.0

var _goblin_root: Node
var _goblin_body: Node
## Sibling CompPathfindingAstar under the goblin root, if present.
var _pathfinding: Node = null
## Counts down while in CHASE; reset on expiry to trigger refind_path().
var _chase_repath_timer: float = 0.0
## Chase speed/direction preserved when leaving a cell (px/s).
var _fall_velocity: Vector2 = Vector2.ZERO

## Seconds accumulated in the current attack phase (windup, strike, or reload).
var _phase_time: float = 0.0
## True after this swing has applied kickback and damage so we only hit once per ATTACKING phase.
var _hit_applied_this_attack: bool = false
## True once arm baseline positions are stored for the current ATTACKING phase.
var _attack_arm_baselines_captured: bool = false
## Sprite2D nodes under SpriteChest whose modulate is driven during windup.
var _windup_sprite_cache: Array[Sprite2D] = []
## Original modulate color per entry in _windup_sprite_cache, restored after windup.
var _windup_modulate_cache: Array[Color] = []
## True while windup sprite/modulate caches are valid for the current windup.
var _windup_cache_built: bool = false

var punch_dir : Vector2 = Vector2.RIGHT 	# the direction we are punching


## Cache the goblin root (parent) and CharacterBody2D used for distances and punch aim.
func _ready() -> void:
	_goblin_root = get_parent()
	_goblin_body = _goblin_root.get_node_or_null("CharacterBody2D")
	_pathfinding = _goblin_root.get_node_or_null("CompPathfindingAstar")
	_chase_repath_timer = maxf(chase_repath_interval_sec, 0.001)
	var cell_overlap := _goblin_root.get_node_or_null("CompOnCellOverlap")
	if cell_overlap != null and cell_overlap.has_signal("left_cell"):
		cell_overlap.left_cell.connect(_on_chase_left_cell)


## Drive the melee attack state machine: chase-to-windup entry, windup flash, punch, reload, and return to chase.
func _process(delta: float) -> void:
	if _goblin_body == null:
		return

	# Get goblin stats
	var goblin_dazed := _is_goblin_dazed()
	var goblin_grounded_status := _get_goblin_grounded_status()
	var goblin_attack_status := _get_goblin_attack_status()

	# get player
	var player := _get_player_body()

	# Goblin state machine

	# if player no longer exists, do nothing
	if player == null:
		return

	if goblin_dazed:
		return

	if goblin_grounded_status == Enums.GroundState.ON_CELL and _fall_velocity != Vector2.ZERO:
		_fall_velocity = Vector2.ZERO

	if goblin_grounded_status == Enums.GroundState.FALLING:
		_apply_fall_motion(delta)
		return

	if goblin_attack_status == Enums.AttackState.CHASE:
		
		# recalculating paths again
		var interval := maxf(chase_repath_interval_sec, 0.001)
		_chase_repath_timer -= delta
		if _chase_repath_timer < 0.0:
			_chase_repath_timer = interval
			if _pathfinding != null and _pathfinding.has_method("refind_path"):
				_pathfinding.call("refind_path")

		# make the goblin face the path
		_apply_chase_path_facing(delta)
		
		# moving the player
		_apply_chase_path_move(delta)

		# check if we are close enough to the player to die
		var dist_player := _distance_to_player(player)
		if dist_player <= distance_to_player_for_attack:
			_reset_melee_phase_state()
			_set_goblin_attack_status(Enums.AttackState.WINDING_UP)

	elif goblin_attack_status == Enums.AttackState.WINDING_UP:
		# if winding up, flash color of all spriteChest in a blink
		if !_windup_cache_built:
			_build_windup_sprite_modulate_cache()
		_phase_time += delta
		var blink := 0.5 + 0.5 * sin(_phase_time * TAU * 14.0)
		_apply_windup_flash(blink)
		if _phase_time >= windup_duration_sec:
			_restore_windup_modulates()
			_windup_cache_built = false
			_phase_time = 0.0
			_hit_applied_this_attack = false
			_attack_arm_baselines_captured = false
			_set_goblin_attack_status(Enums.AttackState.ATTACKING)

	elif goblin_attack_status == Enums.AttackState.ATTACKING:
		# move the right arm towards the player like a punch
		# check if we collide with the player once, give a kickback to the player and damage it
		var chest := _get_sprite_chest()
		var arm_r := _get_sprite_arm_right()
		var arm_r_outline := _get_sprite_arm_right_outline()
		if chest == null or arm_r == null:
			_restore_arm_positions(arm_r, arm_r_outline)
			_phase_time = 0.0
			_set_goblin_attack_status(Enums.AttackState.RELOAD)
		else:
			if !_attack_arm_baselines_captured:
				_capture_arm_baselines(arm_r, arm_r_outline)
				_attack_arm_baselines_captured = true
			_phase_time += delta
			var strike_t := clampf(_phase_time / maxf(attack_duration_sec, 0.001), 0.0, 1.0)
			punch_dir = chest.to_local(player.global_position)
			if punch_dir.length_squared() > 0.0001:
				punch_dir = punch_dir.normalized()
			else:
				punch_dir = Vector2.RIGHT
			var punch_offset := punch_dir * punch_arm_reach_px
			arm_r.position = _arm_r_base.lerp(_arm_r_base + punch_offset, strike_t)
			if arm_r_outline != null:
				arm_r_outline.position = _arm_r_outline_base.lerp(_arm_r_outline_base + punch_offset, strike_t)

			if (
				!_hit_applied_this_attack
				and strike_t >= melee_hit_min_strike_t
				and arm_r.global_position.distance_to(player.global_position) <= melee_hit_radius_px
			):
				_apply_melee_hit(player)

			if _phase_time >= attack_duration_sec:
				_restore_arm_positions(arm_r, arm_r_outline)
				_phase_time = 0.0
				_set_goblin_attack_status(Enums.AttackState.RELOAD)

	elif goblin_attack_status == Enums.AttackState.RELOAD:
		# wait for a certain amount of time
		_phase_time += delta
		
		# return the arm to original position
		var strike_t := clampf(1 - _phase_time / maxf(attack_duration_sec, 0.001), 0.0, 1.0)
		var punch_offset := punch_dir * punch_arm_reach_px
		var arm_r := _get_sprite_arm_right()
		var arm_r_outline := _get_sprite_arm_right_outline()
		arm_r.position = _arm_r_base.lerp(_arm_r_base + punch_offset, strike_t)
		arm_r_outline.position = _arm_r_base.lerp(_arm_r_base + punch_offset, strike_t)
		
		if _phase_time >= reload_duration_sec:
			_phase_time = 0.0
			_hit_applied_this_attack = false
			_attack_arm_baselines_captured = false
			_chase_repath_timer = maxf(chase_repath_interval_sec, 0.001)
			_set_goblin_attack_status(Enums.AttackState.CHASE)


## Local position of SpriteArmRight at the start of the current strike (restored after ATTACKING)
var _arm_r_base: Vector2 = Vector2.ZERO
## Local position of SpriteArmRight_outline at strike start, if present.
var _arm_r_outline_base: Vector2 = Vector2.ZERO


## Clear timers and caches when starting a new windup from CHASE.
func _reset_melee_phase_state() -> void:
	_phase_time = 0.0
	_hit_applied_this_attack = false
	_attack_arm_baselines_captured = false
	_windup_cache_built = false
	_windup_sprite_cache.clear()
	_windup_modulate_cache.clear()


## Rotate the goblin body toward the next path waypoint from CompPathfindingAstar.path_coor.
func _apply_chase_path_facing(delta: float) -> void:
	if chase_rotation_speed_rad <= 0.0:
		return
	if _pathfinding == null or _goblin_body == null:
		return
	var raw: Variant = _pathfinding.get("path_coor")
	if raw == null:
		return
	var path_pts: Array = raw as Array
	if path_pts.size() < 2:
		return
	var body_pos: Vector2 = _goblin_body.global_position
	var target_world: Vector2 = path_pts[path_pts.size() - 1] as Vector2
	for wp_v in path_pts:
		if not wp_v is Vector2:
			continue
		var wp: Vector2 = wp_v as Vector2
		if body_pos.distance_to(wp) > chase_waypoint_advance_epsilon_px:
			target_world = wp
			break
	var to_target := target_world - body_pos
	if to_target.length_squared() < 0.0001:
		return
	var target_angle := to_target.angle()
	_goblin_body.rotation = rotate_toward(_goblin_body.rotation, target_angle, chase_rotation_speed_rad * delta)

## Blocking groups from CompPathfindingAstar, or the same defaults as that component.
func _get_astar_blocking_groups() -> Array[StringName]:
	if _pathfinding != null:
		var groups: Variant = _pathfinding.get("blocking_elements_groups_astar")
		if groups is Array:
			return groups as Array[StringName]
	return [&"pillar", &"wall", &"glass", &"goblin"]


## True when a movement segment hits any static blocking collider.
## Uses CompPathfindingAstar's cached AABB list for O(rects) cost with no scene queries.
func _is_chase_segment_blocked(from: Vector2, to: Vector2) -> bool:
	if _goblin_body == null:
		return false
	if from.distance_squared_to(to) < 0.0001:
		return false
	if _pathfinding != null and _pathfinding.has_method("is_segment_blocked"):
		return _pathfinding.call("is_segment_blocked", from, to)
	return General._blocked_by_LOS(
		_goblin_body,
		from.x, from.y, to.x, to.y,
		_get_astar_blocking_groups()
	)


## Return the farthest point along from→to that does not cross a blocker.
func _clamp_chase_motion(from: Vector2, to: Vector2) -> Vector2:
	if not _is_chase_segment_blocked(from, to):
		return to
	var low := 0.0
	var high := 1.0
	for _i in 8:
		var mid := (low + high) * 0.5
		var mid_pos := from.lerp(to, mid)
		if _is_chase_segment_blocked(from, mid_pos):
			high = mid
		else:
			low = mid
	return from.lerp(to, low)


func _apply_chase_path_move(delta: float) -> void:
	if _pathfinding == null or _goblin_body == null:
		return
		
	var raw: Variant = _pathfinding.get("path_coor")
	if raw == null:
		return
	var path_pts: Array = raw as Array
	if path_pts.size() < 2:
		return
	
	var body := _goblin_body as CharacterBody2D
	if body == null:
		return

	var chase_vel := Vector2.from_angle(body.rotation) * chase_path_speed
	body.velocity = chase_vel

	var from := body.global_position
	var motion := chase_vel * delta
	var to := from + motion
	var blocked_full := _is_chase_segment_blocked(from, to)
	body.global_position = _clamp_chase_motion(from, to)
	if blocked_full:
		_chase_repath_timer = 0.0


## Capture path speed/direction when CompOnCellOverlap reports leaving a cell.
func _on_chase_left_cell() -> void:
	if _goblin_body is CharacterBody2D:
		var body := _goblin_body as CharacterBody2D
		if body.velocity.length_squared() > 0.01:
			_fall_velocity = body.velocity
		else:
			_fall_velocity = Vector2.from_angle(body.rotation) * chase_path_speed
	elif _goblin_body != null:
		_fall_velocity = Vector2.from_angle(_goblin_body.rotation) * chase_path_speed


## Continue moving at preserved chase velocity while FALLING (goblin.gd sets ground state).
func _apply_fall_motion(delta: float) -> void:
	if !(_goblin_body is CharacterBody2D):
		return
	var body := _goblin_body as CharacterBody2D
	body.velocity = _fall_velocity
	body.global_position += _fall_velocity * delta



## Return the goblin’s SpriteChest node under CharacterBody2D, or null if missing.
func _get_sprite_chest() -> Node2D:
	if _goblin_body == null:
		return null
	return _goblin_body.get_node_or_null("SpriteChest") as Node2D


## Return SpriteArmRight under SpriteChest, or null.
func _get_sprite_arm_right() -> Sprite2D:
	var chest := _get_sprite_chest()
	if chest == null:
		return null
	return chest.get_node_or_null("SpriteArmRight") as Sprite2D


## Return SpriteArmRight_outline under SpriteChest, or null.
func _get_sprite_arm_right_outline() -> Sprite2D:
	var chest := _get_sprite_chest()
	if chest == null:
		return null
	return chest.get_node_or_null("SpriteArmRight_outline") as Sprite2D


## Append every Sprite2D in the subtree rooted at n to out (depth-first).
func _collect_sprites_recursive(n: Node, out: Array[Sprite2D]) -> void:
	if n is Sprite2D:
		out.append(n as Sprite2D)
	for c in n.get_children():
		_collect_sprites_recursive(c, out)


## Fill windup sprite and modulate caches from all Sprite2D nodes under SpriteChest.
func _build_windup_sprite_modulate_cache() -> void:
	_windup_sprite_cache.clear()
	_windup_modulate_cache.clear()
	var chest := _get_sprite_chest()
	if chest == null:
		_windup_cache_built = true
		return
	_collect_sprites_recursive(chest, _windup_sprite_cache)
	for s in _windup_sprite_cache:
		_windup_modulate_cache.append(s.modulate)
	_windup_cache_built = true


## Blend each cached sprite’s modulate toward windup_flash_color; blink_t is typically 0–1 from a sine pulse.
func _apply_windup_flash(blink_t: float) -> void:
	for i in range(_windup_sprite_cache.size()):
		var s := _windup_sprite_cache[i]
		if not is_instance_valid(s):
			continue
		var base: Color = _windup_modulate_cache[i] if i < _windup_modulate_cache.size() else Color.WHITE
		s.modulate = base.lerp(windup_flash_color, blink_t)


## Restore original modulates from cache and clear windup sprite caches.
func _restore_windup_modulates() -> void:
	for i in range(_windup_sprite_cache.size()):
		var s := _windup_sprite_cache[i]
		if not is_instance_valid(s):
			continue
		if i < _windup_modulate_cache.size():
			s.modulate = _windup_modulate_cache[i]
	_windup_sprite_cache.clear()
	_windup_modulate_cache.clear()


## Store current local positions of the right arm and its outline for lerp and restore after the strike.
func _capture_arm_baselines(arm_r: Sprite2D, arm_r_outline: Sprite2D) -> void:
	_arm_r_base = arm_r.position
	_arm_r_outline_base = arm_r_outline.position if arm_r_outline != null else Vector2.ZERO


## Reset right arm and outline local positions to the baselines captured at strike start.
func _restore_arm_positions(arm_r: Sprite2D, arm_r_outline: Sprite2D) -> void:
	if arm_r != null:
		arm_r.position = _arm_r_base
	if arm_r_outline != null:
		arm_r_outline.position = _arm_r_outline_base


## Apply one-shot kickback and damage to the player when the melee hit conditions are met.
func _apply_melee_hit(player: CharacterBody2D) -> void:
	_hit_applied_this_attack = true
	var ang = (player.global_position - _goblin_body.global_position).angle()
	var kb := player.get_node_or_null("CompBodyKickback")
	if kb != null and kb.has_method("impact"):
		kb.call("impact", melee_kickback_force, ang)
	var dmg_parent := player.get_parent()
	var dmg: Node = null
	if dmg_parent != null:
		dmg = dmg_parent.get_node_or_null("CompDamage")
	if dmg != null and dmg.has_method("take_damage"):
		dmg.call("take_damage", melee_damage)


## Return true if the parent goblin reports dazed (e.g. kickback), so melee logic stays idle.
func _is_goblin_dazed() -> bool:
	if _goblin_root == null:
		return false
	return _goblin_root.has_method("get_dazed") and _goblin_root.call("get_dazed")


## Return the first CharacterBody2D in the player group, or null if none exists.
func _get_player_body() -> CharacterBody2D:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	for node in players:
		if node is CharacterBody2D:
			return node as CharacterBody2D
	return null


## Read ON_CELL vs FALLING from the parent goblin when it exposes get_ground_state.
func _get_goblin_grounded_status() -> Enums.GroundState:
	if _goblin_root == null:
		return Enums.GroundState.ON_CELL

	if _goblin_root.has_method("get_ground_state"):
		return _goblin_root.call("get_ground_state")

	return Enums.GroundState.ON_CELL


## Forward ground state to the parent goblin if set_ground_state exists; return whether the call was made.
func _set_goblin_grounded_status(_groundState: Enums.GroundState) -> bool:
	if _goblin_root == null:
		return false

	if _goblin_root.has_method("set_ground_state"):
		_goblin_root.call("set_ground_state", _groundState)
		return true

	return false


## Read the parent goblin’s attack phase (IDLE, CHASE, WINDING_UP, ATTACKING, RELOAD) via get_attack_state.
func _get_goblin_attack_status() -> Enums.AttackState:
	if _goblin_root == null:
		return Enums.AttackState.CHASE

	if _goblin_root.has_method("get_attack_state"):
		return _goblin_root.call("get_attack_state")

	return Enums.AttackState.CHASE


## Set the parent goblin’s attack state when set_attack_state exists; return whether the call was made.
func _set_goblin_attack_status(_attackState: Enums.AttackState) -> bool:
	if _goblin_root == null:
		return false

	if _goblin_root.has_method("set_attack_state"):
		_goblin_root.call("set_attack_state", _attackState)
		return true

	return false


## Euclidean distance from the goblin CharacterBody2D to the player CharacterBody2D.
func _distance_to_player(_player: CharacterBody2D) -> float:
	return _player.global_position.distance_to(_goblin_body.global_position)
