extends Node2D

#region Exported configuration
@export_group("Enable")
## When false, movement and path updates are skipped (useful for debugging).
@export var movement_enabled: bool = true
## When true, clears the path and zeroes velocity while the goblin is dazed (e.g. after a kick).
@export var pause_when_dazed: bool = true

@export_group("Node paths")
## CharacterBody2D driven by this chase logic (velocity, move_and_slide).
@export var body_path: NodePath = ^"../CharacterBody2D"
## Optional kickback component; when it reports active impact, pathing is cleared until impact ends.
@export var kickback_path: NodePath = ^"../CompBodyKickback"
## Optional overlap component; connects to cell floor signals so the goblin only paths when on a cell.
@export var cell_overlap_path: NodePath = ^"../CompOnCellOverlap"

@export_group("blocking_elements")
## Physics groups whose colliders block line-of-sight raycasts to the player.
@export var blocking_elements_groups_los: Array[String] = ["pillar", "wall"]
## Physics groups treated as solid for A* grid marking and path-smoothing obstacle checks.
@export var blocking_elements_groups_astar: Array[String] = ["pillar", "wall", "glass"]

@export_group("Movement")
## Target speed along the path toward the current waypoint (pixels per second).
@export var move_speed: float = 220.0
## Distance from a waypoint at which the goblin advances to the next point.
@export var waypoint_reach_distance: float = 10.0
## When true, rotates the body toward the current movement direction each frame.
@export var rotate_to_velocity_enabled: bool = true
## How quickly the body rotation lerps toward the movement direction (higher = snappier).
@export var rotation_speed: float = 10.0

@export_group("Path update")
## Base seconds between full path rebuilds while chasing.
@export var repath_interval_sec: float = 1.0
## Random jitter added to each repath delay so many goblins do not repath on the same frame.
@export var repath_jitter_sec: float = 0.2
## Maximum random delay (seconds) before the first repath after ready, to stagger startup.
@export var initial_stagger_max_sec: float = 1.0

@export_group("A* Grid")
## Grid cell size in pixels (also used for world/cell conversions, minimum 8 enforced in code).
@export var cell_size: int = 32
## Extra padding around tracked actors and the goal when computing the A* region bounds.
@export var grid_margin_px: float = 220.0
## Default blocker radius in pixels when no collision shape can be read from a pillar node.
@export var pillar_block_radius_px: float = 54.0
## Extra padding added to computed blocker radii so nearby cells stay walkable-safe.
@export var pillar_block_buffer_px: float = 12.0
## When true, allows diagonal edges on the A* grid; when false, only cardinal moves.
@export var allow_diagonal_movement: bool = true

@export_group("Path Debug")
## When true, draws the active path from the body to waypoints in the editor/game view.
@export var draw_path_enabled: bool = true
## Color used for path debug lines.
@export var path_line_color: Color = Color(0.2, 1.0, 0.2, 0.95)
## Width of path debug lines.
@export var path_line_width: float = 2.0
#endregion

#region Types and state
enum BehaviorState {
	IDLE, # we just stand there
	CHASE, # moving towards the last known location of the player
	SEARCH_LAST_KNOWN # search stuff
}

var _body: CharacterBody2D
var _kickback: Node
var _goblin_root: Node

var _astar: AStarGrid2D
var _grid_origin: Vector2 = Vector2.ZERO

var _path_points: PackedVector2Array = PackedVector2Array()
var _path_index: int = 0
var _repath_timer: float = 0.0

var _behavior_state: BehaviorState = BehaviorState.IDLE
var _last_known_player_pos: Vector2 = Vector2.ZERO
var _on_cell_floor: bool = true
#endregion

#region Lifecycle and signals
func _ready() -> void:
	_body = get_node_or_null(body_path) as CharacterBody2D
	_kickback = get_node_or_null(kickback_path)
	_goblin_root = get_parent()
	var cell_overlap := get_node_or_null(cell_overlap_path)
	if cell_overlap:
		cell_overlap.left_cell.connect(_on_overlap_left_cell)
		cell_overlap.on_cell_state_changed.connect(_on_overlap_cell_state_changed)
	randomize()
	_repath_timer = randf_range(0.0, max(initial_stagger_max_sec, 0.0))


func _on_overlap_left_cell() -> void:
	_on_cell_floor = false


func _on_overlap_cell_state_changed(is_on_cell: bool, _area: Area2D) -> void:
	_on_cell_floor = is_on_cell
