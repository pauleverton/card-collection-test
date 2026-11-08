extends Control
## The team sheet, between the hub and the match. The whiteboard (TacticsBoard) shows your
## starters plus the manager's notes (BoardNotes); the scouting report shows the opponent;
## the bench holds everyone else. Click a bench player to bring him on, a magnet to take
## him off (he's rubbed out). Everything is built in code; the scene is just this root node.

const PLAYER_UI := preload("res://Scenes/player_card_view.tscn")
const BACKGROUND := Color("0f1a14")
const GOLD := Color("f2c14e")
const GREY := Color("9fb09f")
const SOFT := Color("7e8f80")
const WHITE := Color("edefe9")
const RED := Color("c4473a")
const PANEL := Color("16261b")
const PANEL_EDGE := Color("2b4232")
const BENCH_WOOD := Color("2e2a24")
const BENCH_CARD := Color("d9dcd4")
const BENCH_TEXT := Color("141a15")
const RESTED_CARD := Color("4a463f")
const RESTED_TEXT := Color("9a968e")
const COACH_FILL := Color("16243a")
const COACH_EDGE := Color("7fb3ff")
const GAP := 16
## 240 wide = a full bench of 7 fits on one row.
const TILE_SIZE := Vector2(240, 116)
const TILE_FONT := 18
## Scouting report: ratings from easy (green) to hard (red), and what each means for you.
const RATING_STEPS := ["VL", "L", "M", "H", "VH"]
const RATING_COLOURS := {
	"VL": Color("5cc46b"), "L": Color("a5d98f"), "M": Color("c9cbc4"),
	"H": Color("f0a35e"), "VH": Color("e8604f")}
const RATING_HINTS := {
	"Keeper": ["Harder to score", "Easier to score"],
	"Defence": ["Harder to move up and keep the ball", "Easier to move up and keep the ball"],
	"Attack": ["Harder to win the ball back", "Easier to win the ball back"]}

var board: TacticsBoard
var bench_row: HBoxContainer
var status_label: Label
var message_label: Label
var busy := false                ## true while a name is being rubbed out or written in

func _ready() -> void:
	RunState.tidy_picked()       ## drop anyone sold or out of games before showing the team

	var background := ColorRect.new()
	background.color = BACKGROUND
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", GAP)
	margin.add_child(page)

	page.add_child(_header())

	## The whiteboard on the left, the scouting report and dugout on the right.
	var main := HBoxContainer.new()
	main.add_theme_constant_override("separation", 28)
	page.add_child(main)
	board = TacticsBoard.new()
	board.magnet_clicked.connect(_on_player_clicked)
	main.add_child(board)
	board.show_notes(BoardNotes.pick())      ## picked once, so the notes don't change as you click
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 14)
	main.add_child(side)
	side.add_child(_scouting_report())
	side.add_child(_dugout())

	## The bench: a heading (with a message line), then the strip of cards.
	var bench_heading := HBoxContainer.new()
	bench_heading.add_theme_constant_override("separation", 20)
	bench_heading.add_child(_label("BENCH", 22, GREY))
	bench_heading.add_child(_label("Click a player to bring him on", 20, SOFT))
	message_label = _label("", 20, GOLD)
	bench_heading.add_child(message_label)
	page.add_child(bench_heading)
	var strip := _panel(BENCH_WOOD, BENCH_WOOD, 12)
	page.add_child(strip)
	bench_row = HBoxContainer.new()
	bench_row.add_theme_constant_override("separation", GAP)
	strip.add_child(bench_row)

	## Push the buttons to the bottom right.
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(spacer)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 20)
	page.add_child(buttons)
	var back := _button("Back to hub", _back_to_hub)
	UiStyle.secondary(back)
	buttons.add_child(back)
	var kick_off := _button("Kick off", _kick_off)
	UiStyle.primary(kick_off)
	buttons.add_child(kick_off)

	_show_team()

# ---------- Header ----------

