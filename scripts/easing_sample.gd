extends Node2D

# Variables that we set public
@export var start: Vector2 = Vector2(100, 200)
@export var end: Vector2 = Vector2(500, 200)
@export var radius: float = 18.0
@export var duration: float = 3.0
@export var ping_pong: bool = true
@export var sprite: Texture2D
@export var sprite_scale: float = 1.0
@export var sprite_offset_x: int = 0
@export var sprite_offset_y: int = 0

@export_enum(
	"linear",
	"ease_in_quad",
	"ease_out_quad",
	"ease_in_out_quad",
	"ease_in_cubic",
	"ease_out_cubic",
	"ease_in_out_cubic",
	"ease_in_quartic",
	"ease_out_quartic",
	"ease_in_out_quartic",
	"ease_in_quint",
	"ease_out_quint",
	"ease_in_out_quint",
	"ease_in_sine",
	"ease_out_sine",
	"ease_in_out_sine",
	"ease_in_expo",
	"ease_out_expo",
	"ease_in_out_expo",
	"ease_in_circ",
	"ease_out_circ",
	"ease_in_out_circ",
	"ease_in_back",
	"ease_out_back",
	"ease_in_out_back",
	"ease_in_elastic",
	"ease_out_elastic",
	"ease_in_out_elastic",
	"ease_out_bounce",
	"ease_in_bounce",
	"ease_in_out_bounce"
)
var easing_type: int

var _time: float = 0.0
var _forward: bool = true
var _default_font: Font = ThemeDB.fallback_font


func _process(delta: float) -> void:
	# Advance time forward/backward
	if _forward:
		_time += delta
	else:
		_time -= delta

	# Handle looping behavior
	if ping_pong:
		if _time >= duration:
			_time = duration
			_forward = false
		elif _time <= 0.0:
			_time = 0.0
			_forward = true
	else:
		if _time >= duration:
			_time -= duration

	queue_redraw()


