extends Node2D

# TODO: TESTING: create the text canvas box
const TEXT_CANVAS_BOX_SCENE := preload("res://scenes/UI/text_canvas_box.tscn")

# TODO: TESTING: pillar test force
@export_group("Pillar crush test")
@export var pillar_test_force: float = 1000.0

#TODO: TESTING: write and read to json
func write_and_read_json() -> void:
	#var path := "user://save_data.json"	# the example says this, but I could not tell you where this ended up
	var path := "res://json/save_data.json"

	var save_data := {
		"player_name": "Martijn",
		"level": 3,
		"hp": 87,
		"items": ["key", "potion"]
	}

	var ok := JsonFileUtils.write_json_file(path, save_data)
	if ok:
		print("Saved JSON to ", path)

	var loaded = JsonFileUtils.read_json_file(path)
	if loaded != null:
		print("Loaded JSON: ", loaded)


func _create_textBox() -> void:
	var txtBox := TEXT_CANVAS_BOX_SCENE.instantiate()
	var lines: Array[String] = [
			"[p1]I'm talking first, and we passed on",
			"[p2]I'm talking second, it has been passed",
			"[p1][big]And I'm talking loudly",
			"[p1][small]Same guy, talking softly",
			"[p2][shake]Shaking a lot",
			"[p1][rotate]rotating my portrait",
			"[p2][big][shake][rotate] All effects!",
		]
	
	var singleton_cam := get_parent().get_node_or_null("SingletonCamera") as Node
	var hud := singleton_cam.get_node_or_null("HudLayer") if singleton_cam else null
	if hud:
		hud.add_child(txtBox)
		txtBox.set_box_texts(lines)
	else:
		add_child(txtBox)
		txtBox.set_box_texts(lines)


# Input
# TODO: TESTING: pillars to you after space bar
## Handle debug input and trigger the pillar push test.
func _unhandled_input(event: InputEvent) -> void:
	#if _is_space_pressed(event):
		#_move_two_closest_pillars_towards_player()
		#write_and_read_json()
	if _is_K_pressed(event):
		_create_textBox()
		
	
# TODO: TESTING: space bar pressed
## Return true when the key event is a non-repeated Space press.
func _is_space_pressed(event: InputEvent) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE

func _is_K_pressed(event: InputEvent) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_K

# TODO: TESTING: move nearest pillars to you
## Push the two nearest pillars toward the player using kickback impact.
func _move_two_closest_pillars_towards_player() -> void:
	# Resolve the player used as the attraction point.
	var player := $movement_WASD as CharacterBody2D
	if player == null:
		return

	# Gather candidate pillars from the scene.
	var pillars: Array[Node] = get_tree().get_nodes_in_group("pillar")
	if pillars.is_empty():
		return

	# Keep only Node2D pillars so we can sort by position.
	var sortable: Array[Node2D] = []
	for node in pillars:
		if node is Node2D:
			sortable.append(node)

	if sortable.is_empty():
		return

	# Sort pillars by distance to the player.
	var player_pos: Vector2 = player.global_position
	sortable.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(player_pos) < b.global_position.distance_squared_to(player_pos)
	)

	# Apply impact to at most two nearest pillars.
	var count: int = min(2, sortable.size())
	for i in count:
		var pillar: Node2D = sortable[i]
		var kickback: Node = pillar.get_node_or_null("CompBodyKickback")
		if kickback == null:
			continue
		var ang: float = (player_pos - pillar.global_position).angle()
		kickback.call("impact", pillar_test_force, ang)
