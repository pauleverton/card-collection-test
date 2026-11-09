class_name PitchView
extends Control
## The pitch in the middle of the match screen, drawn in code: five zones from your box (left)
## to theirs (right), real line markings, and the ball in the zone where play is.
## Gold ball + green zone = your ball. Red ball + dark red zone = theirs.
## Display only: match_screen tells it what to show with show_state(), or, during a replay,
## where the ball is with show_ball_at() / show_their_ball_at().

const GRASS_A := Color("24482d")
const GRASS_B := Color("284f31")
const GRASS_OURS := Color("356b42")       ## the zone play is in, your ball
const GRASS_THEIRS := Color("553a2c")     ## the zone play is in, their ball
const LINE := Color(0.91, 0.95, 0.91, 0.5)
const LINE_WIDTH := 3.0
const GOLD := Color("f2b233")
const RED := Color("e0574a")
const DARK := Color("0e1812")
const NAME_COLOUR := Color(0.91, 0.95, 0.91, 0.55)
## Shapes, as a share of the pitch, so they stay right whatever size the pitch is given.
const MARGIN := 16.0          ## gap between the edge and the touchline (pixels)
const BOX_DEPTH := 0.14       ## penalty box: share of the pitch width
const BOX_WIDTH := 0.52       ## penalty box: share of the pitch height
const SIX_DEPTH := 0.05
const SIX_WIDTH := 0.24
const GOAL_WIDTH := 0.14
const CIRCLE := 0.145         ## centre circle radius: share of the pitch height
const BALL_RADIUS := 20.0
const BALL_MOVE_TIME := 0.25  ## the ball sliding from zone to zone (game-speed scaled)
const TAG_SIZE := 18
const NAME_SIZE := 20
const NOTE_SIZE := 18

## Where the ball is drawn: a float, so it can slide between zones.
var ball_zone := 2.0:
	set(value):
		ball_zone = value
		queue_redraw()
var _zone := 2                       ## the zone play is in
var _ours := true                    ## true = your ball
var _tag := ""                       ## the pill at the top of that zone ("PRESS 48")
var _note: PackedStringArray = []    ## extra lines under the pill (their chance in your box...)
var _pill := StyleBoxFlat.new()
var _ball_tween: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill.set_corner_radius_all(6)

## The normal view after every action.
func show_state(m: MatchRules) -> void:
	var tag := ""
	var note: PackedStringArray = []
	if m.has_ball:
		tag = "PRESS %d" % m.target
	elif m.zone == 0:
		tag = "THEIR CHANCE %d" % m.quality
		note.append("They score: %d%%" % m.their_goal_odds())
		note.append("Nobody back: keeper only!" if m.nobody_back() else "Block or Tackle to lower it")
	elif m.nobody_back():
		tag = "NOBODY BACK!"
	else:
		tag = "HOLD %d" % m.target
	_show(m.zone, m.has_ball, tag, note)

## During a replay: your ball, in zone z.
func show_ball_at(z: int) -> void:
	_show(z, true, "", [])

## During a replay: their ball, in zone z (e.g. a counter-attack).
func show_their_ball_at(z: int, note: String = "") -> void:
	_show(z, false, note.to_upper(), [])

