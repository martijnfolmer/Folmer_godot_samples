extends Node

"""
	script that plays instances of certain
	sfx sounds

	Each sound can define how many copies of itself are allowed
	to play at the same time
"""


const _SFX_DATA: Dictionary = {
	"hit1": {
		# location of the sound
		"stream": preload("res://sounds/hit/hit1.wav"),

		# Maximum number of times this sound may play at the same time.
		"max_simultaneous": 1,
	},
}

@onready var _player_template: AudioStreamPlayer = $AudioStreamPlayer

# Tracks currently playing AudioStreamPlayers per sfx name.
# Example:
# {
#   "hit1": [AudioStreamPlayer, AudioStreamPlayer]
# }
var _active_players_by_sfx: Dictionary = {}


# Only uncomment if you need information about the sound we are playing
#func _process(_delta: float) -> void:
	#var info := get_current_volume_info()
#
	#print(
		#"Peak: ", info["peak_db"], " dB, ",
		#"Headroom: ", info["headroom_db"], " dB, ",
		#"Can multiply by: ", info["can_multiply_by"]
	#)

#region Playing sfx sound functions
func play_sfx(
	sfx_name: String,
	from: float = 0.0,
	pitch: float = 1.0,
	volume_multiplier: float = 1.0
) -> void:
	if not _SFX_DATA.has(sfx_name):
		push_warning("Unknown sfx: %s" % sfx_name)
		return

	if not can_play_sfx(sfx_name):
		# Sound is already playing the maximum allowed number of times.
		return

	var sfx_data := _SFX_DATA[sfx_name] as Dictionary
	var stream := sfx_data["stream"] as AudioStream

	var player := create_sfx_player(sfx_name, stream, pitch, volume_multiplier)
	player.play(from)


func play_sfx_rand_pitch(
	sfx_name: String,
	from: float = 0.0,
	random_pitch_min: float = 0.1,
	random_pitch_max: float = 2.0,
	volume_multiplier: float = 1.0
) -> void:
	if not _SFX_DATA.has(sfx_name):
		push_warning("Unknown sfx: %s" % sfx_name)
		return

	if not can_play_sfx(sfx_name):
		# Sound is already playing the maximum allowed number of times.
		return

	var sfx_data := _SFX_DATA[sfx_name] as Dictionary
	var stream := sfx_data["stream"] as AudioStream

	var pitch := randf() * (random_pitch_max - random_pitch_min) + random_pitch_min

	var player := create_sfx_player(sfx_name, stream, pitch, volume_multiplier)
	player.play(from)
#endregion


#region Helper functions

func can_play_sfx(sfx_name: String) -> bool:
	var sfx_data := _SFX_DATA[sfx_name] as Dictionary
	var max_simultaneous := sfx_data["max_simultaneous"] as int

	if not _active_players_by_sfx.has(sfx_name):
		_active_players_by_sfx[sfx_name] = []

	var active_players := _active_players_by_sfx[sfx_name] as Array

	# Remove players that may already have been freed
	active_players = active_players.filter(func(player): return is_instance_valid(player))
	_active_players_by_sfx[sfx_name] = active_players
	return active_players.size() < max_simultaneous


func create_sfx_player(
	sfx_name: String,
	stream: AudioStream,
	pitch: float,
	volume_multiplier: float
) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()

	player.stream = stream
	player.pitch_scale = pitch
	player.bus = _player_template.bus

	# volume_multiplier should be between 0 and 10.
	# 0 = silent, 1 = normal volume, 10 = 10 times as loud.
	player.volume_db = volume_multiplier_to_db(volume_multiplier)

	add_child(player)

	if not _active_players_by_sfx.has(sfx_name):
		_active_players_by_sfx[sfx_name] = []

	var active_players := _active_players_by_sfx[sfx_name] as Array
	active_players.append(player)

	# When this specific sound finishes, remove it from the tracking array
	# and delete the temporary AudioStreamPlayer
	player.finished.connect(_on_sfx_player_finished.bind(sfx_name, player))

	return player


func _on_sfx_player_finished(sfx_name: String, player: AudioStreamPlayer) -> void:
	if _active_players_by_sfx.has(sfx_name):
		var active_players := _active_players_by_sfx[sfx_name] as Array
		active_players.erase(player)

	player.queue_free()


func volume_multiplier_to_db(volume_multiplier: float) -> float:
	# Clamp the value so callers cannot accidentally pass values below 0 or above 10x as loud
	var clamped_multiplier := clampf(volume_multiplier, 0.0, 10.0)

	# A multiplier of 0 means complete silence.
	# Godot does not use negative infinity here, so -80 dB is silent
	if clamped_multiplier <= 0.0:
		return -80.0

	# Convert linear volume to decibels.
	# Examples:
	# 1.0  -> 0 dB, normal volume
	# 2.0  -> about +6 dB, twice as loud in amplitude
	# 10.0 -> +20 dB, ten times as loud in amplitude
	return linear_to_db(clamped_multiplier)


func get_current_volume_info(bus_index: int = 0) -> Dictionary:
	var left_db := AudioServer.get_bus_peak_volume_left_db(bus_index, 0)
	var right_db := AudioServer.get_bus_peak_volume_right_db(bus_index, 0)

	var peak_db = max(left_db, right_db)

	# If nothing is playing, Godot may return very low values.
	if peak_db <= -80.0:
		return {
			"playing": false,
			"player_volume_db": _player_template.volume_db,
			"peak_db": -80.0,
			"headroom_db": 80.0,
			"can_multiply_by": db_to_linear(80.0)
		}

	var headroom_db = 0.0 - peak_db

	return {
		"playing": true,
		"player_volume_db": _player_template.volume_db,
		"peak_db": peak_db,
		"headroom_db": headroom_db,
		"can_multiply_by": db_to_linear(headroom_db)
	}
#endregion




# TODO: TESTING: remove testing V input button
func _unhandled_input(event: InputEvent) -> void:
	if Input.get_action_strength("ui_test_v"):
		# Normal volume:
		#play_sfx("hit1")

		# Half volume:
		play_sfx("hit1", 0.0, 1.0, 0.5)

		# Ten times as loud:
		#play_sfx("hit1", 0.0, 1.0, 10.0)

		# Random pitch, normal volume:
		#play_sfx_rand_pitch("hit1", 0.0)

		# Random pitch, 5x volume:
		#play_sfx_rand_pitch("hit1", 0.0, 0.1, 2.0, 5.0)

	#if event is InputEventKey:
		#var key_event := event as InputEventKey
		#if key_event.pressed and not key_event.echo and key_event.keycode == KEY_V:
			##play_sfx("hit1")
			#play_sfx_rand_pitch("hit1", 0)
