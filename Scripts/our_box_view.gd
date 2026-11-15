class_name OurBoxView
extends PanelContainer
## The big view of YOUR box (they attack, you react), shown in place of the bar and pitch
## while they're in it. Display only: match_screen tells it what to show; MatchRules decides.
##   Left:  your penalty area drawn (BoxPitchView in "ours" mode: your goal at the bottom),
##          with the challenge / result written across it.
##   Right: their chance, THEIR NEXT MOVE, and YOUR ANSWER (one row per card you could play).
## Hovering a card in your hand (or the Lunge button) lights up its answer row, like their box.

const RED := Color("e0574a")
const PINK := Color("ffb3a9")
const SOFT_RED := Color("f0b4ad")
const GREEN := Color("7be07b")
const GREY := Color("b9c4b8")
const LIGHT := Color("cfd8ce")
const DIM := Color("8a7672")
const PANEL := Color("121e16")
const NOW_TILE := Color("1e1514")
const NOW_EDGE := Color("4a2723")
const NEXT_TILE := Color("2a1714")
const ROW := Color("16261b")
const ROW_EDGE := Color("2b4232")
const TRACK := Color("0a120d")
const DRAWING_WIDTH := 480      ## the penalty-area drawing on the left
const BIG := 56                 ## the big numbers / words in the two tiles
const ROW_FONT := 20
const HOVER_EDGE := Color("f2b233")   ## gold edge on the hovered card's row (same as their box)
const LUNGE_KEY := "_lunge"           ## the Lunge row's key (no card is called this)

var _drawing := BoxPitchView.new()
var _chance: Label
var _now_odds: Label
var _next_word: Label
var _next_note: Label
var _plan: Label
var _rows: VBoxContainer
var _m: MatchRules = null           ## the match, kept from show_state() so preview() can redraw
var _hovered: ActionCard = null     ## the card under the mouse in your hand (null = none)
var _lunge_hovered := false         ## the mouse is over the Lunge button
var _row_for := {}                  ## card name (or LUNGE_KEY) -> its answer row

func _init() -> void:
	add_theme_stylebox_override("panel", _box_style(PANEL, RED, 3, 12, 20))
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	add_child(columns)
	_drawing.custom_minimum_size.x = DRAWING_WIDTH
	_drawing.set_ours(true)
	columns.add_child(_drawing)

	## Right column. Everything sits at the top: a hovered card in your hand lifts up over the bottom.
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	columns.add_child(right)

	## Header: THEY'RE IN YOUR BOX ........ Chance 45
	var header := HBoxContainer.new()
	right.add_child(header)
	var title := _label("THEY'RE IN YOUR BOX", 34, RED)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_chance = _label("", 30, Color.WHITE)
	header.add_child(_chance)

	## Two tiles: IF THEY SHOOT NOW (big %) | THEIR NEXT MOVE (big word + what it does).
	var tiles := HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 14)
	right.add_child(tiles)

	var now_tile := _tile(NOW_TILE, NOW_EDGE, 1)
	now_tile.custom_minimum_size.x = 210
	var now_box := VBoxContainer.new()
	now_box.add_theme_constant_override("separation", 0)
	now_tile.add_child(now_box)
	now_box.add_child(_label("IF THEY SHOOT NOW", 18, SOFT_RED))
	_now_odds = _label("", BIG, Color("ff7a6b"))
	now_box.add_child(_now_odds)
	tiles.add_child(now_tile)

	var next_tile := _tile(NEXT_TILE, RED, 2)
	next_tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var next_box := VBoxContainer.new()
	next_box.add_theme_constant_override("separation", 0)
	next_tile.add_child(next_box)
	var next_head := HBoxContainer.new()
	next_box.add_child(next_head)
	var next_title := _label("THEIR NEXT MOVE", 18, SOFT_RED)
	next_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_head.add_child(next_title)
	_plan = _label("", 16, PINK)
	next_head.add_child(_plan)
	_next_word = _label("", 40, Color.WHITE)
	next_box.add_child(_next_word)
	_next_note = _label("", 17, PINK)
	next_box.add_child(_next_note)
	tiles.add_child(next_tile)

	right.add_child(_label("YOUR ANSWER", 22, GREY))
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	right.add_child(_rows)

