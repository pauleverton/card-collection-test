class_name SquadTileView
extends Control
## One member of the matchday squad, in the column down the left of the match screen.
##   Players: cream card, gold edge, initials (until there's artwork), name, what they do,
##            an ability chip (special players only) and games left this season.
##   Coaches: navy card, blue edge, name, what they do.
## Display only. react() is the pop + floating number when the player helps a card.
## The visible card is a child of this plain Control, so it can scale and tilt freely
## (containers reset the scale/rotation of their own children).

const PLAYER_HEIGHT := 112
const COACH_HEIGHT := 72
const PLAYER_FILL := Color("f3eedf")
const PLAYER_EDGE := Color("d4a12a")
const PLAYER_INK := Color("1b1f1a")
const PLAYER_EFFECT := Color("2c4f7c")
const PLAYER_NOTE := Color("6e6650")
const ART_FILL := Color("e6dfc9")
const ART_EDGE := Color("b9ae8e")
const ART_SIZE := 60
const COACH_FILL := Color("1a2a40")
const COACH_EDGE := Color("4c8bd9")
const COACH_INK := Color("e8eef6")
const COACH_EFFECT := Color("b8cbe4")
const CHIP_ON := Color("2e8b4e")
const CHIP_OFF := Color("d7cfb8")
const CHIP_OFF_TEXT := Color("5a5440")
const POP_SCALE := 1.1            ## how big the card grows when it reacts
const POP_TILT := 4.0             ## degrees of wiggle
const FLOAT_COLOUR := Color(0.4, 1.0, 0.4)

var player: StaffCard
var _card := PanelContainer.new()   ## the visible card: it's what pops and wiggles
var _chip_box: PanelContainer = null   ## only special (ability) players have one
var _chip: Label
var _pips: Label

func setup(data: StaffCard) -> void:
	player = data
	var is_coach := data is CoachCard
	custom_minimum_size.y = COACH_HEIGHT if is_coach else PLAYER_HEIGHT
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)
	_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_theme_stylebox_override("panel", _box(
			COACH_FILL if is_coach else PLAYER_FILL, COACH_EDGE if is_coach else PLAYER_EDGE, 3, 10))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_card.add_child(row)
	if not is_coach:
		row.add_child(_art_square(data.display_name))

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 2)
	row.add_child(text)
	text.add_child(_label(data.display_name.to_upper(), 20, COACH_INK if is_coach else PLAYER_INK))
	var effect := _label(data.description, 14, COACH_EFFECT if is_coach else PLAYER_EFFECT)
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect.max_lines_visible = 2
	text.add_child(effect)
	if is_coach:
		return

	## Bottom line: ability chip (if any), then games left.
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	text.add_child(bottom)
	if data.ability != null:
		_chip_box = PanelContainer.new()
		_chip = _label("", 12, Color.WHITE)
		_chip_box.add_child(_chip)
		bottom.add_child(_chip_box)
	_pips = _label("", 13, PLAYER_NOTE)
	bottom.add_child(_pips)
	_show_games()

## Update the ability chip from the match: ON, FROM 75', or WHEN LOSING etc.
func show_state(m: MatchRules) -> void:
	if _chip_box == null:
		return
	var ability: Ability = player.ability
	var on := ability.is_active(m)
	if on:
		_chip.text = "ON"
	elif m.minute < ability.active_from_minute:
		_chip.text = "FROM %d'" % ability.active_from_minute
	else:
		_chip.text = "WHEN " + ability.when_score.replace("_", " ").to_upper()
	_chip.add_theme_color_override("font_color", Color.WHITE if on else CHIP_OFF_TEXT)
	_chip_box.add_theme_stylebox_override("panel", _box(CHIP_ON if on else CHIP_OFF, Color.TRANSPARENT, 0, 4, 8, 1))

## Games left this season as pips: ● still to play, ○ used. (This match is already counted.)
func _show_games() -> void:
	var p := player as PlayerCard
	var most := p.max_appearances()
	var left := LeagueState.appearances_left(p)
	_pips.text = "%s%s  %d of %d left" % ["●".repeat(left), "○".repeat(maxi(most - left, 0)), left, most]

## Pop + wiggle, then float the bonus number. `delay` lets several players go in turn.
## Every length goes through SettingsState.t(), so the game-speed setting controls it.
func react(label_text: String, delay: float) -> void:
	var s := SettingsState
	_card.pivot_offset = _card.size / 2          ## grow/rotate from the centre
	var t := create_tween()
	t.tween_interval(delay)                       ## wait for our turn (already scaled by the caller)
	t.tween_callback(_float_number.bind(label_text))
	t.tween_property(_card, "scale", Vector2.ONE * POP_SCALE, s.t(0.1)) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_card, "rotation_degrees", POP_TILT, s.t(0.06))
	t.tween_property(_card, "rotation_degrees", -POP_TILT, s.t(0.08))
	t.tween_property(_card, "rotation_degrees", 0.0, s.t(0.06))
	t.parallel().tween_property(_card, "scale", Vector2.ONE, s.t(0.15))

func _float_number(label_text: String) -> void:
	var s := SettingsState
	var label := _label(label_text, 40, FLOAT_COLOUR)
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	label.z_index = 10
	label.position = Vector2(size.x - 90, -20)   ## up by the right-hand edge
	add_child(label)
	var t := create_tween()
	t.tween_property(label, "position:y", label.position.y - 60, s.t(0.6))
	t.parallel().tween_property(label, "modulate:a", 0.0, s.t(0.6)).set_delay(s.t(0.2))
	t.tween_callback(label.queue_free)            ## tidy up when it's gone

## A square with the player's initials, where his artwork will go later.
func _art_square(full_name: String) -> PanelContainer:
	var square := PanelContainer.new()
	square.custom_minimum_size = Vector2(ART_SIZE, ART_SIZE)
	square.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	square.add_theme_stylebox_override("panel", _box(ART_FILL, ART_EDGE, 2, 8, 0, 0))
	var initials := ""
	for word in full_name.split(" ", false):
		if initials.length() < 2:
			initials += word.left(1).to_upper()
	var label := _label(initials, 24, PLAYER_NOTE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	square.add_child(label)
	return square

func _box(fill: Color, edge: Color, width: int, radius: int,
		margin_x: int = 12, margin_y: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin_x
	style.content_margin_right = margin_x
	style.content_margin_top = margin_y
	style.content_margin_bottom = margin_y
	return style

func _label(text: String, font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	return label
