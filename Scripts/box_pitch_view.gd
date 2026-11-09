class_name BoxPitchView
extends Control
## Their penalty area, drawn in code, on the left of the box view: their goal at the top,
## their keeper, two of your players (one on the ball, one making a run) and their defenders
## closing in on whoever has the ball. Display only: BoxView tells it what to show.
##   new_attack()     a fresh layout each time you get into the box
##   show_pressure()  defenders close in after each card you play here
##   act()            the result plays out: a pass, cross or dribble that comes off,
##                    a tackle that wins the ball, a save, a rebound, a goal
##   say()            the gamble / result written big in a band across the drawing
## Positions are worked out on a REF_SIZE drawing (in pixels) and scaled when drawn.

const GRASS_A := Color("24482d")
const GRASS_B := Color("284f31")
const LINE := Color(0.91, 0.95, 0.91, 0.5)
const LINE_WIDTH := 3.0
const NET := Color(0.93, 0.94, 0.91)
const GOLD := Color("f2b233")
const RED := Color("e0574a")
const KEEPER := Color("6fb7f0")
const BALL := Color.WHITE
const DARK := Color("0e1812")
const LEGEND := Color("cfe3d0")
const SHADE := Color(0, 0, 0, 0.6)         ## the band behind the big text
const BAND_HEIGHT := 0.25   
const BAND_TOP := 0.52                     ## the band: share of the height where it starts...const BAND_HEIGHT := 0.25                  ## ...and how tall it is (the players stay visible above)
const STRIPES := 6                         ## mown stripes across the grass
const GOAL_LINE := 14.0                    ## pixels from the top: the goal sits above it
const REF_SIZE := Vector2(480, 540)        ## positions are worked out at this size
## Shapes as shares of the drawing (stylised, not to scale, so the box fills the view).
const BOX_WIDTH := 0.86
const BOX_DEPTH := 0.56
const SIX_WIDTH := 0.4
const SIX_DEPTH := 0.19
const GOAL_WIDTH := 0.24
const SPOT_Y := 0.41
const ARC_RADIUS := 0.26
## Your two players at the start of an attack (shares of the drawing).
const CARRIER_X := Vector2(0.28, 0.72)     ## the one on the ball: left-right range
const CARRIER_Y := Vector2(0.44, 0.52)     ## ...and up-down range
const RUNNER_Y := Vector2(0.28, 0.38)      ## the other one starts further forward...
const RUNNER_GAP := 0.22                   ## ...and at least this far across
const FORWARD_LIMIT := 0.27                ## your players stop here (just outside the six-yard box)
const KEEPER_Y := 0.09
const KEEPER_FOLLOW := 0.4                 ## how far the keeper shifts towards the ball (0-1)
## Moves (pixels on the REF_SIZE drawing).
const BALL_OFFSET := Vector2(10, 12)       ## where the ball sits at a player's feet
const DRIBBLE_STEP := Vector2(50, 75)      ## a dribble carries the ball this far towards goal
const DRIBBLE_SIDE := 45.0                 ## ...and up to this far sideways
const RUN_Y := Vector2(0.30, 0.42)         ## after a pass, the passer runs into space here (shares)
const CROSS_ARC := 110.0                   ## how high a cross goes
const SHOT_ARC := 30.0                     ## a shot lifts a little
const LUNGE_GAP := 18.0                    ## where the tackler ends up, right next to you
const REBOUND_SHIFT := Vector2(0.12, 0.18) ## a parry spills this far to one side (share of width)
const MOVE_TIME := 0.5                     ## defenders closing in after each card
const ACT_TIME := 0.45                     ## a pass / dribble / cross / tackle / shot playing out
const CROSS_TIME:=0.9
## Defenders, measured from the ball carrier. They start FAR and finish NEAR, coming
## mostly from the goal side, each at their own speed.
const DEFENDERS_BASE := 3                  ## a Medium defence; each rating step adds or removes one
const DEFENDERS_MIN := 2
const DEFENDERS_MAX := 4
const FAR := Vector2(150, 210)             ## starting distance range
const NEAR := Vector2(42, 60)              ## finishing distance range
const SPREAD := Vector2(-170, -10)         ## directions they come from (degrees; -90 = from the goal)
const JITTER := 15.0                       ## random wobble on each direction (degrees)
const SPEED := Vector2(0.7, 1.35)          ## some close in faster than others
const SIX_CLEAR := 12.0                    ## defenders never start inside the six-yard box (+ this gap)
const KEEPER_CLEAR := 46.0                 ## and never stand closer than this to the keeper
const MAX_PRESSURE := 3                    ## after this many cards played here they're as close as they get
const STATUS_SIZE := 36

## How far through the current move everything is (0 = where it was, 1 = where it's going).
var progress := 1.0:
	set(value):
		progress = value
		queue_redraw()