#endregion

#region Main loop
## Update chase behavior, repath timing, and path following each physics frame.
func _physics_process(delta: float) -> void:
	# Abort when required body is missing.
	if _body == null:
		return

	# When we manually disable movement in the gui, we reset our path variables
	if !_is_movement_active():
		_set_state(BehaviorState.IDLE)
		_clear_path()
		if !_is_impact_active():
			_body.velocity = Vector2.ZERO
		return

	# If the goblin has impact, we don't do anything with the path
	if _is_impact_active():
		_clear_path()
		return

	# The path stops when the goblin is dazed
	if pause_when_dazed and _is_goblin_dazed():
		_clear_path()
		_body.velocity = Vector2.ZERO
		_body.move_and_slide()
		return

	if !_on_cell_floor:
		_set_state(BehaviorState.IDLE)
		_clear_path()
		_body.velocity = Vector2.ZERO
		_body.move_and_slide()
		return

	if !_is_goblin_chasing():
		_clear_path()
		_body.velocity = Vector2.ZERO
		_body.move_and_slide()
		return

	# Update behavior state and rebuild path on timer.
	_update_behavior_state()

	# Recalculate path every so often
	_repath_timer -= delta
	if _repath_timer <= 0.0:
		_rebuild_path_for_state() # based on state, we make a path
		_repath_timer = _next_repath_delay()

	_follow_path(delta)
#endregion

#region Movement guards
## Return whether this behavior component is enabled. for debugging purposes, we set movement_enabled to false
func _is_movement_active() -> bool:
	return movement_enabled


## Return true while the kickback component reports active impact motion.
func _is_impact_active() -> bool:
	return _kickback != null and _kickback.has_method("is_impact_active") and _kickback.call("is_impact_active")


## Compute the next repath delay with random jitter.
func _next_repath_delay() -> float:
	var base: float = max(0.05, repath_interval_sec)
	var jitter: float = max(0.0, repath_jitter_sec)
	return max(0.05, base + randf_range(-jitter, jitter))
#endregion

#region State machine
## Update behavior state using line-of-sight and last-known player position.
func _update_behavior_state() -> void:

	# Fall back to idle if no player body is found (if the player is dead for example)
	var player_body := _get_player_body()
	if player_body == null:
		_set_state(BehaviorState.IDLE)
		return

	# Check line of sight (if we have line of sight, we update the known position of the player)
	var has_los: bool = _has_clear_line_to_player(player_body)
	if has_los:
		_last_known_player_pos = player_body.global_position

	# Change state of the goblin
	match _behavior_state:
		BehaviorState.IDLE: # if we are idle and see the player, we chase
			if has_los:
				_set_state(BehaviorState.CHASE)
		BehaviorState.CHASE: # if we are chasing and lose the player, go to last known location
			if !has_los:
				_set_state(BehaviorState.SEARCH_LAST_KNOWN)
		BehaviorState.SEARCH_LAST_KNOWN:
			if has_los: # if we are searching last known, and see the player, we start chasing
				_set_state(BehaviorState.CHASE)
				return

			# If we are close to player last known location, and don't see him, we go back to idle
			if _body.global_position.distance_to(_last_known_player_pos) <= waypoint_reach_distance * 1.6:
				_set_state(BehaviorState.IDLE)


## Apply behavior-state transitions and force immediate repath.
func _set_state(next_state: BehaviorState) -> void:
	if _behavior_state == next_state:
		return
	_behavior_state = next_state
	if _behavior_state == BehaviorState.IDLE:
		_clear_path()
	_repath_timer = 0.0
#endregion

#region Path build and follow
## Build a new path to current behavior target for the active state.
func _rebuild_path_for_state() -> void:

	# If there is no player, we clear the path
	var player_body := _get_player_body()
	if player_body == null:
		_clear_path()
		return

	# if we are idle, we clear the path and stop moving
	if _behavior_state == BehaviorState.IDLE:
		_clear_path()
		return

	var target_pos: Vector2 = player_body.global_position # player location

	if _behavior_state == BehaviorState.SEARCH_LAST_KNOWN:
		target_pos = _last_known_player_pos

	# Build A* grid and compute ID path fallbacks.
	var graph_ok: bool = _build_grid(target_pos)

	if !graph_ok:
		_set_path(PackedVector2Array([target_pos]))
		return

	var start_id: Vector2i = _world_to_cell(_body.global_position)
	var goal_id: Vector2i = _world_to_cell(target_pos)

	if !_is_cell_in_bounds(start_id) or !_is_cell_in_bounds(goal_id):
		_set_path(PackedVector2Array([target_pos]))
		return

	_astar.set_point_solid(start_id, false)
	_astar.set_point_solid(goal_id, false)

	var id_path: Array[Vector2i] = _astar.get_id_path(start_id, goal_id)
	if id_path.is_empty():
		_set_path(PackedVector2Array([target_pos]))
		return

	var world_points: PackedVector2Array = PackedVector2Array()
	for cell in id_path:
		world_points.append(_cell_to_world(cell))
	world_points.append(target_pos)

	# Remove unnecessary points before storing path.
	_set_path(_smooth_path_points(world_points))


