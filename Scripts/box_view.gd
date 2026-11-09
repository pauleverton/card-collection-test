class_name BoxView
extends PanelContainer
## The big view of their box (push your luck), shown in place of the bar and pitch while
## you're in it. Display only: match_screen tells it what to show; MatchRules decides.
##   Left:  their penalty area drawn (BoxPitchView), with the gamble / result written across it.
##   Right: the chance, SHOOT NOW (button and card odds), OR KEEP BUILDING (one row per card).

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
const ODDS_SIZE := 72           ## the big % numbers
## Shown under the title, one per card already played in this attack.
const PRESSURE := ["Defenders still getting back", "They're closing in", "Tight now", "Swarmed"]
const BUILD_TAGS := ["pass", "dribble", "cross"]

var _drawing := BoxPitchView.new()
var _chance: Label
var _pressure: Label
var _button_odds: Label
var _button_note: Label
var _card_tile: PanelContainer
var _card_odds: Label
var _card_note: Label
var _build_title: Label
var _rows: VBoxContainer

func _init() -> void:
	add_theme_stylebox_override("panel", _box_style(PANEL, GOLD, 3, 12, 20))
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	add_child(columns)
	_drawing.custom_minimum_size.x = DRAWING_WIDTH
	columns.add_child(_drawing)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	columns.add_child(right)

	## Header: IN THEIR BOX ........ Chance 21, and how close the defenders are underneath.
	var header := HBoxContainer.new()
	right.add_child(header)
	var title := _label("IN THEIR BOX", 34, GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_chance = _label("", 30, Color.WHITE)
	header.add_child(_chance)
	_pressure = _label("", 20, GREY)
	right.add_child(_pressure)

	## SHOOT NOW: the two ways to shoot, sharing the width. They grow taller when
	## there's nothing to build with, so the column never ends in a gap.
	right.add_child(_label("SHOOT NOW", 22, GOLD))
	var tiles := HBoxContainer.new()
	tiles.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tiles.add_theme_constant_override("separation", 14)
	right.add_child(tiles)
	var button_tile := _tile()
	tiles.add_child(button_tile)
	var button_box := button_tile.get_child(0)
	button_box.add_child(_label("Shoot button", 22, Color.WHITE))
	_button_odds = _label("", ODDS_SIZE, GOLD)
	button_box.add_child(_button_odds)
	_button_note = _label("", 18, GREY)
	button_box.add_child(_button_note)
	_card_tile = _tile()
	tiles.add_child(_card_tile)
	var card_box := _card_tile.get_child(0)
	card_box.add_child(_label("Shoot card", 22, Color.WHITE))
	_card_odds = _label("", ODDS_SIZE, GOLD)
	card_box.add_child(_card_odds)
	_card_note = _label("", 18, GREY)
	card_box.add_child(_card_note)

	## OR KEEP BUILDING: one row per Pass / Dribble / Cross you could play.
	_build_title = _label("OR KEEP BUILDING (risky)", 22, RED)
	right.add_child(_build_title)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 8)
	right.add_child(_rows)

## Redraw from the match. Hidden unless you have the ball in their box.
func show_state(m: MatchRules) -> void:
	visible = m.in_their_box() and not m.match_over
	if not visible:
		return
	_drawing.show_pressure(m.box_cards_played, m.rebound)
	_chance.text = "Chance %d" % m.quality
	if m.rebound:
		_pressure.text = "REBOUND! One more shot"
		_pressure.add_theme_color_override("font_color", GOLD)
	else:
		_pressure.text = PRESSURE[mini(m.box_cards_played, PRESSURE.size() - 1)]
		_pressure.add_theme_color_override("font_color", GREY)

	## Shoot button: the chance plus a random roll.
	_button_odds.text = "%d%%" % m.basic_shot_odds()
	_button_note.text = "random strike +%d to +%d" % [
			m.basic_shot_roll_low(), m.basic_shot_roll_high()]

	## Shoot card: your best one in hand, if you can play it.
	var best_card: ActionCard = null
	for card in DeckState.hand:
		if card.tag == "shot" and m.can_play_here(card) and card.energy_cost <= m.energy:
			if best_card == null or m.power_of(card) > m.power_of(best_card):
				best_card = card
	if best_card != null:
		var power := m.power_of(best_card)
		_card_odds.text = "%d%%" % m.basic_shot_odds_at(m.quality + power)
		_card_note.text = "random strike, +%d more" % power
		_card_tile.modulate = Color.WHITE
	else:
		_card_odds.text = "—"
		_card_note.text = "none in your hand"
		_card_tile.modulate = Color(1, 1, 1, 0.4)

	## Keep building: one row per different Pass / Dribble / Cross you can play.
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	if m.rebound:
		_build_title.text = "REBOUND: SHOTS ONLY"
		return
	_build_title.text = "OR KEEP BUILDING (risky)"
	var seen := []
	for card in DeckState.hand:
		if card.tag not in BUILD_TAGS or card.display_name in seen:
			continue
		if not m.can_play_here(card) or card.energy_cost > m.energy:
			continue
		seen.append(card.display_name)
		_rows.add_child(_build_row(m, card))
	if seen.is_empty():
		_rows.add_child(_label("Nothing to build with: time to shoot!", 22, DIM))

## The gamble, written across the drawing before the result is shown.
func suspense(text: String) -> void:
	_drawing.say(text, GOLD)

## The result, with a little pop.
func flash(text: String, colour: Color) -> void:
	_drawing.say(text, colour, true)

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
	var then_label := _label("then shoot %d%%" % _best_shot_at(m, m.quality + gain), 18, LIGHT)
	then_label.custom_minimum_size.x = 150
	row.add_child(then_label)
	var risk := m.box_risk(card.tag)
	row.add_child(_risk_bar(risk))
	var risk_label := _label("%d%% lose it" % risk, 22, RED)
	risk_label.custom_minimum_size.x = 120
	risk_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(risk_label)
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

## Your best odds from a chance of q: the Shoot button, or a Shoot card if you hold one.
func _best_shot_at(m: MatchRules, q: int) -> int:
	var best := m.basic_shot_odds_at(q)
	for card in DeckState.hand:
		if card.tag == "shot":
			best = maxi(best, m.basic_shot_odds_at(q + m.power_of(card)))
	return best

## A shooting option tile: a rounded panel holding a centred VBox. Shares the width.
func _tile() -> PanelContainer:
	var tile := PanelContainer.new()
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.add_theme_stylebox_override("panel", _box_style(TILE, TILE_EDGE, 1, 12, 18, 14))
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	tile.add_child(box)
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
