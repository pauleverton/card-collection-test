class_name TypeIcon
extends Control
## A small icon drawn in code: shield = defending, target = attacking, chevrons = move,
## plus = utility, sparkle = skills, gloves = goalkeeper, clock = a timed ability ("FROM 75'").
## badge = true: white icon on a round badge in the type's colour (players' and coaches'
## card type). Otherwise just the icon, in `colour`. Scales to whatever size it's given.

const CLOCK_GREEN := Color("1f9e4a")        ## the clock on paper
const CLOCK_GREEN_LIGHT := Color("4cd97a")  ## the clock on dark tiles
const BADGE_RING := Color(1, 1, 1, 0.85)

var kind := "defending"
var colour := Color.WHITE
var badge := false

## Make one: TypeIcon.make("defending", 56, true) for a badge, or
## TypeIcon.make("clock", 18, false, TypeIcon.CLOCK_GREEN) for a plain icon.
static func make(kind_name: String, icon_size: float, is_badge: bool, icon_colour: Color = Color.WHITE) -> TypeIcon:
	var icon := TypeIcon.new()
	icon.kind = kind_name
	icon.badge = is_badge
	icon.colour = icon_colour
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

func _draw() -> void:
	var side := minf(size.x, size.y)
	var centre := Vector2(side, side) / 2.0
	var ink := colour
	var half := side / 2.0                    ## half the size of the icon's own box
	if badge:
		draw_circle(centre, side / 2.0, CardTags.TYPE_COLOURS.get(kind, Color("5a635c")))
		draw_arc(centre, side / 2.0 - side * 0.08, 0, TAU, 48, BADGE_RING, maxf(1.5, side * 0.04), true)
		ink = Color.WHITE
		half = side * 0.3
	var unit := half * 2.0 / 24.0             ## the icons are drawn on a 24 × 24 grid
	var width := maxf(1.5, 2.4 * unit)
	match kind:
		"defending":
			_shape(centre, unit, [Vector2(12, 3), Vector2(19.5, 6), Vector2(19.5, 12), Vector2(18.5, 15.5),
					Vector2(16, 18.5), Vector2(12, 21), Vector2(8, 18.5), Vector2(5.5, 15.5),
					Vector2(4.5, 12), Vector2(4.5, 6), Vector2(12, 3)], ink, width)
		"attacking":
			draw_arc(centre, 8.5 * unit, 0, TAU, 32, ink, width, true)
			draw_arc(centre, 4.0 * unit, 0, TAU, 24, ink, width, true)
			draw_circle(centre, 1.2 * unit, ink)
		"move":
			_shape(centre, unit, [Vector2(5, 6), Vector2(11, 12), Vector2(5, 18)], ink, width)
			_shape(centre, unit, [Vector2(13, 6), Vector2(19, 12), Vector2(13, 18)], ink, width)
		"utility":
			draw_arc(centre, 8.5 * unit, 0, TAU, 32, ink, width, true)
			_shape(centre, unit, [Vector2(12, 7.5), Vector2(12, 16.5)], ink, width)
			_shape(centre, unit, [Vector2(7.5, 12), Vector2(16.5, 12)], ink, width)
		"skills":
			_shape(centre, unit, [Vector2(12, 3.5), Vector2(12, 20.5)], ink, width)
			_shape(centre, unit, [Vector2(3.5, 12), Vector2(20.5, 12)], ink, width)
			_shape(centre, unit, [Vector2(7, 7), Vector2(17, 17)], ink, width * 0.7)
			_shape(centre, unit, [Vector2(17, 7), Vector2(7, 17)], ink, width * 0.7)
		"goalkeeper":
			## A pair of keeper's gloves, thumbs facing in.
			var cut: Color = CardTags.TYPE_COLOURS.get(kind, Color("5a635c")) if badge else Color.TRANSPARENT
			_draw_glove(centre, unit, ink, false, cut)
			_draw_glove(centre, unit, ink, true, cut)
		"clock":
			draw_arc(centre, 8.5 * unit, 0, TAU, 32, ink, width, true)
			_shape(centre, unit, [Vector2(12, 7), Vector2(12, 12), Vector2(15.5, 14)], ink, width)