## Redraw from the match. Hidden unless they have the ball in your box.
func show_state(m: MatchRules) -> void:
	var was_showing := visible
	visible = m.in_our_box() and not m.match_over
	_m = m
	if not visible:
		return
	if not was_showing:
		_drawing.new_attack(1.0)              ## a fresh attack: new positions every time
		_drawing.show_pressure(2, false)     ## your defenders goal-side, close to their man
		## (only at the start: moving them every refresh undid blocks and tackles)
	_chance.text = "Chance %d" % m.quality
	_now_odds.text = "%d%%" % m.their_goal_odds()

	## Their next move, and what's left of their plan after it.
	var move := m.next_move()
	if move.is_empty() or move["kind"] == "shot":
		_next_word.text = "SHOT"
		_next_note.text = "They shoot: %d%% to score" % m.their_goal_odds()
		_plan.text = "Last chance to stop it"
	else:
		var after: int = m.quality + move["gain"]
		_next_word.text = "%s  +%d" % [move["kind"].to_upper(), move["gain"]]
		_next_note.text = "Chance %d → %d · they'd score %d%%" % [m.quality, after, m.their_goal_odds_at(after)]
		var later := PackedStringArray()
		for i in range(1, m.their_moves.size()):
			later.append("Shot" if m.their_moves[i]["kind"] == "shot" else "?")
		_plan.text = "Then: " + " · ".join(later)

	## Your answer: one row per kind of card you could play now.
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_row_for.clear()
	if m.nobody_back():
		_rows.add_child(_label("Nobody back: it's down to your keeper.", ROW_FONT, DIM))
		return
	var seen := []
	for card in DeckState.hand:
		if card.energy_cost > m.energy or not m.can_play_here(card):
			continue
		var key: String = card.display_name
		if key in seen or card.tag in ["retain", "overlap"]:
			continue
		seen.append(key)
		var row := _answer_row(m, card, false)
		_row_for[key] = row
		_rows.add_child(row)
	if m.can_lunge() and _rows.get_child_count() < 4:
		var any_card: ActionCard = DeckState.hand.filter(func(c): return m.is_lunge(c)).front()
		var lunge_row := _answer_row(m, any_card, true)
		_row_for[LUNGE_KEY] = lunge_row
		_rows.add_child(lunge_row)
	if _rows.get_child_count() == 0:
		_rows.add_child(_label("Nothing you can play: they make their move.", ROW_FONT, DIM))
	_light_rows()

## The card under the mouse in your hand (null when the mouse leaves).
func preview(card: ActionCard) -> void:
	_hovered = card
	if visible and _m != null:
		_light_rows()

## The mouse is over (true) or has left (false) the Lunge button.
func preview_lunge(on: bool) -> void:
	_lunge_hovered = on
	if visible and _m != null:
		_light_rows()

## Gold edge on the row that matches what you're hovering; every other row gets its own edge back.
func _light_rows() -> void:
	var key := ""
	if _lunge_hovered:
		key = LUNGE_KEY
	elif _hovered != null and _hovered in DeckState.hand:
		key = _hovered.display_name
	for row_key in _row_for:
		var row: PanelContainer = _row_for[row_key]
		var lit: bool = row_key == key
		var edge: Color = HOVER_EDGE if lit else row.get_meta("edge")
		row.add_theme_stylebox_override("panel", _box_style(ROW, edge, 2 if lit else 1, 8, 12, 5))

## The challenge, written across the drawing before the result is shown.
func suspense(text: String) -> void:
	_drawing.say(text, Color.WHITE)

