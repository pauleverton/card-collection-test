class_name TypeIcon
extends Control
## A small icon drawn in code: shield = defending, target = attacking, chevrons = move,
## plus = utility, sparkle = skills, clock = a timed ability ("FROM 75'").
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
		"clock":
			draw_arc(centre, 8.5 * unit, 0, TAU, 32, ink, width, true)
			_shape(centre, unit, [Vector2(12, 7), Vector2(12, 12), Vector2(15.5, 14)], ink, width)

## A line through points given on the 24 × 24 grid.
func _shape(centre: Vector2, unit: float, points: Array, ink: Color, width: float) -> void:
	var line := PackedVector2Array()
	for p in points:
		line.append(centre + (p - Vector2(12, 12)) * unit)
	draw_polyline(line, ink, width, true)