var _from := {}                ## where everything was when the current move started
var _to := {}                  ## where everything is heading
var _via: Array = []           ## points the ball passes through on the way (a parry)
var _arc := 0.0                ## how high the ball goes on this move
var _carrier := "p0"           ## which of your players has the ball: "p0" or "p1"
var _ball_free := false        ## true = not at your feet (saved, lost, in the net)
var _pressure := 0.0           ## how close the defenders are now (0-1)
var _defenders: Array = []     ## per defender: {key, angle, far, near, speed}
var _status := Label.new()
var _tween: Tween

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_status.anchor_left = 0.0
	_status.anchor_right = 1.0
	_status.anchor_top = BAND_TOP
	_status.anchor_bottom = BAND_TOP + BAND_HEIGHT
	_status.offset_left = 20
	_status.offset_right = -20
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", STATUS_SIZE)
	_status.add_theme_constant_override("outline_size", 10)
	_status.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_status.visible = false
	add_child(_status)
	new_attack(1.0)

# ---------- What BoxView calls ----------

## A fresh attack into the box: roll where your two players are and how their defenders come.
## their_defence is the opponent's Defence multiplier (Very Low 0.8 ... Very High 1.2):
## a stronger defence sends more bodies, which is also why the risk of losing it is higher.
func new_attack(their_defence: float) -> void:
	var carrier_share := randf_range(CARRIER_X.x, CARRIER_X.y)
	var runner_share := randf_range(carrier_share + RUNNER_GAP, 0.78) if carrier_share < 0.5 \
			else randf_range(0.22, carrier_share - RUNNER_GAP)
	var carrier := Vector2(carrier_share, randf_range(CARRIER_Y.x, CARRIER_Y.y)) * REF_SIZE
	var runner := Vector2(runner_share, randf_range(RUNNER_Y.x, RUNNER_Y.y)) * REF_SIZE
	_carrier = "p0"
	_ball_free = false
	_pressure = 0.0
	var steps := roundi((their_defence - 1.0) / OpponentTeam.RATING_SPREAD)
	var count := clampi(DEFENDERS_BASE + steps, DEFENDERS_MIN, DEFENDERS_MAX)
	_defenders.clear()
	for i in count:
		## Spread the directions evenly across SPREAD, then wobble each one a little.
		var angle := lerpf(SPREAD.x, SPREAD.y, (i + 0.5) / count) + randf_range(-JITTER, JITTER)
		_defenders.append({"key": "d%d" % i, "angle": deg_to_rad(angle),
				"far": randf_range(FAR.x, FAR.y), "near": randf_range(NEAR.x, NEAR.y),
				"speed": randf_range(SPEED.x, SPEED.y)})
	var keeper := _keeper_spot(carrier.x)
	var spots := {"p0": carrier, "p1": runner, "keeper": keeper, "ball": carrier + BALL_OFFSET}
	spots.merge(_defender_targets(carrier, keeper, 0.0))
	_from = spots.duplicate()
	_to = spots.duplicate()
	_via = []
	_arc = 0.0
	if _tween:
		_tween.kill()
	progress = 1.0

## Defenders close in on whoever has the ball, to match how many cards you've played here.
func show_pressure(cards_played: int, _rebound: bool) -> void:
	_pressure = clampf(float(cards_played) / MAX_PRESSURE, 0.0, 1.0)
	_status.visible = false
	_move(_defender_targets(_to[_carrier], _to["keeper"], _pressure), MOVE_TIME)

## Play out what just happened. kind: "gain" (tag = pass / dribble / cross), "lost",
## "goal", "saved", "rebound". Anything else: nothing moves.
func act(kind: String, tag: String = "") -> void:
	match kind:
		"gain":
			if tag == "pass":
				_pass(false)
			elif tag == "cross":
				_pass(true)
			else:
				_dribble()
		"lost":
			_lose_ball()
		"goal":
			_shoot("goal")
		"saved":
			_shoot("saved")
		"rebound":
			_shoot("rebound")

## Write big text in the band across the drawing. pop = the result (a quick bounce);
## otherwise it types out.
func say(text: String, colour: Color, pop: bool = false) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", colour)
	_status.visible = true
	_status.pivot_offset = _status.size / 2
	if pop:
		_status.visible_ratio = 1.0
		_status.scale = Vector2(1.3, 1.3)
		create_tween().tween_property(_status, "scale", Vector2.ONE, SettingsState.t(0.25))
	else:
		_status.scale = Vector2.ONE
		_status.visible_ratio = 0.0
		create_tween().tween_property(_status, "visible_ratio", 1.0, SettingsState.t(0.3))
	queue_redraw()

# ---------- The moves ----------

