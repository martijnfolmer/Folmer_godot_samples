# res://scripts/utils/func_easing.gd
class_name Easing

# For the function which doe not have _lerp, the variables are expected
	# t is expected to be in range [0.0, 1.0]
	# All functions return a value in [0.0, 1.0]
# For the functions which do have _lerp, 
	# t1<t2, x1<x2,
	# All functions return a value in [x1, x2]


# Easing functions

# -----------------
# Linear
# -----------------
static func linear(t: float) -> float:
	return t


# -----------------
# Quadratic
# -----------------
static func ease_in_quad(t: float) -> float:
	return t * t

static func ease_out_quad(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)

static func ease_in_out_quad(t: float) -> float:
	if t < 0.5:
		return 2.0 * t * t
	return 1.0 - pow(-2.0 * t + 2.0, 2) / 2.0


# -----------------
# Cubic
# -----------------
static func ease_in_cubic(t: float) -> float:
	return t * t * t

static func ease_out_cubic(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3)

static func ease_in_out_cubic(t: float) -> float:
	if t < 0.5:
		return 4.0 * t * t * t
	return 1.0 - pow(-2.0 * t + 2.0, 3) / 2.0


# -----------------
# Quartic
# -----------------
static func ease_in_quart(t: float) -> float:
	return pow(t, 4)

static func ease_out_quart(t: float) -> float:
	return 1.0 - pow(1.0 - t, 4)

static func ease_in_out_quart(t: float) -> float:
	if t < 0.5:
		return 8.0 * pow(t, 4)
	return 1.0 - pow(-2.0 * t + 2.0, 4) / 2.0


# -----------------
# Quintic
# -----------------
static func ease_in_quint(t: float) -> float:
	return pow(t, 5)

static func ease_out_quint(t: float) -> float:
	return 1.0 - pow(1.0 - t, 5)

static func ease_in_out_quint(t: float) -> float:
	if t < 0.5:
		return 16.0 * pow(t, 5)
	return 1.0 - pow(-2.0 * t + 2.0, 5) / 2.0


# -----------------
# Sine
# -----------------
static func ease_in_sine(t: float) -> float:
	return 1.0 - cos((t * PI) / 2.0)

static func ease_out_sine(t: float) -> float:
	return sin((t * PI) / 2.0)

static func ease_in_out_sine(t: float) -> float:
	return -(cos(PI * t) - 1.0) / 2.0


# -----------------
# Exponential
# -----------------
static func ease_in_expo(t: float) -> float:
	if t == 0.0:
		return 0.0
	return pow(2.0, 10.0 * t - 10.0)

static func ease_out_expo(t: float) -> float:
	if t == 1.0:
		return 1.0
	return 1.0 - pow(2.0, -10.0 * t)

static func ease_in_out_expo(t: float) -> float:
	if t == 0.0:
		return 0.0
	if t == 1.0:
		return 1.0
	if t < 0.5:
		return pow(2.0, 20.0 * t - 10.0) / 2.0
	return (2.0 - pow(2.0, -20.0 * t + 10.0)) / 2.0


# -----------------
# Circular
# -----------------
static func ease_in_circ(t: float) -> float:
	return 1.0 - sqrt(1.0 - t * t)

static func ease_out_circ(t: float) -> float:
	return sqrt(1.0 - pow(t - 1.0, 2))

static func ease_in_out_circ(t: float) -> float:
	if t < 0.5:
		return (1.0 - sqrt(1.0 - pow(2.0 * t, 2))) / 2.0
	return (sqrt(1.0 - pow(-2.0 * t + 2.0, 2)) + 1.0) / 2.0
	
	
