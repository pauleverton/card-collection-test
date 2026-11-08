class_name BoxView
extends PanelContainer
## The big view of their box (push your luck), shown in place of the pitch strip while
## you're in it. Display only: match_screen tells it what to show; MatchRules decides.

const GOLD := Color("f2b233")
const GREEN := Color("7be07b")
const RED := Color("f0857a")
const GREY := Color("b9c4b8")
## Shown under the title, one per card already played in this attack.
const PRESSURE := ["Defenders still getting back", "They're closing in", "Tight now", "Swarmed"]

var _pressure: Label
var _odds: Label
var _chance: Label
var _status: Label
var _rows: VBoxContainer

func _init() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("16261b")
	style.border_color = GOLD
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(24)
	add_theme_stylebox_override("panel", style)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 48)
	add_child(columns)

	## Left: the title, the pressure, the big Shoot now %, and the gamble / result line.
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(left)
	left.add_child(_label("IN THEIR BOX", 34, GOLD))
	_pressure = _label("", 22, GREY)
	left.add_child(_pressure)
	var odds_row := HBoxContainer.new()
	odds_row.add_theme_constant_override("separation", 16)
	left.add_child(odds_row)
	_odds = _label("", 84, GOLD)
	odds_row.add_child(_odds)
	_chance = _label("", 24, GREY)
	_chance.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	odds_row.add_child(_chance)
	_status = _label("", 34, GOLD)
	left.add_child(_status)

	## Right: one row per card you could play here.
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	columns.add_child(right)
	right.add_child(_label("YOUR OPTIONS", 22, GREY))
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 8)
	right.add_child(_rows)

## Redraw from the match. Hidden unless you have the ball in their box.
func show_state(m: MatchRules) -> void:
	visible = m.in_their_box() and not m.match_over
	if not visible:
		return
	_status.text = ""
	_odds.text = "%d%%" % m.basic_shot_odds()
	_chance.text = "SHOOT NOW\nchance %d" % m.quality
	if m.rebound:
		_pressure.text = "REBOUND! One more shot, shots only"
	else:
		_pressure.text = PRESSURE[mini(m.box_cards_played, PRESSURE.size() - 1)]
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	var seen := []
	for card in DeckState.hand:
		if card.tag not in ["pass", "dribble", "cross", "shot"] or card.display_name in seen:
			continue
		if not m.can_play_here(card) or card.energy_cost > m.energy:
			continue
		seen.append(card.display_name)
		_rows.add_child(_option_row(m, card))
	if seen.is_empty():
		_rows.add_child(_label("Nothing else to play: Shoot!", 24, GREY))

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

func _option_row(m: MatchRules, card: ActionCard) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	var title := _label(card.display_name, 26, Color.WHITE)
	title.custom_minimum_size.x = 180
	row.add_child(title)
	if card.tag == "shot":
		var power := m.power_of(card)
		row.add_child(_label("+%d strike → scores %d%%" % [power, m.goal_odds(m.quality + power)], 26, GREEN))
		row.add_child(_label("no risk", 26, GREY))
	else:
		var gain := m.box_gain(card)
		row.add_child(_label("+%d → shoot %d%%" % [gain, m.basic_shot_odds_at(m.quality + gain)], 26, GREEN))
		row.add_child(_label("%d%% to lose it" % m.box_risk(card.tag), 26, RED))
	return row

func _label(text: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	return l