func _header() -> HBoxContainer:
	var header := HBoxContainer.new()
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(_label("TEAM SHEET  ·  %s  ·  ROUND %d OF %d" % [
			LeagueState.current_tournament_name().to_upper(), LeagueState.matches_played + 1,
			LeagueState.matches_per_season()], 20, GREY))
	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", 18)
	var them := LeagueState.next_opponent()
	title.add_child(_label("vs " + (them.team_name if them != null else "nobody"), 52, WHITE))
	if them != null and them.is_favourite:
		var tag := _panel(RED, RED, 8)
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tag.add_child(_label("★ FAVOURITES", 20, Color.WHITE))
		title.add_child(tag)
	left.add_child(title)
	header.add_child(left)
	status_label = _label("", 22, GREY)
	status_label.size_flags_vertical = Control.SIZE_SHRINK_END
	header.add_child(status_label)
	return header

## "2nd  ·  1 pt off top  ·  2 / 3 picked"
func _status_text() -> String:
	var parts: PackedStringArray = []
	if LeagueState.matches_played > 0:
		parts.append(_ordinal(LeagueState.position_of(LeagueState.YOU)))
		var off := BoardNotes.points_off_top()
		if off > 0:
			parts.append(("1 pt" if off == 1 else "%d pts" % off) + " off top")
	parts.append("%d / %d picked" % [RunState.match_players().size(), RunState.MATCHDAY_PLAYERS])
	return "  ·  ".join(parts)

# ---------- Your team ----------

## Rebuild the board's team and the bench from RunState.picked.
func _show_team() -> void:
	var starters := RunState.match_players()
	board.show_team(starters, RunState.MATCHDAY_PLAYERS)
	for child in bench_row.get_children():
		child.queue_free()
	var bench := RunState.players().filter(func(p): return not starters.has(p))
	for p in bench:
		_add_bench_card(p)
	for i in RunState.MAX_PLAYERS - starters.size() - bench.size():
		bench_row.add_child(_empty_place())
	status_label.text = _status_text()

func _add_bench_card(p: PlayerCard) -> void:
	var ui = PLAYER_UI.instantiate()
	bench_row.add_child(ui)               ## add first: the tile's _ready sets its own size
	ui.setup(p)
	ui.modulate = Color.WHITE             ## setup tints players gold; the bench uses card colours
	ui.custom_minimum_size = TILE_SIZE
	ui.focus_mode = Control.FOCUS_NONE
	ui.add_theme_font_size_override("font_size", TILE_FONT)
	var left := LeagueState.appearances_left(p)
	if left == 0:
		ui.text += "\nRESTED: no games left"
		ui.disabled = true
		_card_look(ui, RESTED_CARD, RESTED_TEXT)
	else:
		ui.text += "\nGames left: %d / %d" % [left, p.max_appearances()]
		_card_look(ui, BENCH_CARD, BENCH_TEXT)
	ui.player_clicked.connect(_on_player_clicked)

## A free place on the bench (you can own MAX_PLAYERS).
func _empty_place() -> Panel:
	var place := Panel.new()
	place.custom_minimum_size = TILE_SIZE
	var style := _box_style(Color(0, 0, 0, 0), 12)
	style.border_color = RESTED_CARD
	style.set_border_width_all(2)
	place.add_theme_stylebox_override("panel", style)
	return place

## Magnet clicked = take him off (rubbed out). Bench card clicked = bring him on (written in).
func _on_player_clicked(p: StaffCard) -> void:
	if busy:
		return
	if RunState.picked.has(p):
		busy = true
		message_label.text = ""
		await board.erase_starter(p)
		RunState.picked.erase(p)
		_show_team()
		busy = false
	elif RunState.match_players().size() < RunState.MATCHDAY_PLAYERS:
		busy = true
		message_label.text = ""
		RunState.picked.append(p)
		_show_team()
		await board.write_in(p)
		busy = false
	else:
		message_label.text = "Team full: take a starter off first"

# ---------- Scouting report and dugout ----------

