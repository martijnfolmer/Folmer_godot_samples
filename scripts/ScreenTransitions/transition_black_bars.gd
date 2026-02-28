# TransitionBlackBars.gd
extends ColorRect
class_name TransitionBlackBars

## Number of black bars (visible bars)
@export var bar_count: int = 12
## How long it takes to close
@export var close_time: float = 0.35
## How long it takes to open
@export var open_time: float = 0.35
## Angle that the black bars appear in degrees
@export var angle: float = 0.0

# 0.0 = no stagger (all bars together)
# 0.5 = last bar starts halfway through the total time
# keep < 1.0
@export_range(0.0, 0.999, 0.001) var cascade: float = 0.35

var _t: float = 0.0
var _phase: int = 0
# 0 = idle/open (hidden)
# 1 = closing (open -> black)
# 2 = black/closed (fully black, waiting)
# 3 = opening (black -> open)

func _ready() -> void:
	color = Color(0, 0, 0, 0) # transparent, we draw bars ourselves
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(false)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept") or _is_space_pressed(event):
		_toggle()

func _toggle() -> void:
	match _phase:
		0:
			_phase = 1
			_t = 0.0
			visible = true
			set_process(true)
			queue_redraw()
		1:
			_phase = 3
			visible = true
			set_process(true)
			queue_redraw()
		2:
			_phase = 3
			_t = 1.0
			visible = true
			set_process(true)
			queue_redraw()
		3:
			_phase = 1
			visible = true
			set_process(true)
			queue_redraw()

func _is_space_pressed(event: InputEvent) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE

func _process(delta: float) -> void:
	match _phase:
		1: # closing
			_t += delta / maxf(close_time, 0.0001)
			if _t >= 1.0:
				_t = 1.0
				_phase = 2
			queue_redraw()

		3: # opening
			_t -= delta / maxf(open_time, 0.0001)
			if _t <= 0.0:
				_t = 0.0
				_phase = 0
				set_process(false)
				visible = false
			queue_redraw()

func _draw() -> void:
	
	if bar_count <= 0 or _phase == 0:
		return

	var w := size.x
	var h := size.y
	var center := Vector2(w * 0.5, h * 0.5)

	var a := deg_to_rad(angle + 90)

	# Find the chord across the rect perpendicular to the bar direction
	var p0 := Geom2Util.ray_rect_intersection(0.0, 0.0, w, h, center.x, center.y, a + PI / 2.0)
	var p1 := Geom2Util.ray_rect_intersection(0.0, 0.0, w, h, center.x, center.y, a - PI / 2.0)

	var chord: Vector2 = p1 - p0
	var dist: float = chord.length()
	if dist <= 0.000001:
		return

	var stack_dir: Vector2 = chord / dist  # spacing direction (bar thickness axis)

	# Expand p0/p1 to cover the full rectangle projection along stack_dir
	var half_span: float = 0.5 * (absf(stack_dir.x) * w + absf(stack_dir.y) * h)
	var current_half: float = 0.5 * dist
	var delta: float = half_span - current_half
	if delta > 0.0:
		p0 -= stack_dir * delta
		p1 += stack_dir * delta

	# Recompute after changing p0/p1
	chord = p1 - p0
	dist = chord.length()
	
	
	var perp := Vector2(-stack_dir.y, stack_dir.x)  # bar length axis

	# Draw 2 extra bars to safely cover edges
	var total_bars: int = bar_count + 2

	var stripe_step := dist / float(total_bars)

	# Make bars long enough to cover the rect even when rotated (+ a tiny epsilon)
	var half_len := size.length() * 0.5 + 2.0

	# Stagger math
	var denom := maxf(1.0 - cascade, 0.00001)
	var cols := [Color.BLACK, Color.BLACK, Color.BLACK, Color.BLACK]

	for j in range(total_bars):
		var idx := float(j) # 0 .. total_bars-1

		# Bar 0 starts first, last bar starts last
		var offset := (idx / maxf(float(total_bars - 1), 1.0)) * cascade
		var local_t := clampf((_t - offset) / denom, 0.0, 1.0)

		var coverage := _smoothstep(local_t)
		var half_th := (stripe_step * 0.5) * coverage

		# Center of bar j
		var c := p0 + stack_dir * ((float(j) + 0.5) * stripe_step)

		var a_pt := c - stack_dir * half_th - perp * half_len
		var b_pt := c + stack_dir * half_th - perp * half_len
		var c_pt := c + stack_dir * half_th + perp * half_len
		var d_pt := c - stack_dir * half_th + perp * half_len

		draw_polygon([a_pt, b_pt, c_pt, d_pt], cols)


func _smoothstep(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)
