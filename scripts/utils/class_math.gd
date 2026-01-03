# res://scripts/utils/class_math.gd
class_name math


## Returns `true` if the given point lies inside or on the border of the specified circle.
##
## @param point The point to test
## @param circle_center The center position of the circle.
## @param circle_radius The radius of the circle.
## @return `true` if the point is strictly inside the circle or on its border, `false` otherwise.
static func is_point_in_circle(point: Vector2, circle_center: Vector2, circle_radius: float) -> bool:
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
static func is_point_in_rectangle(point: Vector2, pointTopLeft: Vector2, pointBottomRight: Vector2) -> bool:
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