func _scouting_report() -> PanelContainer:
	var panel := _panel(PANEL, PANEL_EDGE, 16)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(_label("SCOUTING REPORT", 18, GREY))
	var them := LeagueState.next_opponent()
	if them == null:
		return panel
	box.add_child(_rating_row("Keeper", them.keeper))
	box.add_child(_rating_row("Defence", them.defence))
	box.add_child(_rating_row("Attack", them.attack))
	var strength := HBoxContainer.new()
	var title := _label("STRENGTH (LEAGUE LEVEL)", 18, GREY)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strength.add_child(title)
	strength.add_child(_label(str(LeagueState.opponent_strength()), 32, WHITE))
	box.add_child(strength)
	if them.is_favourite and them.effect_text != "":
		var boss := _panel(Color("3a1a16"), RED, 8)
		var text := _label("★ Boss effect: " + them.effect_text, 16, Color("f3c9c3"))
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		boss.add_child(text)
		box.add_child(boss)
	return panel

## "KEEPER ........ High", a 5-segment bar, then what it means for you.
func _rating_row(title: String, value: float) -> VBoxContainer:
	var short := OpponentTeam.rating_short(value)
	var colour: Color = RATING_COLOURS.get(short, WHITE)
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	var top := HBoxContainer.new()
	var name_label := _label(title.to_upper(), 18, GREY)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	top.add_child(_label(OpponentTeam.rating_word(value), 24, colour))
	row.add_child(top)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	var filled := RATING_STEPS.find(short) + 1
	for i in RATING_STEPS.size():
		var segment := Panel.new()
		segment.custom_minimum_size.y = 10
		segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		segment.add_theme_stylebox_override("panel", _box_style(colour if i < filled else PANEL_EDGE, 3))
		bar.add_child(segment)
	row.add_child(bar)
	row.add_child(_label(_rating_hint(title, value), 15, GREY))
	return row

func _rating_hint(title: String, value: float) -> String:
	if value > 1.0 and not is_equal_approx(value, 1.0):
		return RATING_HINTS[title][0]
	if value < 1.0 and not is_equal_approx(value, 1.0):
		return RATING_HINTS[title][1]
	return "About average"

func _dugout() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(_label("DUGOUT  ·  COACHES ALWAYS PLAY", 18, GREY))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	if RunState.coaches().is_empty():
		row.add_child(_label("No coaches yet.", 16, SOFT))
	for c in RunState.coaches():
		var card := _panel(COACH_FILL, COACH_EDGE, 10)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var words := VBoxContainer.new()
		card.add_child(words)
		words.add_child(_label(c.display_name.to_upper(), 20, Color("cfe2ff")))
		var text := _label(c.description, 15, Color("a9c3e8"))
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.add_child(text)
		row.add_child(card)
	return box

# ---------- Helpers ----------

func _box_style(fill: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(radius)
	return style

## A rounded panel with a 1px edge and `padding` inside.
func _panel(fill: Color, edge: Color, padding: int) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := _box_style(fill, 12)
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_content_margin_all(padding)
	panel.add_theme_stylebox_override("panel", style)
	return panel

## Bench card colours for every button state (hover a touch lighter).
func _card_look(ui: Button, fill: Color, text: Color) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := _box_style(fill.lightened(0.08) if state == "hover" else fill, 12)
		style.set_content_margin_all(10)
		ui.add_theme_stylebox_override(state, style)
	for colour_name in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		ui.add_theme_color_override(colour_name, text)

func _label(text: String, font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	return label

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(280, 64)
	button.pressed.connect(action)
	return button

func _ordinal(n: int) -> String:
	match n:
		1: return "1st"
		2: return "2nd"
		3: return "3rd"
	return "%dth" % n

func _kick_off() -> void:
	get_tree().change_scene_to_file("res://Scenes/match_screen.tscn")

func _back_to_hub() -> void:
	get_tree().change_scene_to_file("res://Scenes/hub_screen.tscn")
