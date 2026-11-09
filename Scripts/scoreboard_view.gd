class_name ScoreboardView
extends VBoxContainer
## The scoreboard at the top of the match screen: both team names, the score in two big
## digit tiles, and the minute on a tab hanging underneath. Display only: match_screen feeds it.
## You are always on the left.

const GOLD := Color("f2b233")
const INK := Color("edefe9")
const DIM := Color("8fa190")
const RED := Color("ff7a6b")
const BOARD := Color("090e0a")
const EDGE := Color("2e3d31")
const TILE := Color("161e18")
const DASH := Color("4f5f51")
const NAME_WIDTH := 360          ## each team name's box; longer names are trimmed with "…"
const NAME_SIZE := 40
const NOTE_SIZE := 16
const DIGIT_SIZE := 64
const TILE_SIZE := Vector2(64, 84)
const MINUTE_SIZE := 32
const HALF_TIME := 45

var _home_name := Label.new()
var _home_note := Label.new()
var _away_name := Label.new()
var _away_note := Label.new()
var _home_goals := Label.new()
var _away_goals := Label.new()
var _minute := Label.new()
var _half := Label.new()

func _init() -> void:
	add_theme_constant_override("separation", 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	## The board: your name | score | their name.
	var board := PanelContainer.new()
	board.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	board.add_theme_stylebox_override("panel", _panel_style(true))
	add_child(board)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	board.add_child(row)
	row.add_child(_team_block(_home_name, _home_note, HORIZONTAL_ALIGNMENT_RIGHT))
	var score := HBoxContainer.new()
	score.add_theme_constant_override("separation", 10)
	row.add_child(score)
	score.add_child(_digit_tile(_home_goals))
	var dash := Label.new()
	dash.text = "–"
	_style(dash, 44, DASH)
	dash.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	score.add_child(dash)
	score.add_child(_digit_tile(_away_goals))
	row.add_child(_team_block(_away_name, _away_note, HORIZONTAL_ALIGNMENT_LEFT))

	## The clock tab hanging under the board: just the minute and which half.
	var tab := PanelContainer.new()
	tab.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tab.add_theme_stylebox_override("panel", _panel_style(false))
	add_child(tab)
	var clock := HBoxContainer.new()
	clock.add_theme_constant_override("separation", 14)
	tab.add_child(clock)
	_style(_minute, MINUTE_SIZE, GOLD)
	clock.add_child(_minute)
	_style(_half, NOTE_SIZE, DIM)
	_half.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	clock.add_child(_half)

## Team names. Called once, at kick-off.
func setup(you: String, them: String, they_are_favourites: bool) -> void:
	_home_name.text = you.to_upper()
	_home_note.text = "YOU"
	_away_name.text = them.to_upper()
	_away_note.text = "★ FAVOURITES" if they_are_favourites else ""
	_away_note.add_theme_color_override("font_color", RED if they_are_favourites else DIM)

## Score and minute. Called whenever the screen refreshes (and during replays).
func show_score(you: int, them: int, minute: int) -> void:
	_home_goals.text = str(you)
	_away_goals.text = str(them)
	_minute.text = "%d'" % minute
	_half.text = "1ST HALF" if minute <= HALF_TIME else "2ND HALF"

## One team: big name, small note underneath, lined up towards the score.
func _team_block(name_label: Label, note: Label, align: HorizontalAlignment) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = NAME_WIDTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	_style(name_label, NAME_SIZE, INK)
	name_label.horizontal_alignment = align
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(name_label)
	_style(note, NOTE_SIZE, DIM)
	note.horizontal_alignment = align
	box.add_child(note)
	return box

## A score digit in its own dark tile, with a thin line across the middle (split-flap style).
func _digit_tile(digit: Label) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.custom_minimum_size = TILE_SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = TILE
	style.border_color = EDGE
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	tile.add_theme_stylebox_override("panel", style)
	_style(digit, DIGIT_SIZE, GOLD)
	digit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	digit.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tile.add_child(digit)
	## The line is a child of the label (not the tile), so the container doesn't stretch it.
	var line := ColorRect.new()
	line.color = BOARD
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.anchor_left = 0.0
	line.anchor_right = 1.0
	line.anchor_top = 0.5
	line.anchor_bottom = 0.5
	line.offset_top = -1
	line.offset_bottom = 1
	digit.add_child(line)
	return tile

## The board (rounded all round) or the clock tab (no top edge, rounded at the bottom).
func _panel_style(is_board: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BOARD
	style.border_color = EDGE
	style.set_border_width_all(2)
	if is_board:
		style.set_corner_radius_all(12)
		style.content_margin_left = 20
		style.content_margin_right = 20
		style.content_margin_top = 10
		style.content_margin_bottom = 10
	else:
		style.border_width_top = 0
		style.corner_radius_bottom_left = 12
		style.corner_radius_bottom_right = 12
		style.content_margin_left = 24
		style.content_margin_right = 24
		style.content_margin_top = 4
		style.content_margin_bottom = 8
	return style

func _style(label: Label, font_size: int, colour: Color) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