# -----------------
# Back
# -----------------
static func ease_in_back(t: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return c3 * t * t * t - c1 * t * t

static func ease_out_back(t: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(t - 1.0, 3) + c1 * pow(t - 1.0, 2)

static func ease_in_out_back(t: float) -> float:
	var c1 := 1.70158
	var c2 := c1 * 1.525

	if t < 0.5:
		return (pow(2.0 * t, 2) * ((c2 + 1.0) * 2.0 * t - c2)) / 2.0
	return (pow(2.0 * t - 2.0, 2) * ((c2 + 1.0) * (t * 2.0 - 2.0) + c2) + 2.0) / 2.0


# -----------------
# Elastic
# -----------------
static func ease_in_elastic(t: float) -> float:
	if t == 0.0:
		return 0.0
	if t == 1.0:
		return 1.0

	var c4 := (2.0 * PI) / 3.0
	return -pow(2.0, 10.0 * t - 10.0) * sin((t * 10.0 - 10.75) * c4)

static func ease_out_elastic(t: float) -> float:
	if t == 0.0:
		return 0.0
	if t == 1.0:
		return 1.0

	var c4 := (2.0 * PI) / 3.0
	return pow(2.0, -10.0 * t) * sin((t * 10.0 - 0.75) * c4) + 1.0

static func ease_in_out_elastic(t: float) -> float:
	if t == 0.0:
		return 0.0
	if t == 1.0:
		return 1.0

	var c5 := (2.0 * PI) / 4.5

	if t < 0.5:
		return -(pow(2.0, 20.0 * t - 10.0) * sin((20.0 * t - 11.125) * c5)) / 2.0
	return (pow(2.0, -20.0 * t + 10.0) * sin((20.0 * t - 11.125) * c5)) / 2.0 + 1.0


# -----------------
# Bounce
# -----------------
static func ease_out_bounce(t: float) -> float:
	var n1 := 7.5625
	var d1 := 2.75

	if t < 1.0 / d1:
		return n1 * t * t
	elif t < 2.0 / d1:
		t -= 1.5 / d1
		return n1 * t * t + 0.75
	elif t < 2.5 / d1:
		t -= 2.25 / d1
		return n1 * t * t + 0.9375
	else:
		t -= 2.625 / d1
		return n1 * t * t + 0.984375

static func ease_in_bounce(t: float) -> float:
	return 1.0 - ease_out_bounce(1.0 - t)

static func ease_in_out_bounce(t: float) -> float:
	if t < 0.5:
		return (1.0 - ease_out_bounce(1.0 - 2.0 * t)) / 2.0
	return (1.0 + ease_out_bounce(2.0 * t - 1.0)) / 2.0
	

# -----------------
# Lerp wrappers (t1, t2 -> normalized t; x1..x2 -> interpolated value)
# -----------------

static func _norm_t(t1: float, t2: float) -> float:
	if t2 == 0.0:
		return 0.0
	return clamp(t1 / t2, 0.0, 1.0)

static func _lerp_eased(eased_t: float, x1: float, x2: float) -> float:
	return x1 + (x2 - x1) * eased_t


# Linear
static func linear_lerp(t1: float, t2: float, x1: float, x2: float) -> float:
	return _lerp_eased(linear(_norm_t(t1, t2)), x1, x2)

# Quadratic
static func ease_in_quad_lerp(t1: float, t2: float, x1: float, x2: float) -> float:
	return _lerp_eased(ease_in_quad(_norm_t(t1, t2)), x1, x2)

static func ease_out_quad_lerp(t1: float, t2: float, x1: float, x2: float) -> float:
	return _lerp_eased(ease_out_quad(_norm_t(t1, t2)), x1, x2)

static func ease_in_out_quad_lerp(t1: float, t2: float, x1: float, x2: float) -> float:
	return _lerp_eased(ease_in_out_quad(_norm_t(t1, t2)), x1, x2)

# Cubic
static func ease_in_cubic_lerp(t1: float, t2: float, x1: float, x2: float) -> float:
	return _lerp_eased(ease_in_cubic(_norm_t(t1, t2)), x1, x2)

static func ease_out_cubic_lerp(t1: float, t2: float, x1: float, x2: float) -> float:
	return _lerp_eased(ease_out_cubic(_norm_t(t1, t2)), x1, x2)

static func ease_in_out_cubic_lerp(t1: float, t2: float, x1: float, x2: float) -> float:
	return _lerp_eased(ease_in_out_cubic(_norm_t(t1, t2)), x1, x2)

# Quartic
static func ease_in_quart_lerp(t1: float, t2: float, x1: float, x2: float) -> float:
	return _lerp_eased(ease_in_quart(_norm_t(t1, t2)), x1, x2)

static func ease_out_quart_lerp(t1: float, t2: float, x1: float, x2: float) -> float:
	return _lerp_eased(ease_out_quart(_norm_t(t1, t2)), x1, x2)

static func ease_in_out_quart_lerp(t1: float, t2: float, x1: float, x2: float) -> float:
	return _lerp_eased(ease_in_out_quart(_norm_t(t1, t2)), x1, x2)

# Quintic
static func ease_in_quint_lerp(t1: float, t2: float, x1: float, x2: float) -> float:
	return _lerp_eased(ease_in_quint(_norm_t(t1, t2)), x1, x2)

static func ease_out_quint_lerp(t1: float, t2: float, x1: float, x2: float) -> float:
	return _lerp_eased(ease_out_quint(_norm_t(t1, t2)), x1, x2)

static func ease_in_out_quint_lerp(t1: float, t2: float, x1: float, x2: float) -> float:
	return _lerp_eased(ease_in_out_quint(_norm_t(t1, t2)), x1, x2)

# Sine
static func ease_in_sine_lerp(t1: float, t2: float, x1: float, x2: float) -> float:
	return _lerp_eased(ease_in_sine(_norm_t(t1, t2)), x1, x2)

static func ease_out_sine_lerp(t1: float, t2: float, x1: float, x2: float) -> float:
	return _lerp_eased(ease_out_sine(_norm_t(t1, t2)), x1, x2)

static func ease_in_out_sine_lerp(t1: float, t2: float, x1: float, x2: float) -> float:
	return _lerp_eased(ease_in_out_sine(_norm_t(t1, t2)), x1, x2)

# Exponential
static func ease_in_expo_lerp(t1: float, t2: float, x1: float, x2: float) -> float:
	return _lerp_eased(ease_in_expo(_norm_t(t1, t2)), x1, x2)

static func ease_out_expo_lerp(t1: float, t2: float, x1: float, x2: float) -> float:
	return _lerp_eased(ease_out_expo(_norm_t(t1, t2)), x1, x2)

static func ease_in_out_expo_lerp(t1: float, t2: float, x1: float, x2: float) -> float:
	return _lerp_eased(ease_in_out_expo(_norm_t(t1, t2)), x1, x2)

# Circular
static func ease_in_circ_lerp(t1: float, t2: float, x1: float, x2: float) -> float:
	return _lerp_eased(ease_in_circ(_norm_t(t1, t2)), x1, x2)

static func ease_out_circ_lerp(t1: float, t2: float, x1: float, x2: float) -> float:
	return _lerp_eased(ease_out_circ(_norm_t(t1, t2)), x1, x2)

static func ease_in_out_circ_lerp(t1: float, t2: float, x1: float, x2: float) -> float:
	return _lerp_eased(ease_in_out_circ(_norm_t(t1, t2)), x1, x2)

# Back
static func ease_in_back_lerp(t1: float, t2: float, x1: float, x2: float) -> float:
	return _lerp_eased(ease_in_back(_norm_t(t1, t2)), x1, x2)

static func ease_out_back_lerp(t1: float, t2: float, x1: float, x2: float) -> float:
	return _lerp_eased(ease_out_back(_norm_t(t1, t2)), x1, x2)

static func ease_in_out_back_lerp(t1: float, t2: float, x1: float, x2: float) -> float:
	return _lerp_eased(ease_in_out_back(_norm_t(t1, t2)), x1, x2)

# Elastic
static func ease_in_elastic_lerp(t1: float, t2: float, x1: float, x2: float) -> float:
	return _lerp_eased(ease_in_elastic(_norm_t(t1, t2)), x1, x2)

static func ease_out_elastic_lerp(t1: float, t2: float, x1: float, x2: float) -> float:
	return _lerp_eased(ease_out_elastic(_norm_t(t1, t2)), x1, x2)

static func ease_in_out_elastic_lerp(t1: float, t2: float, x1: float, x2: float) -> float:
	return _lerp_eased(ease_in_out_elastic(_norm_t(t1, t2)), x1, x2)

# Bounce
static func ease_out_bounce_lerp(t1: float, t2: float, x1: float, x2: float) -> float:
	return _lerp_eased(ease_out_bounce(_norm_t(t1, t2)), x1, x2)

static func ease_in_bounce_lerp(t1: float, t2: float, x1: float, x2: float) -> float:
	return _lerp_eased(ease_in_bounce(_norm_t(t1, t2)), x1, x2)

static func ease_in_out_bounce_lerp(t1: float, t2: float, x1: float, x2: float) -> float:
	return _lerp_eased(ease_in_out_bounce(_norm_t(t1, t2)), x1, x2)
