class_name BoxView
extends PanelContainer
## The big view of their box (push your luck), shown in place of the bar and pitch while
## you're in it. Display only: match_screen tells it what to show; MatchRules decides.
##   Left:  their penalty area drawn (BoxPitchView), with the gamble / result written across it.
##   Right: the chance, SHOOT NOW (button and card odds), OR KEEP BUILDING (one row per card).
## Hovering a card in your hand previews it here (preview()): a Shoot card fills the card tile
## with ITS odds, a Pass / Dribble / Cross lights up its row.

const GOLD := Color("f2b233")
const GREEN := Color("7be07b")
const RED := Color("f0857a")
const RISK := Color("e0574a")
const GREY := Color("b9c4b8")
const LIGHT := Color("cfd8ce")
const DIM := Color("6f7d70")
const PANEL := Color("16261b")
const TILE := Color("223829")
const TILE_EDGE := Color("3d5a45")
const ROW := Color("241414")
const ROW_EDGE := Color("4a2723")
const TRACK := Color("140b0a")
const DRAWING_WIDTH := 480      ## the penalty-area drawing on the left
const ODDS_SIZE := 56           ## the big % numbers
const ODDS_WIDTH := 120         ## room for "100%"
## Shown under the title, one per card already played in this attack.
const PRESSURE := ["Defenders still getting back", "They're closing in", "Tight now", "Swarmed"]
const BUILD_TAGS := ["pass", "dribble", "cross"]
const TILE_TITLE_SIZE := 20     ## card name on the shoot card tile (shrinks to fit long names)
const TILE_TITLE_MIN := 14

var _drawing := BoxPitchView.new()
var _chance: Label
var _pressure: Label
var _button_title: Label
var _button_odds: Label
var _button_note: Label
var _card_tile: PanelContainer
var _card_title: Label
var _card_odds: Label
var _card_note: Label
var _build_title: Label
var _rows: VBoxContainer
var _m: MatchRules = null           ## the match, kept from show_state() so preview() can redraw
var _hovered: ActionCard = null     ## the card under the mouse in your hand (null = none)
var _row_for := {}                  ## card name -> its build row (to light it up on hover)

func _init() -> void:
	add_theme_stylebox_override("panel", _box_style(PANEL, GOLD, 3, 12, 20))
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	add_child(columns)
	_drawing.custom_minimum_size.x = DRAWING_WIDTH
	columns.add_child(_drawing)

	## Right column. Everything sits at the top: the bottom ~130px stays empty on purpose,
	## because a hovered card in your hand lifts up over it.
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	columns.add_child(right)

	## Header: IN THEIR BOX ........ Chance 21
	var header := HBoxContainer.new()
	right.add_child(header)
	var title := _label("IN THEIR BOX", 34, GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_chance = _label("", 30, Color.WHITE)
	header.add_child(_chance)

	## SHOOT NOW ........ how close the defenders are
	var shoot_row := HBoxContainer.new()
	right.add_child(shoot_row)
	var shoot_title := _label("SHOOT NOW", 22, GOLD)
	shoot_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shoot_row.add_child(shoot_title)
	_pressure = _label("", 20, GREY)
	shoot_row.add_child(_pressure)

	## The two ways to shoot, side by side: big % on the left of each tile, words on the right.
	var tiles := HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 14)
	right.add_child(tiles)
	_button_odds = _label("", ODDS_SIZE, GOLD)
	_button_note = _label("", 16, GREY)
	_button_title = _label("Shoot button", TILE_TITLE_SIZE, Color.WHITE)
	tiles.add_child(_tile(_button_title, _button_odds, _button_note))
	_card_title = _label("Shoot card", TILE_TITLE_SIZE, Color.WHITE)
	_card_odds = _label("", ODDS_SIZE, GOLD)
	_card_note = _label("", 16, GREY)
	_card_tile = _tile(_card_title, _card_odds, _card_note)
	tiles.add_child(_card_tile)

	## OR KEEP BUILDING: one row per Pass / Dribble / Cross you could play.
	_build_title = _label("OR KEEP BUILDING (risky)", 22, RED)
	right.add_child(_build_title)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 8)
	right.add_child(_rows)