## Move toward current waypoint and advance along path when reached.
func _follow_path(delta: float) -> void:
	if _path_points.is_empty():
		_body.velocity = Vector2.ZERO
		_body.move_and_slide()
		return

	while _path_index < _path_points.size():
		var target: Vector2 = _path_points[_path_index]
		if _body.global_position.distance_to(target) <= waypoint_reach_distance:
			_path_index += 1
			continue
		var dir: Vector2 = (target - _body.global_position).normalized()
		_body.velocity = dir * move_speed
		_rotate_body_toward(dir, delta)
		_body.move_and_slide()
		return

	_body.velocity = Vector2.ZERO
	_body.move_and_slide()
#endregion

#region A* grid
## Build an A* grid around tracked actors and destination target.
func _build_grid(target_pos: Vector2) -> bool:
	# Compute bounds from pillars, goblins, player, and target.
	var bounds_ok: bool = false
	var min_x: float = 0.0
	var min_y: float = 0.0
	var max_x: float = 0.0
	var max_y: float = 0.0

	var tracked: Array[Node] = []
	tracked.append_array(get_tree().get_nodes_in_group("pillar"))
	tracked.append_array(get_tree().get_nodes_in_group("goblin"))
	tracked.append_array(get_tree().get_nodes_in_group("player"))
	tracked.append(self)
	for group_name in blocking_elements_groups_astar:
		if group_name.is_empty():
			continue
		tracked.append_array(get_tree().get_nodes_in_group(group_name))

	for node in tracked:
		if node is Node2D:
			var pos: Vector2 = (node as Node2D).global_position
			if !bounds_ok:
				min_x = pos.x
				min_y = pos.y
				max_x = pos.x
				max_y = pos.y
				bounds_ok = true
			else:
				min_x = min(min_x, pos.x)
				min_y = min(min_y, pos.y)
				max_x = max(max_x, pos.x)
				max_y = max(max_y, pos.y)

	if !bounds_ok:
		return false

	min_x = min(min_x, target_pos.x) - grid_margin_px
	min_y = min(min_y, target_pos.y) - grid_margin_px
	max_x = max(max_x, target_pos.x) + grid_margin_px
	max_y = max(max_y, target_pos.y) + grid_margin_px

	var size_px: Vector2 = Vector2(max_x - min_x, max_y - min_y)
	var step: int = max(8, cell_size)
	var width_cells: int = max(8, int(ceil(size_px.x / float(step))) + 1)
	var height_cells: int = max(8, int(ceil(size_px.y / float(step))) + 1)

	_grid_origin = Vector2(min_x, min_y)
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(0, 0, width_cells, height_cells)
	_astar.cell_size = Vector2(step, step)
	_astar.diagonal_mode = (
		AStarGrid2D.DIAGONAL_MODE_AT_LEAST_ONE_WALKABLE
		if allow_diagonal_movement
		else AStarGrid2D.DIAGONAL_MODE_NEVER
	)
	_astar.update()

	_mark_blocked_cells_for_astar_groups(step)
	return true


## Mark blocked grid cells around each A* blocker (groups from blocking_elements_groups_astar).
func _mark_blocked_cells_for_astar_groups(step: int) -> void:
	var seen: Dictionary = {}
	for group_name in blocking_elements_groups_astar:
		if group_name.is_empty():
			continue
		for node in get_tree().get_nodes_in_group(group_name):
			if seen.has(node):
				continue
			seen[node] = true
			if !(node is Node2D):
				continue

			var blocker: Node2D = node as Node2D
			var block_radius_px: float = _pillar_block_radius_for(blocker)
			var center_id: Vector2i = _world_to_cell(blocker.global_position)
			var block_radius_cells: int = max(1, int(ceil(block_radius_px / float(step))))
			for y in range(-block_radius_cells, block_radius_cells + 1):
				for x in range(-block_radius_cells, block_radius_cells + 1):
					var sample_world: Vector2 = _cell_to_world(center_id + Vector2i(x, y))
					if sample_world.distance_to(blocker.global_position) > block_radius_px:
						continue
					var test_id := center_id + Vector2i(x, y)
					if _is_cell_in_bounds(test_id):
						_astar.set_point_solid(test_id, true)
