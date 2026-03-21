extends Node

"""
	script that plays a single instance of a certain
	sfx sound
"""


const _STREAMS: Dictionary = {
	"hit1": preload("res://sounds/hit/hit1.wav"),
}

@onready var _player: AudioStreamPlayer = $AudioStreamPlayer


func play_sfx(sfx_name: String) -> void:
	if not _STREAMS.has(sfx_name):
		push_warning("Unknown sfx: %s" % sfx_name)
		return
	_player.stream = _STREAMS[sfx_name] as AudioStream
	_player.play()


#TODO: TESTING: make sfx happen
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_V:
			play_sfx("hit1")
