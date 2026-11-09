class_name BoxView
extends PanelContainer
## The big view of their box (push your luck), shown in place of the pitch strip while
## you're in it. Display only: match_screen tells it what to show; MatchRules decides.
## Three sections: where you are and SHOOT NOW side by side, OR KEEP BUILDING underneath.

const GOLD := Color("f2b233")
const GREEN := Color("7be07b")
const RED := Color("f0857a")
const GREY := Color("b9c4b8")
const DIM := Color("6f7d70")
const PANEL := Color("16261b")
const TILE := Color("223829")
## Shown under the title, one per card already played in this attack.
const PRESSURE := ["Defenders still getting back", "They're closing in", "Tight now", "Swarmed"]
const BUILD_TAGS := ["pass", "dribble", "cross"]

var _pressure: Label
var _chance: Label
var _status: Label
var _button_odds: Label
var _button_note: Label
var _card_tile: PanelContainer
var _card_odds: Label
var _card_note: Label
var _build_title: Label
var _rows: VBoxContainer

func _init() -> void:
	add_theme_stylebox_override("panel", _box_style(PANEL, GOLD, 3, 24))
	## Top row: where you are | SHOOT NOW. Underneath, full width: OR KEEP BUILDING.
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 28)
	add_child(outer)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 40)
	outer.add_child(columns)

	## Left: where you are, and the gamble / result line.
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 340
	left.add_theme_constant_override("separation", 6)
	columns.add_child(left)
	left.add_child(_label("IN THEIR BOX", 34, GOLD))
	_pressure = _label("", 22, GREY)
	left.add_child(_pressure)
	_chance = _label("", 26, Color.WHITE)
	left.add_child(_chance)
	_status = _label("", 30, GOLD)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.x = 340
	left.add_child(_status)

	## Middle: SHOOT NOW, the two ways to shoot side by side.
	var middle := VBoxContainer.new()
	middle.add_theme_constant_override("separation", 10)
	columns.add_child(middle)
	middle.add_child(_label("SHOOT NOW", 22, GOLD))
	var tiles := HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 14)
	middle.add_child(tiles)
	var button_tile := _tile()
	tiles.add_child(button_tile)
	var button_box := button_tile.get_child(0)
	button_box.add_child(_label("Shoot button", 22, Color.WHITE))
	_button_odds = _label("", 60, GOLD)
	button_box.add_child(_button_odds)
	_button_note = _label("", 18, GREY)
	button_box.add_child(_button_note)
	_card_tile = _tile()
	tiles.add_child(_card_tile)
	var card_box := _card_tile.get_child(0)
	card_box.add_child(_label("Shoot card", 22, Color.WHITE))
	_card_odds = _label("", 60, GOLD)
	card_box.add_child(_card_odds)
	_card_note = _label("", 18, GREY)
	card_box.add_child(_card_note)

	## Underneath: OR KEEP BUILDING, one row per Pass / Dribble / Cross you could play.
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	outer.add_child(right)
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
	_status.text = ""
	_chance.text = "Chance %d" % m.quality
	if m.rebound:
		_pressure.text = "REBOUND! One more shot"
	else:
		_pressure.text = PRESSURE[mini(m.box_cards_played, PRESSURE.size() - 1)]

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

## The gamble, before the result is shown.
func suspense(text: String) -> void:
	_status.add_theme_color_override("font_color", GOLD)
	_status.text = text
	_status.visible_ratio = 0.0
	create_tween().tween_property(_status, "visible_ratio", 1.0, SettingsState.t(0.3))

## The result, with a little pop.
func flash(text: String, colour: Color) -> void:
	_status.add_theme_color_override("font_color", colour)
	_status.text = text
	_status.visible_ratio = 1.0
	_status.pivot_offset = _status.size / 2
	_status.scale = Vector2(1.3, 1.3)
	create_tween().tween_property(_status, "scale", Vector2.ONE, SettingsState.t(0.25))

## One Pass / Dribble / Cross: what it adds, your best shot afterwards, and the risk.
func _build_row(m: MatchRules, card: ActionCard) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	var title := _label(card.display_name, 24, Color.WHITE)
	title.custom_minimum_size.x = 150
	row.add_child(title)
	var gain := m.box_gain(card)
	var gain_label := _label("+%d chance" % gain, 24, GREY)
	gain_label.custom_minimum_size.x = 140
	row.add_child(gain_label)
	var then_label := _label("then shoot %d%%" % _best_shot_at(m, m.quality + gain), 24, GREEN)
	then_label.custom_minimum_size.x = 200
	row.add_child(then_label)
	row.add_child(_label("%d%% to lose it" % m.box_risk(card.tag), 24, RED))
	return row

## Your best odds from a chance of q: the Shoot button, or a Shoot card if you hold one.
func _best_shot_at(m: MatchRules, q: int) -> int:
	var best := m.basic_shot_odds_at(q)
	for card in DeckState.hand:
		if card.tag == "shot":
			best = maxi(best, m.basic_shot_odds_at(q + m.power_of(card)))
	return best

## A shooting option tile: a rounded panel holding a VBox.
func _tile() -> PanelContainer:
	var tile := PanelContainer.new()
	tile.custom_minimum_size.x = 210
	tile.add_theme_stylebox_override("panel", _box_style(TILE, Color("3d5a45"), 1, 14))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	tile.add_child(box)
	return tile

func _box_style(fill: Color, border: Color, border_width: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(margin)
	return style

func _label(text: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	return l