## A pass along the ground (or a cross through the air) to your other player.
## The passer then runs into space; the defenders switch to the new man on the ball.
func _pass(cross: bool) -> void:
	var passer := _carrier
	var receiver := _other(passer)
	var target: Vector2 = _to[receiver]
	if cross:
		target = _keep_yours(target + Vector2(randf_range(-30, 30), -45))   ## attacks the cross
	var run_x := randf_range(0.25, 0.45) if target.x > REF_SIZE.x / 2 else randf_range(0.55, 0.75)
	var run := _keep_yours(Vector2(run_x, randf_range(RUN_Y.x, RUN_Y.y)) * REF_SIZE)
	_carrier = receiver
	var keeper := _keeper_spot(target.x)
	var targets := {passer: run, receiver: target, "keeper": keeper, "ball": target + BALL_OFFSET}
	targets.merge(_defender_targets(target, keeper, _pressure))
	_move(targets, CROSS_TIME if cross else ACT_TIME, [], CROSS_ARC if cross else 0.0)

## Carry the ball towards goal; your other player drifts with you.
func _dribble() -> void:
	var you: Vector2 = _to[_carrier]
	var step := Vector2(randf_range(-DRIBBLE_SIDE, DRIBBLE_SIDE), -randf_range(DRIBBLE_STEP.x, DRIBBLE_STEP.y))
	var moved := _keep_yours(you + step)
	if moved.distance_to(you) < 30.0:                  ## already as far forward as you can go: go across
		var across := -1.0 if you.x > REF_SIZE.x / 2 else 1.0
		moved = _keep_yours(you + Vector2(across * randf_range(55, 85), randf_range(-10, 10)))
	var mate: Vector2 = _to[_other(_carrier)]
	var drift := _keep_yours(mate + Vector2(randf_range(-20, 20), -randf_range(0, 20)))
	var keeper := _keeper_spot(moved.x)
	var targets := {_carrier: moved, _other(_carrier): drift, "keeper": keeper, "ball": moved + BALL_OFFSET}
	targets.merge(_defender_targets(moved, keeper, _pressure))
	_move(targets, ACT_TIME)

## The nearest defender lunges in and comes away with the ball; you're knocked aside.
func _lose_ball() -> void:
	var you: Vector2 = _to[_carrier]
	var tackler := ""
	var nearest := INF
	for d in _defenders:
		var gap := you.distance_to(_to[d["key"]])
		if gap < nearest:
			nearest = gap
			tackler = d["key"]
	if tackler == "":
		return
	var line: Vector2 = (_to[tackler] - you).normalized()
	var tackle_at := you + line * LUNGE_GAP
	_ball_free = true
	_move({tackler: tackle_at, _carrier: you - line * 14, "ball": tackle_at + line * 14}, ACT_TIME)

## A shot. "goal": in the net, keeper beaten. "saved": the keeper gets to it.
## "rebound": he parries it to one side and your other player follows it in.
func _shoot(result: String) -> void:
	var from: Vector2 = _to["ball"]
	var keeper: Vector2 = _to["keeper"]
	var aim := Vector2(REF_SIZE.x / 2 + randf_range(-1, 1) * REF_SIZE.x * GOAL_WIDTH * 0.35, GOAL_LINE / 2)
	var line_t := clampf((keeper.y - from.y) / (aim.y - from.y), 0.0, 1.0)
	var save := from.lerp(aim, line_t)                  ## where the shot crosses the keeper's line
	_ball_free = true
	match result:
		"goal":
			var dive := keeper + Vector2(-signf(aim.x - keeper.x + 0.01) * 30, 0)   ## the wrong way
			_move({"ball": aim, "keeper": dive}, ACT_TIME, [], SHOT_ARC)
		"saved":
			_move({"ball": save, "keeper": save}, ACT_TIME, [], SHOT_ARC)
		"rebound":
			var side := 1.0 if save.x < REF_SIZE.x / 2 else -1.0
			var spill := Vector2(REF_SIZE.x / 2 + side * randf_range(REBOUND_SHIFT.x, REBOUND_SHIFT.y) * REF_SIZE.x,
					REF_SIZE.y * 0.21)
			var follow := _other(_carrier)
			_carrier = follow
			_ball_free = false
			_move({"ball": spill, "keeper": save, follow: spill - BALL_OFFSET}, ACT_TIME, [save], SHOT_ARC)

# ---------- Helpers ----------

## Move everything named in targets to its new spot; everything else stays where it is.
func _move(targets: Dictionary, time: float, via: Array = [], arc: float = 0.0) -> void:
	for key in _to.keys():
		_from[key] = _now(key)          ## start from wherever it's drawn right now
	for key in _to.keys():
		_to[key] = targets.get(key, _from[key])
	_via = via
	_arc = arc
	if _tween:
		_tween.kill()
	var length := SettingsState.t(time)
	if length <= 0.0:
		progress = 1.0
		return
	progress = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "progress", 1.0, length).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## Where something is right now (on the REF_SIZE drawing, on the ground).