func _show(z: int, ours: bool, tag: String, note: PackedStringArray) -> void:
	_zone = z
	_ours = ours
	_tag = tag
	_note = note
	if _ball_tween:
		_ball_tween.kill()
	_ball_tween = create_tween()
	_ball_tween.tween_property(self, "ball_zone", float(z), SettingsState.t(BALL_MOVE_TIME)) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	var zone_w := w / 5.0
	var font := ThemeDB.fallback_font
	var accent := GOLD if _ours else RED

	## Grass: one band per zone, the zone in play lit up with a coloured strip on top.
	for i in 5:
		var grass := GRASS_A if i % 2 == 0 else GRASS_B
		if i == _zone:
			grass = GRASS_OURS if _ours else GRASS_THEIRS
		draw_rect(Rect2(i * zone_w, 0, zone_w, h), grass)
	draw_rect(Rect2(_zone * zone_w, 0, zone_w, 5), accent)
	_draw_markings(w, h)

	## Zone names along the bottom.
	for i in 5:
		var colour := Color.WHITE if i == _zone else NAME_COLOUR
		draw_string(font, Vector2(i * zone_w, h - 30), MatchRules.ZONE_NAMES[i].to_upper(),
				HORIZONTAL_ALIGNMENT_CENTER, zone_w, NAME_SIZE, colour)

	## The pill at the top of the zone in play, then any extra lines under it.
	if _tag != "":
		var tag_w := font.get_string_size(_tag, HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_SIZE).x + 28
		var pill := Rect2(_zone * zone_w + (zone_w - tag_w) / 2, 24, tag_w, 32)
		_pill.bg_color = accent
		draw_style_box(_pill, pill)
		draw_string(font, Vector2(pill.position.x, pill.position.y + 23), _tag,
				HORIZONTAL_ALIGNMENT_CENTER, tag_w, TAG_SIZE, DARK if _ours else Color.WHITE)
	var y := 90.0
	for line in _note:
		draw_multiline_string(font, Vector2(_zone * zone_w + 8, y), line,
				HORIZONTAL_ALIGNMENT_CENTER, zone_w - 16, NOTE_SIZE, 2, Color.WHITE)
		y += 52

	## Chevrons in the zone play is heading for.
	var ahead := _zone + 1 if _ours else _zone - 1
	if ahead >= 0 and ahead <= 4:
		_draw_chevrons(Vector2((ahead + 0.5) * zone_w, h / 2), 1 if _ours else -1, Color(accent, 0.45))

	## The ball.
	var ball := Vector2((ball_zone + 0.5) * zone_w, h / 2)
	draw_circle(ball, BALL_RADIUS + 10, Color(accent, 0.25))
	draw_circle(ball, BALL_RADIUS + 4, DARK)
	draw_circle(ball, BALL_RADIUS, accent)

## Touchlines, halfway line, centre circle, both boxes, six-yard boxes, spots and goals.
func _draw_markings(w: float, h: float) -> void:
	var field := Rect2(MARGIN, MARGIN, w - 2 * MARGIN, h - 2 * MARGIN)
	var mid := Vector2(w / 2, h / 2)
	draw_rect(field, LINE, false, LINE_WIDTH)
	draw_line(Vector2(mid.x, field.position.y), Vector2(mid.x, field.end.y), LINE, LINE_WIDTH)
	draw_arc(mid, field.size.y * CIRCLE, 0, TAU, 64, LINE, LINE_WIDTH)
	draw_circle(mid, 4, LINE)
	var box := Vector2(field.size.x * BOX_DEPTH, field.size.y * BOX_WIDTH)
	var six := Vector2(field.size.x * SIX_DEPTH, field.size.y * SIX_WIDTH)
	var goal_h := field.size.y * GOAL_WIDTH
	for left in [true, false]:
		var edge := field.position.x if left else field.end.x
		var inward := 1.0 if left else -1.0
		draw_rect(_from_edge(edge, inward, mid.y, box), LINE, false, LINE_WIDTH)
		draw_rect(_from_edge(edge, inward, mid.y, six), LINE, false, LINE_WIDTH)
		draw_rect(_from_edge(edge, -inward, mid.y, Vector2(12, goal_h)), LINE, false, LINE_WIDTH)
		draw_circle(Vector2(edge + inward * box.x * 0.7, mid.y), 4, LINE)

## A rectangle of `rect_size` against a goal line at x = edge, reaching inward (+1) or outward (-1).
func _from_edge(edge: float, direction: float, centre_y: float, rect_size: Vector2) -> Rect2:
	var x := edge if direction > 0 else edge - rect_size.x
	return Rect2(x, centre_y - rect_size.y / 2, rect_size.x, rect_size.y)

## Two arrowheads pointing right (direction 1) or left (-1).
func _draw_chevrons(centre: Vector2, direction: int, colour: Color) -> void:
	for k in 2:
		var x := centre.x + (k * 22 - 11) * direction
		draw_polyline(PackedVector2Array([
				Vector2(x - 9 * direction, centre.y - 18),
				Vector2(x + 9 * direction, centre.y),
				Vector2(x - 9 * direction, centre.y + 18)]), colour, 6.0)
