extends Node

"""
	script that plays a single instance of a certain
	sfx sound
"""


const _STREAMS: Dictionary = {
	"hit1": preload("res://sounds/hit/hit1.wav"),
}

@onready var _player: AudioStreamPlayer = $AudioStreamPlayer


func play_sfx(sfx_name: String, from : float = 0.0, pitch : float = 1.0) -> void:
	if not _STREAMS.has(sfx_name):
		push_warning("Unknown sfx: %s" % sfx_name)
		return
	_player.stream = _STREAMS[sfx_name] as AudioStream
	
	_player.pitch_scale = pitch
	_player.play(from)


func play_sfx_rand_pitch(sfx_name: String, from : float = 0.0, random_pitch_min : float = 0.1, random_pitch_max : float = 2.0) -> void:
	if not _STREAMS.has(sfx_name):
		push_warning("Unknown sfx: %s" % sfx_name)
		return
	_player.stream = _STREAMS[sfx_name] as AudioStream
	
	var pitch = randf() * (random_pitch_max - random_pitch_min) + random_pitch_min
	_player.pitch_scale = pitch
	_player.play(from)



#TODO: TESTING: make sfx happen
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_V:
			#play_sfx("hit1")
			play_sfx_rand_pitch("hit1", 0)