## Redraw from the match. Hidden unless you have the ball in their box.
func show_state(m: MatchRules) -> void:
	var was_showing := visible
	visible = m.in_their_box() and not m.match_over
	_m = m
	if not visible:
		return
	if not was_showing:
		_drawing.new_attack(m.their_defence)     ## a fresh attack: new positions every time
	if m.penalty:
		_drawing.quiet()        ## a penalty: everyone stays out of the box, so don't close in
	else:
		_drawing.show_pressure(m.box_cards_played, m.rebound)
	_chance.text = "Penalty" if m.penalty else "Chance %d" % m.quality
	if m.penalty:
		_pressure.text = "PENALTY! One shot"
		_pressure.add_theme_color_override("font_color", GOLD)
	elif m.rebound:
		_pressure.text = "REBOUND! One more shot"
		_pressure.add_theme_color_override("font_color", GOLD)
	else:
		_pressure.text = PRESSURE[mini(m.box_cards_played, PRESSURE.size() - 1)]
		_pressure.add_theme_color_override("font_color", GREY)

	## Shoot button: the chance plus a random roll. On a penalty it takes the penalty instead.
	if m.penalty:
		var odds: Dictionary = m.your_penalty_odds()
		_button_title.text = "Penalty"
		_button_odds.text = "%d%%" % odds["score"]
		_button_note.text = "saved %d%% · miss %d%%" % [odds["save"], odds["miss"]]
	else:
		_button_title.text = "Shoot button"
		_button_odds.text = "%d%%" % m.basic_shot_odds()
		_button_note.text = "random strike +%d to +%d" % [
				m.basic_shot_roll_low(), m.basic_shot_roll_high()]

	## Shoot card: the hovered one, or your best one you can play.
	_show_card_tile()

	## Keep building: one row per different Pass / Dribble / Cross you can play.
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_row_for.clear()
	if m.rebound or m.penalty:
		_build_title.text = "PENALTY: NO CARDS, JUST THE KICK" if m.penalty else "REBOUND: SHOTS ONLY"
		return
	_build_title.text = "OR KEEP BUILDING (risky)"
	var seen := []
	for card in DeckState.hand:
		if card.tag not in BUILD_TAGS or card.display_name in seen:
			continue
		if not m.can_play_here(card) or card.energy_cost > m.energy:
			continue
		seen.append(card.display_name)
		var row := _build_row(m, card)
		_row_for[card.display_name] = row
		_rows.add_child(row)
	if seen.is_empty():
		_rows.add_child(_label("Nothing to build with: time to shoot!", 22, DIM))
	_light_rows()

## The card under the mouse in your hand (null when the mouse leaves). Redraws only the parts
## that depend on it, so nothing flickers.
func preview(card: ActionCard) -> void:
	_hovered = card
	if not visible or _m == null:
		return
	_show_card_tile()
	_light_rows()

## The hovered card, if it's still in your hand (a played card can still be "hovered" for a moment).
func _hovered_card() -> ActionCard:
	if _hovered != null and _hovered in DeckState.hand:
		return _hovered
	return null

## Can you play this Shoot card right now (right place, enough energy)?
func _can_shoot_with(card: ActionCard) -> bool:
	return card.tag == "shot" and _m.can_play_here(card) and card.energy_cost <= _m.energy

## The card tile: a hovered Shoot card shows ITS odds; otherwise your best playable one, by name.
func _show_card_tile() -> void:
	var m := _m
	if m.penalty:
		_set_card_title("Shoot card")
		_card_odds.text = "—"
		_card_note.text = "not on a penalty"
		_card_tile.modulate = Color(1, 1, 1, 0.4)
		_card_tile.add_theme_stylebox_override("panel", _box_style(TILE, TILE_EDGE, 1, 12, 16, 8))
		return
	var card := _hovered_card()
	var hovering := card != null and card.tag == "shot"
	if not hovering:
		card = null
		for c in DeckState.hand:
			if _can_shoot_with(c) and (card == null or m.power_of(c) > m.power_of(card)):
				card = c
	if card == null:
		_set_card_title("Shoot card")
		_card_odds.text = "—"
		_card_note.text = "none you can play"
		_card_tile.modulate = Color(1, 1, 1, 0.4)
		_card_tile.add_theme_stylebox_override("panel", _box_style(TILE, TILE_EDGE, 1, 12, 16, 8))
		return
	_set_card_title(card.display_name)
	var power := m.power_of(card)
	if _can_shoot_with(card):
		_card_odds.text = "%d%%" % m.basic_shot_odds_at(m.quality + power)
		_card_note.text = "%d energy · +%d" % [card.energy_cost, power]
		_card_tile.modulate = Color.WHITE
	else:
		_card_odds.text = "—"
		_card_note.text = "needs %d energy" % card.energy_cost
		_card_tile.modulate = Color(1, 1, 1, 0.6)
	## Gold edge while it's the card under your mouse, so you can see the tile is following it.
	var edge := GOLD if hovering else TILE_EDGE
	_card_tile.add_theme_stylebox_override("panel", _box_style(TILE, edge, 2 if hovering else 1, 12, 16, 8))

