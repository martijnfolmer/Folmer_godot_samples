## Functions related to geometry operations (boxes, shapes, polygons, etc.).
class_name Geometry



## Computes the Intersection over Union (IoU) between two axis-aligned rectangles.
##
## Each rectangle is defined by its top-left and bottom-right corners.
## IoU is calculated as the area of the intersection divided by the area
## of the union of both rectangles. A value of 0.0 indicates no overlap,
## while 1.0 indicates identical rectangles. IoU is symmetric and will be 
## the same regardless of parameter order.
##
## @param point_top_left_1 The top-left corner of the first rectangle.
## @param point_bottom_right_1 The bottom-right corner of the first rectangle.
## @param point_top_left_2 The top-left corner of the second rectangle.
## @param point_bottom_right_2 The bottom-right corner of the second rectangle.
## @return A float in the range [0.0, 1.0] representing the IoU.
static func iou_vect(
		point_top_left_1: Vector2, point_bottom_right_1: Vector2,
		point_top_left_2: Vector2, point_bottom_right_2: Vector2
	) -> float:
	# Intersection rectangle
	var x_a := maxf(point_top_left_1.x, point_top_left_2.x)
	var y_a := maxf(point_top_left_1.y, point_top_left_2.y)
	var x_b := minf(point_bottom_right_1.x, point_bottom_right_2.x)
	var y_b := minf(point_bottom_right_1.y, point_bottom_right_2.y)
	
	# Intersection size (clamped to 0)
	var inter_w := maxf(0.0, x_b - x_a)
	var inter_h := maxf(0.0, y_b - y_a)
	var inter_area := inter_w * inter_h
	
	# Areas of each rectangle (clamped to 0 in case of bad inputs)
	var area_1 := maxf(0.0, point_bottom_right_1.x - point_top_left_1.x) * maxf(0.0, point_bottom_right_1.y - point_top_left_1.y)
	var area_2 := maxf(0.0, point_bottom_right_2.x - point_top_left_2.x) * maxf(0.0, point_bottom_right_2.y - point_top_left_2.y)
	
	# Union
	var union_area := area_1 + area_2 - inter_area
	if union_area <= 0.0:
		return 0.0

	return inter_area / union_area

## Computes the Intersection over Union (IoU) for two Rect2 objects.
## 
## IoU is calculated as the area of the intersection divided by the area
## of the union of both rectangles. A value of 0.0 indicates no overlap,
## while 1.0 indicates identical rectangles. IoU is symmetric and will be 
## the same regardless of parameter order
##
## @param box1 The first rectangle
## @param box2 The second rectangle
## @return A float in the range [0.0, 1.0] representing the IoU.
static func iou_rect(box1: Rect2, box2: Rect2) -> float:
	var inter := box1.intersection(box2)
	var inter_area := inter.get_area()
	
	if inter_area <= 0.0:
		return 0.0
	
	var union_area := box1.get_area() + box2.get_area() - inter_area
	if union_area <= 0.0:
		return 0.0
	
	return inter_area / union_area

## Gets the fractional area of [param rect1] that is overlapped by [param rect2].
##
## Note: This calculation is asymmetric. The overlap fraction of rect1 with rect2 
## is not the same as the overlap fraction of rect2 with rect1.
##
## @param rect1 The base rectangle whose area acts as the denominator.
## @param rect2 The overlapping rectangle.
## @return A float in the range [0.0, 1.0] representing the fraction of rect1 covered.
static func rect_overlap_fraction(rect1: Rect2, rect2: Rect2) -> float:
	var overlap := rect1.intersection(rect2)
	
	if overlap.size.x <= 0.0 or overlap.size.y <= 0.0:
		return 0.0
	
	var rect1_area := rect1.get_area()
	if rect1_area <= 0.0:
		return 0.0
	
	return overlap.get_area() / rect1_area