## Keeper's gloves on the 24 × 24 grid: the LEFT glove (the right one is its mirror image).
## Four chunky splayed fingers, a padded palm, the thumb out towards the middle, and the big
## wrist strap that makes them read as keeper's gloves. Tilted outwards by GLOVE_TILT.
const GLOVE_PALM := [Vector2(2.8, 10.2), Vector2(9.3, 10.2), Vector2(9.3, 16.8), Vector2(2.8, 16.8)]
const GLOVE_THUMB := [Vector2(8.8, 15.8), Vector2(8.8, 12.0), Vector2(10.0, 10.2), Vector2(10.9, 8.9),
		Vector2(12.0, 9.5), Vector2(11.5, 11.4), Vector2(10.4, 14.6)]
const GLOVE_STRAP := [Vector2(2.1, 16.4), Vector2(10.0, 16.4), Vector2(10.0, 21.0), Vector2(2.1, 21.0)]
## Fingers: [left edge, right edge, how high the tip reaches]. Outer (little finger) first.
const GLOVE_FINGERS := [[2.8, 4.35, 6.2], [4.45, 6.0, 4.5], [6.1, 7.65, 3.9], [7.75, 9.3, 4.9]]
const GLOVE_STRAP_LINE := [Vector2(7.2, 16.9), Vector2(7.2, 20.5)]   ## the velcro tab
## Short lines between the fingers (badge only), from just below the tips down into the palm.
const GLOVE_FINGER_GAPS := [[Vector2(4.4, 6.8), Vector2(4.4, 9.4)], [Vector2(6.05, 5.8), Vector2(6.05, 9.4)],
		[Vector2(7.7, 6.2), Vector2(7.7, 9.4)]]
const GLOVE_PIVOT := Vector2(6.0, 21.0)
const GLOVE_TILT := -0.16         ## radians (about 9°); negative leans the left glove left

## A point on the left glove, tilted, and flipped left to right for the right glove.
func _glove_point(p: Vector2, mirror: bool) -> Vector2:
	var q := GLOVE_PIVOT + (p - GLOVE_PIVOT).rotated(GLOVE_TILT)
	return Vector2(24 - q.x, q.y) if mirror else q

## A solid shape from glove points.
func _glove_fill(centre: Vector2, unit: float, points: Array, ink: Color, mirror: bool) -> void:
	var shape := PackedVector2Array()
	for p in points:
		shape.append(centre + (_glove_point(p, mirror) - Vector2(12, 12)) * unit)
	draw_colored_polygon(shape, ink)
	shape.append(shape[0])
	draw_polyline(shape, ink, maxf(1.0, 0.45 * unit), true)   ## a soft edge (the fill alone is jagged)

## One whole glove, solid. On a badge the strap's edge and velcro tab are cut out in the
## badge colour (`cut`); as a plain icon it's a silhouette.
func _draw_glove(centre: Vector2, unit: float, ink: Color, mirror: bool, cut: Color) -> void:
	_glove_fill(centre, unit, GLOVE_PALM, ink, mirror)
	_glove_fill(centre, unit, GLOVE_THUMB, ink, mirror)
	for f in GLOVE_FINGERS:
		var r: float = (f[1] - f[0]) / 2.0
		## a finger = a bar up from the palm with a round tip
		_glove_fill(centre, unit, [Vector2(f[0], 10.6), Vector2(f[0], f[2] + r),
				Vector2(f[1], f[2] + r), Vector2(f[1], 10.6)], ink, mirror)
		var tip := _glove_point(Vector2((f[0] + f[1]) / 2.0, f[2] + r), mirror)
		draw_circle(centre + (tip - Vector2(12, 12)) * unit, r * unit, ink, true, -1.0, true)
	_glove_fill(centre, unit, GLOVE_STRAP, ink, mirror)
	if cut.a == 0.0:
		return
	var cut_width := maxf(1.0, 0.5 * unit)
	var top := [Vector2(2.1, 16.4), Vector2(10.0, 16.4)]
	for line in [top, GLOVE_STRAP_LINE] + GLOVE_FINGER_GAPS:
		var points: Array = line.map(func(p): return _glove_point(p, mirror))
		_shape(centre, unit, points, cut, cut_width)

## A line through points given on the 24 × 24 grid.
func _shape(centre: Vector2, unit: float, points: Array, ink: Color, width: float) -> void:
	var line := PackedVector2Array()
	for p in points:
		line.append(centre + (p - Vector2(12, 12)) * unit)
	draw_polyline(line, ink, width, true)