## Card names vary in length ("Really hard Shot"): shrink the title to fit on one line.
func _set_card_title(text: String) -> void:
	_card_title.text = text
	var font := _card_title.get_theme_font("font")
	## Room = the tile minus its margins, the big % and the gap (the label's own size lags a frame).
	var room := _card_tile.size.x - 32 - ODDS_WIDTH - 14
	if room <= 0:
		room = 180.0
	var font_size := TILE_TITLE_SIZE
	while font_size > TILE_TITLE_MIN and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > room:
		font_size -= 1
	_card_title.add_theme_font_size_override("font_size", font_size)

## Gold edge on the build row of the hovered card (two Short Passes share one row).
func _light_rows() -> void:
	var card := _hovered_card()
	for card_name in _row_for:
		var lit: bool = card != null and card.display_name == card_name
		var row: PanelContainer = _row_for[card_name]
		row.add_theme_stylebox_override("panel",
				_box_style(ROW, GOLD if lit else ROW_EDGE, 2 if lit else 1, 8, 12, 6))

## The gamble, written across the drawing before the result is shown.
func suspense(text: String) -> void:
	_drawing.say(text, GOLD)

## The result, with a little pop, and the move playing out on the drawing.
## kind: "gain" / "lost" / "penalty" / "goal" / "saved" / "rebound"; tag: the card's tag (pass / dribble / cross).
func flash(text: String, colour: Color, kind: String = "", tag: String = "") -> void:
	_drawing.say(text, colour, true)
	_drawing.act(kind, tag)

## One Pass / Dribble / Cross: what it adds, your best shot afterwards, and the risk (as a bar).
func _build_row(m: MatchRules, card: ActionCard) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box_style(ROW, ROW_EDGE, 1, 8, 12, 6))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var title := _label(card.display_name, 22, Color.WHITE)
	title.custom_minimum_size.x = 120
	row.add_child(title)
	var gain := m.box_gain(card)
	var gain_label := _label("+%d" % gain, 22, GREEN)
	gain_label.custom_minimum_size.x = 50
	row.add_child(gain_label)
	var energy_left := m.energy - card.energy_cost
	var then_label := _label("then shoot %d%%" % _best_shot_at(m, m.quality + gain, energy_left), 18, LIGHT)
	then_label.custom_minimum_size.x = 150
	row.add_child(then_label)
	## The risk splits in two: losing it (red) and being fouled = a penalty for you (gold).
	var pen := m.box_penalty_chance(card.tag)
	var lose := m.box_risk(card.tag) - pen
	row.add_child(_risk_bar(lose))
	var risk_label := _label("%d%% lose it" % lose, 22, RED)
	risk_label.custom_minimum_size.x = 112
	risk_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(risk_label)
	if pen > 0:
		var pen_label := _label("%d%% pen" % pen, 18, GOLD)
		pen_label.custom_minimum_size.x = 62
		pen_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(pen_label)
	return panel

## A thin red bar showing the risk out of 100.
func _risk_bar(risk: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 100
	bar.value = risk
	bar.custom_minimum_size.y = 12
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override("background", _box_style(TRACK, TRACK, 0, 6, 0, 0))
	bar.add_theme_stylebox_override("fill", _box_style(RISK, RISK, 0, 6, 0, 0))
	return bar

## Your best odds from a chance of q with `energy` left: the Shoot button, or a Shoot card you
## could still afford. (Building always leaves enough energy for the button.)
func _best_shot_at(m: MatchRules, q: int, energy: int) -> int:
	var best := m.basic_shot_odds_at(q)
	for card in DeckState.hand:
		if card.tag == "shot" and card.energy_cost <= energy:
			best = maxi(best, m.basic_shot_odds_at(q + m.power_of(card)))
	return best

## A shooting option tile, sharing the width: the big % on the left, title and note on the right.
func _tile(title: Label, odds: Label, note: Label) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.add_theme_stylebox_override("panel", _box_style(TILE, TILE_EDGE, 1, 12, 16, 8))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	tile.add_child(row)
	odds.custom_minimum_size.x = ODDS_WIDTH
	odds.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(odds)
	var words := VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 2)
	row.add_child(words)
	title.clip_text = true
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(title)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 120
	words.add_child(note)
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