#endregion

#region Node lookup and coordinates
## Return the first player CharacterBody2D in the player group.
func _get_player_body() -> CharacterBody2D:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	for node in players:
		if node is CharacterBody2D:
			return node as CharacterBody2D
	return null


## Convert world position to current grid cell coordinates.
func _world_to_cell(world_pos: Vector2) -> Vector2i:
	var step: float = float(max(8, cell_size))
	var local: Vector2 = world_pos - _grid_origin
	return Vector2i(
		int(floor(local.x / step)),
		int(floor(local.y / step))
	)


## Convert grid cell coordinates to world-center position.
func _cell_to_world(cell: Vector2i) -> Vector2:
	var step: float = float(max(8, cell_size))
	return _grid_origin + Vector2(cell.x + 0.5, cell.y + 0.5) * step


## Return true when a cell lies inside current A* region bounds.
func _is_cell_in_bounds(cell: Vector2i) -> bool:
	if _astar == null:
		return false
	return (
		cell.x >= _astar.region.position.x
		and cell.y >= _astar.region.position.y
		and cell.x < _astar.region.end.x
		and cell.y < _astar.region.end.y
	)
#endregion

#region Path storage
## Store a new world-space path and reset waypoint index.
func _set_path(points: PackedVector2Array) -> void:
	_path_points = points
	_path_index = 0
	queue_redraw() # for debugging : draw the path


## Clear active path data and request redraw when needed.
func _clear_path() -> void:
	if _path_points.is_empty() and _path_index == 0:
		return
	_path_points = PackedVector2Array()
	_path_index = 0
	queue_redraw() # for debugging : draw the path
#endregion

#region Perception and path smoothing
## Return true when no pillar blocks line of sight to the player (line of sight)
func _has_clear_line_to_player(player_body: CharacterBody2D) -> bool:
	if _body == null or player_body == null:
		return false
	var space_state := get_world_2d().direct_space_state
	if space_state == null:
		return false

	# Raycast from goblin body to player, ignoring both endpoints.
	var query := PhysicsRayQueryParameters2D.create(_body.global_position, player_body.global_position)
	query.exclude = [_body.get_rid(), player_body.get_rid()]
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var hit: Dictionary = space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider := hit.get("collider") as Node
	if collider == null:
		return true

	# check line of sight blocked
	var blocked = false
	for group_name in blocking_elements_groups_los:
		if _node_or_ancestor_in_group(collider, group_name):
			blocked = true
			break

	return !blocked


## Return true when a straight segment's first physics hit is in blocking_elements_groups_astar.
func _is_line_blocked_by_astar_groups(from_pos: Vector2, to_pos: Vector2) -> bool:
	var space_state := get_world_2d().direct_space_state
	if space_state == null:
		return false
	var query := PhysicsRayQueryParameters2D.create(from_pos, to_pos)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	if _body != null:
		query.exclude = [_body.get_rid()]
	var hit: Dictionary = space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var collider := hit.get("collider") as Node
	if collider == null:
		return false
	for group_name in blocking_elements_groups_astar:
		if group_name.is_empty():
			continue
		if _node_or_ancestor_in_group(collider, group_name):
			return true
	return false


