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
## A shot from outside the box (Long Shot): the ball flies at goal, then GOAL! or WIDE!.
const SHOT_TIME := 0.55       ## the ball's flight (game-speed scaled)
const SHOT_ARC := 60.0        ## how high the ball goes on the way (pixels)
const SHOT_BALL_RADIUS := 8.0 ## the white ball in flight (the box view uses 7)
const BANNER_SIZE := 110      ## the big GOAL! / WIDE! word

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
## The shot in flight: 0 = leaving the boot, 1 = at the goal line. -1 = no shot on screen.
var shot_progress := -1.0:
	set(value):
		shot_progress = value
		queue_redraw()
var banner_scale := 1.0:
	set(value):
		banner_scale = value
		queue_redraw()
var _shot_scored := false
var _shot_dy := 0.0         ## where it crosses the goal line: share of the pitch height from the middle
var _banner := ""
var _banner_colour := GOLD

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
	shot_progress = -1.0     ## any shot on screen is over
	_banner = ""
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

	## The marker: where play is (gold = your ball, red = theirs). It stays put during a shot.
	var marker := Vector2((ball_zone + 0.5) * zone_w, h / 2)
	draw_circle(marker, BALL_RADIUS + 10, Color(accent, 0.25))
	draw_circle(marker, BALL_RADIUS + 4, DARK)
	draw_circle(marker, BALL_RADIUS, accent)

	## A long shot: a real (white) ball flies from the marker at their goal, like the box view's.
	if shot_progress >= 0.0:
		var start := marker + Vector2(BALL_RADIUS + 4, BALL_RADIUS - 2)   ## at the shooter's feet
		var end := Vector2(w - MARGIN + 6, h / 2 + _shot_dy * (h - 2 * MARGIN))
		var ground := start.lerp(end, shot_progress)
		var lift := sin(shot_progress * PI)                  ## 0 on the ground, 1 at the top
		var ball := ground - Vector2(0, lift * SHOT_ARC)
		var grow := 1.0 + lift * 0.4                         ## bigger when it's up in the air
		if shot_progress >= 1.0 and _shot_scored:
			## The net lights up (drawn first, so the ball shows in it).
			var goal_h := (h - 2 * MARGIN) * GOAL_WIDTH
			draw_rect(Rect2(w - MARGIN, h / 2 - goal_h / 2, 12, goal_h), Color(GOLD, 0.8))
		draw_circle(ground, SHOT_BALL_RADIUS, Color(0, 0, 0, 0.35))   ## shadow on the grass
		draw_circle(ball, (SHOT_BALL_RADIUS + 2) * grow, DARK)
		draw_circle(ball, SHOT_BALL_RADIUS * grow, Color.WHITE)

	## GOAL! / WIDE! across the middle of the pitch, the same style as the box view.
	if _banner != "":
		var banner_size := int(BANNER_SIZE * banner_scale)
		var y_base := h / 2 + banner_size * 0.35
		draw_string_outline(font, Vector2(0, y_base), _banner, HORIZONTAL_ALIGNMENT_CENTER, w,
				banner_size, 12, DARK)
		draw_string(font, Vector2(0, y_base), _banner, HORIZONTAL_ALIGNMENT_CENTER, w,
				banner_size, _banner_colour)

## A shot from where the ball is now at their goal. scored = it goes in, else it flies wide.
## Returns how long the flight takes, so the screen can wait for it.
func shoot(scored: bool) -> float:
	if _ball_tween:
		_ball_tween.kill()
	_shot_scored = scored
	_banner = ""
	_tag = ""                ## clear the pill and notes so the shot has the pitch to itself
	_note = []
	var post := GOAL_WIDTH / 2   ## the goal's half-width, as a share of the pitch height
	if scored:
		_shot_dy = randf_range(-post * 0.7, post * 0.7)
	else:
		_shot_dy = (post + randf_range(0.08, 0.14)) * (1 if randf() < 0.5 else -1)
	var time := SettingsState.t(SHOT_TIME)
	shot_progress = 0.0
	var t := create_tween()
	t.tween_property(self, "shot_progress", 1.0, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_callback(_show_banner)
	return time

func _show_banner() -> void:
	_banner = "GOAL!" if _shot_scored else "WIDE!"
	_banner_colour = GOLD if _shot_scored else RED
	banner_scale = 1.3
	create_tween().tween_property(self, "banner_scale", 1.0, SettingsState.t(0.25))

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