## The result, with a little pop, and the move playing out on the drawing.
## kind: "block" / "won" / "beaten" / "foul" / "move" (tag = pass / dribble / cross) / "goal" / "saved".
func flash(text: String, colour: Color, kind: String = "", tag: String = "") -> void:
	_drawing.say(text, colour, true)
	_drawing.act(kind, tag)

## One answer: name | what it does | what happens next | foul risk (bar + words).
func _answer_row(m: MatchRules, card: ActionCard, lunge: bool) -> PanelContainer:
	var title := card.display_name
	var effect := ""
	var then := ""
	var risk := 0
	var move := m.next_move()
	var shot_next: bool = move.is_empty() or move["kind"] == "shot"
	match card.tag if not lunge else "lunge":
		"block", "track_back":
			var power := m.power_of(card)
			if card.tag == "track_back":
				power = roundi(power * MatchRules.TRACK_BACK_BOX_SCALE)
			var lower := maxi(MatchRules.MIN_THEIR_CHANCE, m.quality - power)
			effect = "Chance %d → %d" % [m.quality, lower]
			if shot_next:
				then = "They shoot: %d%%" % m.their_goal_odds_at(lower)
			else:
				var after: int = lower + move["gain"]
				then = "After the %s: %d%%" % [move["kind"], m.their_goal_odds_at(after)]
		"tackle", "lunge":
			var chance := m.lunge_chance() if lunge else m.tackle_chance(card)
			var share := MatchRules.LUNGE_FOUL_SHARE if lunge else MatchRules.TACKLE_FOUL_SHARE
			if lunge:
				title = "Lunge"
				effect = "%d%% · random card" % chance
			if not lunge:
				effect = "%d%% win it" % chance
			var beaten: int = m.quality + MatchRules.BEATEN_BONUS + (0 if shot_next else move["gain"])
			then = "Beaten: chance %d" % beaten
			risk = roundi((100 - chance) * share / 100.0)
		"lump_clear":
			effect = "Clear it out"
			then = "They keep the ball"
		_:
			effect = "—"

	var panel := PanelContainer.new()
	var hot := card.tag == "tackle" or lunge
	var edge := GREEN.darkened(0.45) if hot else ROW_EDGE
	panel.set_meta("edge", edge)        ## remembered, so _light_rows() can put it back
	panel.add_theme_stylebox_override("panel", _box_style(ROW, edge, 1, 8, 12, 5))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var name_label := _label(title, ROW_FONT + 2, Color.WHITE)
	name_label.custom_minimum_size.x = 124
	name_label.clip_text = true
	row.add_child(name_label)
	var effect_label := _label(effect, ROW_FONT - 2, GREEN)
	effect_label.custom_minimum_size.x = 150
	row.add_child(effect_label)
	var then_label := _label(then, ROW_FONT - 4, LIGHT)
	then_label.custom_minimum_size.x = 140
	row.add_child(then_label)
	row.add_child(_risk_bar(risk))
	var risk_label := _label("%d%% foul" % risk if risk > 0 else "Safe", ROW_FONT - 2, Color("ff8f82") if risk > 0 else GREEN)
	risk_label.custom_minimum_size.x = 80
	risk_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(risk_label)
	return panel

## A thin red bar: the foul risk out of 100.
func _risk_bar(risk: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 100
	bar.value = risk
	bar.custom_minimum_size = Vector2(40, 10)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override("background", _box_style(TRACK, TRACK, 0, 5, 0, 0))
	bar.add_theme_stylebox_override("fill", _box_style(RED, RED, 0, 5, 0, 0))
	return bar

func _tile(fill: Color, edge: Color, edge_width: int) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.add_theme_stylebox_override("panel", _box_style(fill, edge, edge_width, 12, 16, 10))
	return tile

func _box_style(fill: Color, border: Color, border_width: int, radius: int,
		margin_x: int, margin_y: int = -1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin_x
	style.content_margin_right = margin_x
	style.content_margin_top = margin_x if margin_y < 0 else margin_y
	style.content_margin_bottom = margin_x if margin_y < 0 else margin_y
	return style

func _label(text: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	return l