## Simplify path points by removing collinear points and skipping nodes only when the chord is free of A* blockers.
func _smooth_path_points(points: PackedVector2Array) -> PackedVector2Array:
	# First pass: remove mostly collinear points.
	if points.size() <= 2:
		return points

	var collinear_reduced: PackedVector2Array = PackedVector2Array()
	collinear_reduced.append(points[0])
	for i in range(1, points.size() - 1):
		var prev: Vector2 = points[i - 1]
		var current: Vector2 = points[i]
		var next: Vector2 = points[i + 1]
		var a: Vector2 = (current - prev).normalized()
		var b: Vector2 = (next - current).normalized()
		var cross_abs: float = abs(a.cross(b))
		if cross_abs > 0.06:
			collinear_reduced.append(current)
	collinear_reduced.append(points[points.size() - 1])

	if collinear_reduced.size() <= 2:
		return collinear_reduced

	# Second pass: greedily skip points when anchor-to-next chord does not hit blocking_elements_groups_astar.
	var simplified: PackedVector2Array = PackedVector2Array()
	simplified.append(collinear_reduced[0])
	var anchor: int = 0
	var i: int = 1
	while i < collinear_reduced.size() - 1:
		var next_i: int = i + 1
		if !_is_line_blocked_by_astar_groups(collinear_reduced[anchor], collinear_reduced[next_i]):
			i += 1
			continue
		simplified.append(collinear_reduced[i])
		anchor = i
		i += 1
	simplified.append(collinear_reduced[collinear_reduced.size() - 1])
	return simplified
#endregion

#region Goblin root helpers and rotation
## Return whether the goblin root currently reports a dazed state.
func _is_goblin_dazed() -> bool:
	if _goblin_root == null:
		return false
	return _goblin_root.has_method("get_dazed") and _goblin_root.call("get_dazed")


## get true if we are using the chasing state of the attacking
func _is_goblin_chasing() -> bool:
	if _goblin_root == null:
		return false
	return _goblin_root.has_method("get_chase_state") and _goblin_root.call("get_chase_state")


## Rotate body smoothly toward movement direction.
func _rotate_body_toward(move_dir: Vector2, delta: float) -> void:
	if !rotate_to_velocity_enabled or _body == null:
		return
	if move_dir.length_squared() <= 0.0001:
		return
	var desired_rot: float = move_dir.angle()
	var weight: float = 1.0 - exp(-max(0.01, rotation_speed) * delta)
	_body.rotation = lerp_angle(_body.rotation, desired_rot, weight)
#endregion

#region Blocker footprint and group tests
## Compute blocker footprint radius from collision shape (CharacterBody2D or StaticBody2D child) and buffer.
func _pillar_block_radius_for(pillar_node: Node2D) -> float:
	var radius_px: float = max(4.0, pillar_block_radius_px)
	var physics_body: CollisionObject2D = pillar_node.get_node_or_null("CharacterBody2D") as CharacterBody2D
	if physics_body == null:
		physics_body = pillar_node.get_node_or_null("StaticBody2D") as StaticBody2D
	if physics_body == null:
		return radius_px + max(0.0, pillar_block_buffer_px)

	var collider_shape := physics_body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collider_shape == null or collider_shape.shape == null:
		return radius_px + max(0.0, pillar_block_buffer_px)

	# Derive approximate radius from known 2D shape types.
	var scale_current: Vector2 = physics_body.global_transform.get_scale().abs()
	var shape := collider_shape.shape
	if shape is RectangleShape2D:
		var rect: RectangleShape2D = shape
		var extents: Vector2 = rect.size * 0.5
		radius_px = max(extents.x * scale_current.x, extents.y * scale_current.y)
	elif shape is CircleShape2D:
		var circle: CircleShape2D = shape
		radius_px = circle.radius * max(scale_current.x, scale_current.y)
	elif shape is CapsuleShape2D:
		var capsule: CapsuleShape2D = shape
		radius_px = (capsule.height * 0.5 + capsule.radius) * max(scale_current.x, scale_current.y)

	return max(4.0, radius_px + max(0.0, pillar_block_buffer_px))


## Return true when node or any ancestor belongs to the given group.
func _node_or_ancestor_in_group(node: Node, group: StringName) -> bool:
	var current: Node = node
	while current != null:
		if current.is_in_group(group):
			return true
		current = current.get_parent()
	return false
#endregion

#region Debug draw
## Draw current path preview from body to remaining waypoints.
func _draw() -> void:
	if !draw_path_enabled or _path_points.is_empty():
		return

	var next_index: int = clampi(_path_index, 0, _path_points.size() - 1)
	if _body != null and next_index < _path_points.size():
		var body_local: Vector2 = to_local(_body.global_position)
		var next_local: Vector2 = to_local(_path_points[next_index])
		draw_line(body_local, next_local, path_line_color, path_line_width, true)

	if _path_points.size() - next_index < 2:
		return

	var local_points: PackedVector2Array = PackedVector2Array()
	for i in range(next_index, _path_points.size()):
		local_points.append(to_local(_path_points[i]))
	draw_polyline(local_points, path_line_color, path_line_width, true)
#endregion
