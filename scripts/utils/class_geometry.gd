# Geom2Util.gd (Godot 4.x)
class_name Geom2Util
extends Object

# -----------------------------
# Lines / segments
# -----------------------------

## Closest point on an infinite line through a->b to point p.
static func closest_point_on_line(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab := b - a
	var denom := ab.length_squared()
	if denom == 0.0:
		return a
	var t := (p - a).dot(ab) / denom
	return a + ab * t

## Closest point on a segment [a,b] to point p.
static func closest_point_on_segment(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab := b - a
	var denom := ab.length_squared()
	if denom == 0.0:
		return a
	var t := (p - a).dot(ab) / denom
	t = clamp(t, 0.0, 1.0)
	return a + ab * t

## Intersection line and rectangle border
# Returns the point where a ray from the rectangle center at angle theta intersects the rectangle border.
# Rect is axis-aligned and given by corners (x1,y1) and (x2,y2).
static func ray_rect_intersection(
		x1: float, y1: float,
		x2: float, y2: float,
		xc: float, yc: float,
		theta: float
	) -> Vector2:

	var left: float = minf(x1, x2)
	var right: float = maxf(x1, x2)
	var top: float = minf(y1, y2)
	var bottom: float = maxf(y1, y2)

	var origin: Vector2 = Vector2(xc, yc)
	var dir: Vector2 = Vector2(cos(theta), sin(theta))

	# Direction is too small -> no meaningful ray
	if dir.length_squared() < 1e-16:
		return origin

	var tmin: float = -INF
	var tmax: float = INF

	# X slab
	if absf(dir.x) < 1e-12:
		# Ray parallel to Y axis: origin must be within x bounds
		if origin.x < left or origin.x > right:
			return origin
	else:
		var tx1: float = (left - origin.x) / dir.x
		var tx2: float = (right - origin.x) / dir.x
		var txmin: float = minf(tx1, tx2)
		var txmax: float = maxf(tx1, tx2)
		tmin = maxf(tmin, txmin)
		tmax = minf(tmax, txmax)

	# Y slab
	if absf(dir.y) < 1e-12:
		# Ray parallel to X axis: origin must be within y bounds
		if origin.y < top or origin.y > bottom:
			return origin
	else:
		var ty1: float = (top - origin.y) / dir.y
		var ty2: float = (bottom - origin.y) / dir.y
		var tymin: float = minf(ty1, ty2)
		var tymax: float = maxf(ty1, ty2)
		tmin = maxf(tmin, tymin)
		tmax = minf(tmax, tymax)

	# No overlap => no intersection
	if tmax < tmin:
		return origin

	# First hit in forward direction. If origin is inside rect, tmin < 0 and tmax is the exit.
	var t_hit: float = tmax
	if tmin >= 0.0:
		t_hit = tmin

	if t_hit < 0.0 or is_inf(t_hit):
		return origin

	return origin + dir * t_hit

# -----------------------------
# Point in polygon / closest to polygon
# -----------------------------

## Ray-casting point-in-polygon.
## include_boundary=true treats points on edges as inside.
static func point_in_polygon(p: Vector2, poly: PackedVector2Array, include_boundary: bool = true) -> bool:
	var n := poly.size()
	if n < 3:
		return false

	# check if the point is on any of the line segment.
	if include_boundary:	
		for i in n:
			if point_on_segment(p, poly[i], poly[(i + 1) % n]):
				return true

	var inside := false
	var j := n - 1
	for i in n:
		var pi := poly[i]
		var pj := poly[j]
		if ((pi.y > p.y) != (pj.y > p.y)):
			var x_at_y := (pj.x - pi.x) * (p.y - pi.y) / (pj.y - pi.y) + pi.x
			if p.x < x_at_y:
				inside = !inside
		j = i

	return inside

## Closest point on or in polygon to p:
## - if p is inside (or on boundary), returns p
## - otherwise returns closest point on polygon edges
static func closest_point_to_polygon(p: Vector2, poly: PackedVector2Array, include_boundary: bool = true) -> Vector2:
	if point_in_polygon(p, poly, include_boundary):
		return p

	var n := poly.size()
	if n == 0:
		return p # polygon is empty, just return the point again
	if n == 1:
		return poly[0]  # polygon is only 1 point, so return that

	var best := Vector2.ZERO
	var best_d2 := INF

	# for each poly line, check what the closests point is, and if this is closer than the 
	# closest point we have found so far
	for i in n:
		var q := closest_point_on_segment(p, poly[i], poly[(i + 1) % n])
		var d2 := p.distance_squared_to(q)
		if d2 < best_d2:
			best_d2 = d2
			best = q

	return best

#region Intersection
##############
# Intersection
###############

## Checks if two bounded lines intersect or not
static func line_intersects_line(x1: float, y1: float, x2: float, y2: float,
								x3: float, y3: float, x4: float, y4: float) -> bool:
	var p := Vector2(x1, y1)
	var r := Vector2(x2 - x1, y2 - y1)

	var q := Vector2(x3, y3)
	var s := Vector2(x4 - x3, y4 - y3)

	var rxs := r.cross(s)
	var q_p := q - p
	var qpxr := q_p.cross(r)

	# Collinear
	if is_zero_approx(rxs) and is_zero_approx(qpxr):
		var r_dot_r := r.dot(r)
		if is_zero_approx(r_dot_r):
			return p == q

		var t0 := q_p.dot(r) / r_dot_r
		var t1 := t0 + s.dot(r) / r_dot_r

		if t0 > t1:
			var temp := t0
			t0 = t1
			t1 = temp

		return t0 <= 1.0 and t1 >= 0.0

	# Parallel but not collinear
	if is_zero_approx(rxs):
		return false

	var t := q_p.cross(s) / rxs
	var u := q_p.cross(r) / rxs

	return t >= 0.0 and t <= 1.0 and u >= 0.0 and u <= 1.0

## Checks if a bounded line intersects with a rectangle
static func line_intersects_rect(x1: float, y1: float,x2: float, y2: float,rect: Rect2) -> bool:
	var p1 := Vector2(x1, y1)
	var p2 := Vector2(x2, y2)

	# If either endpoint is inside the rectangle
	if rect.has_point(p1) or rect.has_point(p2):
		return true

	var left := rect.position.x
	var right := rect.position.x + rect.size.x
	var top := rect.position.y
	var bottom := rect.position.y + rect.size.y

	# Check against all 4 rectangle edges
	return (
		line_intersects_line(x1, y1, x2, y2, left, top, right, top) or
		line_intersects_line(x1, y1, x2, y2, right, top, right, bottom) or
		line_intersects_line(x1, y1, x2, y2, right, bottom, left, bottom) or
		line_intersects_line(x1, y1, x2, y2, left, bottom, left, top)
	)

## Check if a bounded line intersects with a circle 
static func line_intersects_circle(x1: float, y1: float,x2: float, y2: float,circle_center: Vector2,radius: float) -> bool:
	var a := Vector2(x1, y1)
	var b := Vector2(x2, y2)

	var ab := b - a
	var ac := circle_center - a

	var ab_len_sq := ab.length_squared()

	# Degenerate line: the segment is just a point
	if is_zero_approx(ab_len_sq):
		return a.distance_squared_to(circle_center) <= radius * radius

	# Project circle center onto the bounded segment
	var t := ac.dot(ab) / ab_len_sq
	t = clamp(t, 0.0, 1.0)

	var closest_point := a + ab * t

	return closest_point.distance_squared_to(circle_center) <= radius * radius
#endregion

# -----------------------------
# Overlaps
# -----------------------------

## Polygon overlap
##
## @param a: First polygon to check
## @param b: Second polygon to check
## @return True if the polygons overlap, False if they do not
static func polygons_overlap(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	if a.size() < 3 or b.size() < 3:
		return false

	# Any intersection polygons == overlap.
	if Geometry2D.intersect_polygons(a, b).size() > 0:
		return true

	# Or complete containment.
	return point_in_polygon(a[0], b, true) or point_in_polygon(b[0], a, true)

## Circle-circle overlap.
##
## @param c0: center coordinates of first circle
## @param r0: radius of the first circle
## @param c1: center coordinate of the second circle
## @param r1: radius of the second circle
## @return: True if the circles overlap, False if they are not
static func circles_overlap(c0: Vector2, r0: float, c1: Vector2, r1: float) -> bool:
	var rr := r0 + r1
	return c0.distance_squared_to(c1) <= rr * rr

## Axis-aligned rectangle overlap
##
## @param r0: first rectangle to overlap
## @param r1: second rectangle to overlap
## @return : True if rectangles overlap, False if not
static func rects_overlap(r0: Rect2, r1: Rect2) -> bool:
	return r0.intersects(r1, true)

## Circle vs axis-aligned rect overlap.
##
## @param center: Center point of the circle
## @param radius: Radius of the circle
## @param rect: rectangle defined by position.x, position.y, size.x, size.y
## @return: True if the circle overlaps with the rectangle, false if not
static func circle_overlaps_rect(center: Vector2, radius: float, rect: Rect2) -> bool:
	var closest := Vector2(
		clamp(center.x, rect.position.x, rect.position.x + rect.size.x),
		clamp(center.y, rect.position.y, rect.position.y + rect.size.y)
	)
	return center.distance_squared_to(closest) <= radius * radius


## Check if point is on segment
##
## @param p: The point to test
## @param a: (x1, x1) start of the line segment
## @param b: (x2, y2) end of the line segment
## @param eps: Allowed offset from the line
## @return: Return true if a point p is on a segment between point a and point b, within epsilon offset
static func point_on_segment(p: Vector2, a: Vector2, b: Vector2, eps: float = 0.00001) -> bool:
	# direction vector
	var ab := b - a
	var ap := p - a

	# Colinear : meaning if the points are on the same line
	if abs(ab.cross(ap)) > eps:
		return false

	# Within [a,b] bounds?
	var t := ap.dot(ab)
	if t < -eps:
		return false
	
	var ab_len2 := ab.length_squared()
	if t > ab_len2 + eps:
		return false

	return true

## Check if a point is inside of a circle
##
## @param point The point to test
## @param circle_center The center position of the circle.
## @param circle_radius The radius of the circle.
## @return `true` if the point is strictly inside the circle or on its border, `false` otherwise.
static func point_in_circle(point: Vector2, circle_center: Vector2, circle_radius: float) -> bool:
	return point.distance_to(circle_center) <= circle_radius

## Check if a point is inside of a rectangle
##
## The rectangle is defined by two opposite corners (`pointTopLeft` and
## `pointBottomRight`). The function is robust to corner order and will
## correctly handle cases where the points are not strictly top-left
## and bottom-right.
##
## @param point The point to test.
## @param pointTopLeft One corner of the rectangle.
## @param pointBottomRight The opposite corner of the rectangle.
## @return `true` if the point is inside or on the rectangle border, `false` otherwise.
static func point_in_rectangle(point: Vector2, pointTopLeft: Vector2, pointBottomRight: Vector2) -> bool:
	var min_x = min(pointTopLeft.x, pointBottomRight.x)
	var max_x = max(pointTopLeft.x, pointBottomRight.x)
	var min_y = min(pointTopLeft.y, pointBottomRight.y)
	var max_y = max(pointTopLeft.y, pointBottomRight.y)
		
	return point.x >= min_x and point.x <=max_x and point.y >= min_y and point.y <= max_y

## Computes the Intersection over Union (IoU) between two axis-aligned rectangles.
##
## Each rectangle is defined by its top-left and bottom-right corners.
## IoU is calculated as the area of the intersection divided by the area
## of the union of both rectangles. A value of `0.0` indicates no overlap,
## while `1.0` indicates identical rectangles.
##
## @param pointTopLeft1 The top-left corner of the first rectangle.
## @param pointBottomRight1 The bottom-right corner of the first rectangle.
## @param pointTopLeft2 The top-left corner of the second rectangle.
## @param pointBottomRight2 The bottom-right corner of the second rectangle.
## @return A value in the range [0.0, 1.0] representing the IoU.
static func IOU_vect(
		pointTopLeft1: Vector2, pointBottomRight1: Vector2,
		pointTopLeft2: Vector2, pointBottomRight2: Vector2
	) -> float:
	# Intersection rectangle
	var xA = max(pointTopLeft1.x, pointTopLeft2.x)
	var yA = max(pointTopLeft1.y, pointTopLeft2.y)
	var xB = min(pointBottomRight1.x, pointBottomRight2.x)
	var yB = min(pointBottomRight1.y, pointBottomRight2.y)

	# Intersection size (clamped to 0)
	var inter_w = max(0.0, xB - xA)
	var inter_h = max(0.0, yB - yA)
	var inter_area = inter_w * inter_h

	# Areas of each rectangle (clamped to 0 in case of bad inputs)
	var area1 = max(0.0, pointBottomRight1.x - pointTopLeft1.x) * max(0.0, pointBottomRight1.y - pointTopLeft1.y)
	var area2 = max(0.0, pointBottomRight2.x - pointTopLeft2.x) * max(0.0, pointBottomRight2.y - pointTopLeft2.y)

	# Union
	var union_area = area1 + area2 - inter_area
	if union_area <= 0.0:
		return 0.0

	return inter_area / union_area

## Get the intersection over union for two rectangles [0, 1]
static func IOU_rect(box1: Rect2, box2: Rect2) -> float:
	var inter := box1.intersection(box2)
	var inter_area := inter.get_area()

	if inter_area <= 0.0:
		return 0.0

	var union_area := box1.get_area() + box2.get_area() - inter_area
	if union_area <= 0.0:
		return 0.0

	return inter_area / union_area
	
	
# points: Array[Vector2] or PackedVector2Array
## Returns the polygon area as a positive float.	
static func polygon_area(points: PackedVector2Array) -> float:

	if points.size() < 3:
		return 0.0

	var sum := 0.0
	var count := points.size()

	for i in count:
		var j := (i + 1) % count
		sum += points[i].x * points[j].y
		sum -= points[j].x * points[i].y

	return abs(sum) * 0.5
