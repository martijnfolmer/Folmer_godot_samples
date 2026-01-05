# Folmer_godot_samples
A collection of Sample scenes, scripts, that can be used in godot projects (mostly for my own education, but feel free
to use any of it if you wish)
It should be noted that there can be overlap between these samples and build in godot functionality. 
This is an ongoing project and will be updated regularly


## Easing
Common easing functions, created in gdscript in scripts/utils/class_easing, and their visualisations.
NOTE  There are build-in versions of these easing functions in godot, more information can be found here : https://docs.godotengine.org/en/stable/classes/class_tween.html
![Visualisations of different easing functions](README_IMG/img.png)

## Geometry
Some common geometry functions for gamedev

### closest_point_on_line(p, a, b) 
Returns the nearest point to p on the infinite line through a→b (or a if degenerate).
### closest_point_on_segment(p, a, b) 
Returns the nearest point to p on the segment [a, b] (or a if degenerate).
### point_in_polygon(p, poly, include_boundary=true) 
Returns true if p is inside poly using ray casting (optionally counting boundary points).
### closest_point_to_polygon(p, poly, include_boundary=true) 
Returns p if inside/on poly, otherwise the closest point on any polygon edge.
### polygons_overlap(a, b) 
Returns true if polygons a and b intersect or one contains the other.
### circles_overlap(c0, r0, c1, r1) 
Returns true if two circles overlap or touch.
### rects_overlap(r0, r1)
 Returns true if two axis-aligned rectangles overlap or touch.
### circle_overlaps_rect(center, radius, rect) 
Returns true if a circle overlaps or touches an axis-aligned rectangle.
### point_on_segment(p, a, b, eps=0.00001) 
Returns true if p lies on segment [a, b] within epsilon tolerance.
### point_in_circle
Returns true if point is in circle or on the border of it
### point_in_rectangle
Returns true if point is in rectangle or on the border of it
### IOU
Intersection over union, tells you how much two rectangles overlap
