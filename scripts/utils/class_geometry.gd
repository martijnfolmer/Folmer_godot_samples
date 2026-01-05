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


# -----------------------------
# Overlaps
# -----------------------------

## Polygon overlap (true if they intersect or one contains the other)
## Partly uses godot build in
static func polygons_overlap(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	if a.size() < 3 or b.size() < 3:
		return false

	# Any intersection polygons == overlap.
	if Geometry2D.intersect_polygons(a, b).size() > 0:
		return true

	# Or complete containment.
	return point_in_polygon(a[0], b, true) or point_in_polygon(b[0], a, true)

## Circle-circle overlap.
## distance_squared_to returns faster than distance_to,
static func circles_overlap(c0: Vector2, r0: float, c1: Vector2, r1: float) -> bool:
	var rr := r0 + r1
	return c0.distance_squared_to(c1) <= rr * rr

## Axis-aligned rectangle overlap (Rect2 vs Rect2)
## Using build-in functionality, but including it for completeness
static func rects_overlap(r0: Rect2, r1: Rect2) -> bool:
	return r0.intersects(r1, true)

## Circle vs axis-aligned rect overlap (often handy).
## distance_squared_to returns faster than distance_to,
static func circle_overlaps_rect(center: Vector2, radius: float, rect: Rect2) -> bool:
	var closest := Vector2(
		clamp(center.x, rect.position.x, rect.position.x + rect.size.x),
		clamp(center.y, rect.position.y, rect.position.y + rect.size.y)
	)
	return center.distance_squared_to(closest) <= radius * radius


##Return true if a point p is on a segment between point a and point b, with epsilon
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


## Returns `true` if the given point lies inside or on the border of the specified circle.
##
## @param point The point to test
## @param circle_center The center position of the circle.
## @param circle_radius The radius of the circle.
## @return `true` if the point is strictly inside the circle or on its border, `false` otherwise.
static func point_in_circle(point: Vector2, circle_center: Vector2, circle_radius: float) -> bool:
	return point.distance_to(circle_center) <= circle_radius

## Returns `true` if the given point lies inside or on the border of the specified rectangle.
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
## @return A value in the range `[0.0, 1.0]` representing the IoU.
static func IOU(
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
