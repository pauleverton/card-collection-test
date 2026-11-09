class_name BoxPitchView
extends Control
## Their penalty area, drawn in code, on the left of the box view: their goal at the top,
## the keeper, you on the ball, and three defenders who close in with every card you play
## in the box. The gamble and the result ("SHOT!  Keeper dives...", "GOAL!") are written
## big across it. Display only: BoxView tells it what to show.

const GRASS_A := Color("24482d")
const GRASS_B := Color("284f31")
const LINE := Color(0.91, 0.95, 0.91, 0.5)
const LINE_WIDTH := 3.0
const NET := Color(0.93, 0.94, 0.91)
const GOLD := Color("f2b233")
const RED := Color("e0574a")
const KEEPER := Color("6fb7f0")
const DARK := Color("0e1812")
const LEGEND := Color("cfe3d0")
const SHADE := Color(0, 0, 0, 0.55)       ## darkens the drawing behind the big text
const STRIPES := 6                         ## mown stripes across the grass
const GOAL_LINE := 14.0                    ## pixels from the top: the goal sits above it
## Shapes as shares of the drawing (stylised, not to scale, so the box fills the view).
const BOX_WIDTH := 0.86
const BOX_DEPTH := 0.56
const SIX_WIDTH := 0.4
const SIX_DEPTH := 0.19
const GOAL_WIDTH := 0.24
const SPOT_Y := 0.41
const ARC_RADIUS := 0.26
## Where everyone stands, as shares of the drawing (x, y).
const KEEPER_SPOT := Vector2(0.5, 0.09)
const BALL_SPOT := Vector2(0.5, 0.47)
const REBOUND_BALL := Vector2(0.64, 0.21)      ## parried: loose by the six-yard box
const REBOUND_KEEPER := Vector2(0.38, 0.11)    ## keeper went the other way
## The defenders slide from FAR to NEAR as the pressure builds.
const DEFENDERS_FAR := [Vector2(0.16, 0.66), Vector2(0.84, 0.62), Vector2(0.5, 0.2)]
const DEFENDERS_NEAR := [Vector2(0.37, 0.43), Vector2(0.63, 0.41), Vector2(0.5, 0.34)]
const MAX_PRESSURE := 3        ## after this many cards played here they can't get any closer
const MOVE_TIME := 0.5         ## defenders closing in (game-speed scaled)
const STATUS_SIZE := 40

## 0 = defenders still getting back, 1 = swarmed. A float so they can slide.
var closeness := 0.0:
	set(value):
		closeness = value
		queue_redraw()
var _rebound := false
var _status := Label.new()
var _tween: Tween

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_status.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_status.offset_left = 24
	_status.offset_right = -24
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", STATUS_SIZE)
	_status.add_theme_constant_override("outline_size", 10)
	_status.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_status.visible = false
	add_child(_status)

## Move the defenders to match how many cards you've played in the box, and clear the text.
func show_pressure(cards_played: int, rebound: bool) -> void:
	_rebound = rebound
	var target := clampf(float(cards_played) / MAX_PRESSURE, 0.0, 1.0)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "closeness", target, SettingsState.t(MOVE_TIME)) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_status.visible = false
	queue_redraw()

## Write big text across the drawing. pop = the result (a quick bounce); otherwise it types out.
func say(text: String, colour: Color, pop: bool = false) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", colour)
	_status.visible = true
	_status.pivot_offset = size / 2
	if pop:
		_status.visible_ratio = 1.0
		_status.scale = Vector2(1.3, 1.3)
		create_tween().tween_property(_status, "scale", Vector2.ONE, SettingsState.t(0.25))
	else:
		_status.scale = Vector2.ONE
		_status.visible_ratio = 0.0
		create_tween().tween_property(_status, "visible_ratio", 1.0, SettingsState.t(0.3))
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	var stripe := h / STRIPES
	for i in STRIPES:
		draw_rect(Rect2(0, i * stripe, w, stripe + 1), GRASS_A if i % 2 == 0 else GRASS_B)

	## Lines: goal line, penalty box, six-yard box, spot, the D, and the goal itself.
	draw_line(Vector2(0, GOAL_LINE), Vector2(w, GOAL_LINE), LINE, LINE_WIDTH)
	var box := Rect2((w - w * BOX_WIDTH) / 2, GOAL_LINE, w * BOX_WIDTH, h * BOX_DEPTH)
	draw_rect(box, LINE, false, LINE_WIDTH)
	draw_rect(Rect2((w - w * SIX_WIDTH) / 2, GOAL_LINE, w * SIX_WIDTH, h * SIX_DEPTH), LINE, false, LINE_WIDTH)
	var spot := Vector2(w / 2, h * SPOT_Y)
	draw_circle(spot, 4, LINE)
	var radius := h * ARC_RADIUS
	var below := box.end.y - spot.y                   ## the D is the part of the circle outside the box
	if radius > below:
		var half := acos(below / radius)
		draw_arc(spot, radius, PI / 2 - half, PI / 2 + half, 32, LINE, LINE_WIDTH)
	draw_rect(Rect2((w - w * GOAL_WIDTH) / 2, 0, w * GOAL_WIDTH, GOAL_LINE), NET)

	## Players: defenders (red, glowing more the closer they get), keeper (blue), you (gold).
	for i in DEFENDERS_FAR.size():
		var at: Vector2 = DEFENDERS_FAR[i].lerp(DEFENDERS_NEAR[i], closeness) * size
		draw_circle(at, 13 + 10 * closeness, Color(RED, 0.25))
		draw_circle(at, 13, RED)
	var keeper: Vector2 = (REBOUND_KEEPER if _rebound else KEEPER_SPOT) * size
	draw_circle(keeper, 17, DARK)
	draw_circle(keeper, 15, KEEPER)
	var ball: Vector2 = (REBOUND_BALL if _rebound else BALL_SPOT) * size
	draw_circle(ball, 22, Color(GOLD, 0.25))
	draw_circle(ball, 19, DARK)
	draw_circle(ball, 16, GOLD)

	## Legend along the bottom.
	var font := ThemeDB.fallback_font
	var x := 18.0
	for item in [[GOLD, "You"], [RED, "Closing in"], [KEEPER, "Keeper"]]:
		draw_circle(Vector2(x + 7, h - 24), 7, item[0])
		draw_string(font, Vector2(x + 20, h - 18), item[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, LEGEND)
		x += 30 + font.get_string_size(item[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x

	if _status.visible:
		draw_rect(Rect2(Vector2.ZERO, size), SHADE)