func _draw() -> void:
	# Using lerp wrappers: pass (_time, duration, x1, x2)
	var pos_x: float
	var pos_y: float
	var type_string := ""

	match easing_type:
		0:
			pos_x = Easing.linear_lerp(_time, duration, start.x, end.x)
			pos_y = Easing.linear_lerp(_time, duration, start.y, end.y)
			type_string = "Linear"

		1:
			pos_x = Easing.ease_in_quad_lerp(_time, duration, start.x, end.x)
			pos_y = Easing.ease_in_quad_lerp(_time, duration, start.y, end.y)
			type_string = "Ease In Quadratic"
		2:
			pos_x = Easing.ease_out_quad_lerp(_time, duration, start.x, end.x)
			pos_y = Easing.ease_out_quad_lerp(_time, duration, start.y, end.y)
			type_string = "Ease Out Quadratic"
		3:
			pos_x = Easing.ease_in_out_quad_lerp(_time, duration, start.x, end.x)
			pos_y = Easing.ease_in_out_quad_lerp(_time, duration, start.y, end.y)
			type_string = "Ease In Out Quadratic"

		4:
			pos_x = Easing.ease_in_cubic_lerp(_time, duration, start.x, end.x)
			pos_y = Easing.ease_in_cubic_lerp(_time, duration, start.y, end.y)
			type_string = "Ease In Cubic"
		5:
			pos_x = Easing.ease_out_cubic_lerp(_time, duration, start.x, end.x)
			pos_y = Easing.ease_out_cubic_lerp(_time, duration, start.y, end.y)
			type_string = "Ease Out Cubic"
		6:
			pos_x = Easing.ease_in_out_cubic_lerp(_time, duration, start.x, end.x)
			pos_y = Easing.ease_in_out_cubic_lerp(_time, duration, start.y, end.y)
			type_string = "Ease In Out Cubic"

		7:
			pos_x = Easing.ease_in_quart_lerp(_time, duration, start.x, end.x)
			pos_y = Easing.ease_in_quart_lerp(_time, duration, start.y, end.y)
			type_string = "Ease In Quartic"
		8:
			pos_x = Easing.ease_out_quart_lerp(_time, duration, start.x, end.x)
			pos_y = Easing.ease_out_quart_lerp(_time, duration, start.y, end.y)
			type_string = "Ease Out Quartic"
		9:
			pos_x = Easing.ease_in_out_quart_lerp(_time, duration, start.x, end.x)
			pos_y = Easing.ease_in_out_quart_lerp(_time, duration, start.y, end.y)
			type_string = "Ease In Out Quartic"

		10:
			pos_x = Easing.ease_in_quint_lerp(_time, duration, start.x, end.x)
			pos_y = Easing.ease_in_quint_lerp(_time, duration, start.y, end.y)
			type_string = "Ease In Quintic"
		11:
			pos_x = Easing.ease_out_quint_lerp(_time, duration, start.x, end.x)
			pos_y = Easing.ease_out_quint_lerp(_time, duration, start.y, end.y)
			type_string = "Ease Out Quintic"
		12:
			pos_x = Easing.ease_in_out_quint_lerp(_time, duration, start.x, end.x)
			pos_y = Easing.ease_in_out_quint_lerp(_time, duration, start.y, end.y)
			type_string = "Ease In Out Quintic"

		13:
			pos_x = Easing.ease_in_sine_lerp(_time, duration, start.x, end.x)
			pos_y = Easing.ease_in_sine_lerp(_time, duration, start.y, end.y)
			type_string = "Ease In Sine"
		14:
			pos_x = Easing.ease_out_sine_lerp(_time, duration, start.x, end.x)
			pos_y = Easing.ease_out_sine_lerp(_time, duration, start.y, end.y)
			type_string = "Ease Out Sine"
		15:
			pos_x = Easing.ease_in_out_sine_lerp(_time, duration, start.x, end.x)
			pos_y = Easing.ease_in_out_sine_lerp(_time, duration, start.y, end.y)
			type_string = "Ease In Out Sine"

		16:
			pos_x = Easing.ease_in_expo_lerp(_time, duration, start.x, end.x)
			pos_y = Easing.ease_in_expo_lerp(_time, duration, start.y, end.y)
			type_string = "Ease In Exponential"
		17:
			pos_x = Easing.ease_out_expo_lerp(_time, duration, start.x, end.x)
			pos_y = Easing.ease_out_expo_lerp(_time, duration, start.y, end.y)
			type_string = "Ease Out Exponential"
		18:
			pos_x = Easing.ease_in_out_expo_lerp(_time, duration, start.x, end.x)
			pos_y = Easing.ease_in_out_expo_lerp(_time, duration, start.y, end.y)
			type_string = "Ease In Out Exponential"

		19:
			pos_x = Easing.ease_in_circ_lerp(_time, duration, start.x, end.x)
			pos_y = Easing.ease_in_circ_lerp(_time, duration, start.y, end.y)
			type_string = "Ease In Circular"
		20:
			pos_x = Easing.ease_out_circ_lerp(_time, duration, start.x, end.x)
			pos_y = Easing.ease_out_circ_lerp(_time, duration, start.y, end.y)
			type_string = "Ease Out Circular"
		21:
			pos_x = Easing.ease_in_out_circ_lerp(_time, duration, start.x, end.x)
			pos_y = Easing.ease_in_out_circ_lerp(_time, duration, start.y, end.y)
			type_string = "Ease In Out Circular"

		22:
			pos_x = Easing.ease_in_back_lerp(_time, duration, start.x, end.x)
			pos_y = Easing.ease_in_back_lerp(_time, duration, start.y, end.y)
			type_string = "Ease In Back"
		23:
			pos_x = Easing.ease_out_back_lerp(_time, duration, start.x, end.x)
			pos_y = Easing.ease_out_back_lerp(_time, duration, start.y, end.y)
			type_string = "Ease Out Back"
		24:
			pos_x = Easing.ease_in_out_back_lerp(_time, duration, start.x, end.x)
			pos_y = Easing.ease_in_out_back_lerp(_time, duration, start.y, end.y)
			type_string = "Ease In Out Back"

		25:
			pos_x = Easing.ease_in_elastic_lerp(_time, duration, start.x, end.x)
			pos_y = Easing.ease_in_elastic_lerp(_time, duration, start.y, end.y)
			type_string = "Ease In Elastic"
		26:
			pos_x = Easing.ease_out_elastic_lerp(_time, duration, start.x, end.x)
			pos_y = Easing.ease_out_elastic_lerp(_time, duration, start.y, end.y)
			type_string = "Ease Out Elastic"
		27:
			pos_x = Easing.ease_in_out_elastic_lerp(_time, duration, start.x, end.x)
			pos_y = Easing.ease_in_out_elastic_lerp(_time, duration, start.y, end.y)
			type_string = "Ease In Out Elastic"

		28:
			pos_x = Easing.ease_out_bounce_lerp(_time, duration, start.x, end.x)
			pos_y = Easing.ease_out_bounce_lerp(_time, duration, start.y, end.y)
			type_string = "Ease Out Bounce"
		29:
			pos_x = Easing.ease_in_bounce_lerp(_time, duration, start.x, end.x)
			pos_y = Easing.ease_in_bounce_lerp(_time, duration, start.y, end.y)
			type_string = "Ease In Bounce"
		30:
			pos_x = Easing.ease_in_out_bounce_lerp(_time, duration, start.x, end.x)
			pos_y = Easing.ease_in_out_bounce_lerp(_time, duration, start.y, end.y)
			type_string = "Ease In Out Bounce"

		_:
			pos_x = Easing.linear_lerp(_time, duration, start.x, end.x)
			pos_y = Easing.linear_lerp(_time, duration, start.y, end.y)
			type_string = "Linear"

	var pos := Vector2(pos_x, pos_y)

	# Draw endpoints and line for clarity
	draw_line(start, end, Color(0.4, 0.4, 0.4), 2.0)
	draw_circle(start, 5.0, Color(0.7, 0.7, 0.7))
	draw_circle(end, 5.0, Color(0.7, 0.7, 0.7))

	draw_string(
		_default_font,
		Vector2(start.x, start.y - 50),
		type_string,
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		22
	)

	# Draw the Sprite (centered + scaled)
	if sprite != null:
		var draw_pos := Vector2(pos.x + sprite_offset_x, pos.y + sprite_offset_y)
		draw_set_transform(draw_pos, 0.0, Vector2(sprite_scale, -sprite_scale))
		draw_texture(sprite, -sprite.get_size() * 0.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