func _now(key: String) -> Vector2:
	if key == "ball" and not _via.is_empty():
		var points: Array = [_from["ball"]] + _via + [_to["ball"]]
		var segments := points.size() - 1
		var f := progress * segments
		var i := mini(int(f), segments - 1)
		return points[i].lerp(points[i + 1], f - i)
	return _from[key].lerp(_to[key], progress)

func _other(player: String) -> String:
	return "p1" if player == "p0" else "p0"

## Keep one of your players inside the box and outside the six-yard box.
func _keep_yours(at: Vector2) -> Vector2:
	var edge := REF_SIZE.x * (1.0 - BOX_WIDTH) / 2 + 22
	return Vector2(clampf(at.x, edge, REF_SIZE.x - edge),
			clampf(at.y, REF_SIZE.y * FORWARD_LIMIT, REF_SIZE.y * 0.6))

## The keeper shifts across with the ball.
func _keeper_spot(ball_x: float) -> Vector2:
	return Vector2(REF_SIZE.x / 2 + (ball_x - REF_SIZE.x / 2) * KEEPER_FOLLOW, REF_SIZE.y * KEEPER_Y)

## Where each defender should stand, closing in on `carrier`: {"d0": position, ...}
## A defender coming from the goal side starts no deeper than the edge of the six-yard box
## (that's the keeper's), and nobody ever stands on the keeper.
func _defender_targets(carrier: Vector2, keeper: Vector2, pressure: float) -> Dictionary:
	var six_line := GOAL_LINE + REF_SIZE.y * SIX_DEPTH + SIX_CLEAR
	var spots := {}
	for d in _defenders:
		var direction := Vector2(cos(d["angle"]), sin(d["angle"]))
		var far: float = d["far"]
		if direction.y < 0.0:
			far = minf(far, (carrier.y - six_line) / -direction.y)   ## stop at the six-yard line
		far = maxf(far, d["near"])
		var amount := clampf(pressure * d["speed"], 0.0, 1.0)
		var at := carrier + direction * lerpf(far, d["near"], amount)
		at = at.clamp(Vector2(16, GOAL_LINE + 16), REF_SIZE - Vector2(16, 48))
		var from_keeper := at - keeper
		if from_keeper.length() < KEEPER_CLEAR:                     ## step off the keeper
			var away := from_keeper.normalized() if from_keeper.length() > 0.1 else Vector2.DOWN
			at = keeper + away * KEEPER_CLEAR
		spots[d["key"]] = at
	return spots

# ---------- Drawing ----------

func _draw() -> void:
	var w := size.x
	var h := size.y
	var k := size / REF_SIZE            ## REF_SIZE positions -> real pixels
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

	## Defenders: they glow more the closer they are to the ball.
	var ball_ground := _now("ball") * k
	for d in _defenders:
		var at: Vector2 = _now(d["key"]) * k
		var close := clampf(1.0 - (at.distance_to(ball_ground) - 40.0) / 160.0, 0.0, 1.0)
		draw_circle(at, 13 + 10 * close, Color(RED, 0.25))
		draw_circle(at, 13, RED)
	## Your two players: the one on the ball has a glow.
	for player in ["p0", "p1"]:
		var at: Vector2 = _now(player) * k
		if player == _carrier and not _ball_free:
			draw_circle(at, 25, Color(GOLD, 0.25))
		draw_circle(at, 17, DARK)
		draw_circle(at, 15, GOLD)
	var keeper: Vector2 = _now("keeper") * k
	draw_circle(keeper, 17, DARK)
	draw_circle(keeper, 15, KEEPER)
	## The ball, lifted off the ground on crosses and shots, with its shadow left on the grass.
	var height := _arc * sin(PI * progress)
	if height > 1.0:
		draw_circle(ball_ground, 7, Color(0, 0, 0, 0.35))
	var ball := ball_ground - Vector2(0, height)
	var grow := 1.0 + (0.5 * height / _arc if _arc > 0.0 else 0.0)
	draw_circle(ball, 9 * grow, DARK)
	draw_circle(ball, 7 * grow, BALL)

	## Legend along the bottom.
	var font := ThemeDB.fallback_font
	var x := 18.0
	for item in [[GOLD, "Your players"], [RED, "Their defenders"], [KEEPER, "Keeper"]]:
		draw_circle(Vector2(x + 7, h - 24), 7, item[0])
		draw_string(font, Vector2(x + 20, h - 18), item[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, LEGEND)
		x += 30 + font.get_string_size(item[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x

	## The band behind the big text.
	if _status.visible:
		draw_rect(Rect2(0, h * BAND_TOP, w, h * BAND_HEIGHT), SHADE)
