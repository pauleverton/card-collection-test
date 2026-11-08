extends Control
## The team sheet, between the hub and the match: who you're playing (big, with their
## ratings) and your team. ON THE PITCH = the picked players (plus coaches, who always play);
## BENCH = everyone else. Click a bench player to bring him on, a starter to drop him.
## Everything is built in code; the scene is just this root node.

const PLAYER_UI := preload("res://Scenes/player_card_view.tscn")
const BACKGROUND := Color("16231c")         ## dark pitch green (same as the hub)
const GOLD := Color("f2c14e")
const BLUE := Color("6fa8dc")
const GREY := Color(0.65, 0.65, 0.65)
const RED := Color("e05a4f")
const PAGE_GAP := 16                        ## space between the sections of the page
const TILE_GAP := 16
## 240 wide = a full bench of 7 fits in one row (7 × 240 + 6 × 16 = 1776 of 1800).
const TILE_SIZE := Vector2(240, 150)
## Bench tiles are faded; players with no games left are greyed out.
const BENCHED_ALPHA := 0.55
const UNAVAILABLE := Color(0.45, 0.45, 0.45, 0.6)

## Opponent boxes: fill per rating, from easy (green) to hard (red). Dark text sits on all of them.
const RATING_COLOURS := {
	"VL": Color("5cc46b"), "L": Color("a5d98f"), "M": Color("c9cbc4"),
	"H": Color("f0a35e"), "VH": Color("e8604f")}
const BOX_TEXT := Color("16231c")
const RATING_BOX_SIZE := Vector2(220, 100)
## Font sizes inside a box: small title, big value, small hint.
const BOX_FONTS := [16, 30, 16]
## What each rating means for you: [when it's high, when it's low].
const RATING_HINTS := {
	"Keeper": ["Harder to score", "Easier to score"],
	"Defence": ["Harder to move up and keep the ball", "Easier to move up and keep the ball"],
	"Attack": ["Harder to win the ball back", "Easier to win the ball back"]}

var pitch_row: HBoxContainer
var bench_row: HBoxContainer
var message_label: Label

func _ready() -> void:
	RunState.tidy_picked()       ## drop anyone sold or out of games before showing the team

	var background := ColorRect.new()
	background.color = BACKGROUND
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 60)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", PAGE_GAP)
	margin.add_child(page)

	## The opponent: name, then one coloured box per rating plus strength.
	var opponent := LeagueState.next_opponent()
	page.add_child(_label("TEAM SHEET   |   %s   |   Round %d of %d" % [
			LeagueState.current_tournament_name(), LeagueState.matches_played + 1,
			LeagueState.matches_per_season()], 24, GREY))
	var favourite := opponent != null and opponent.is_favourite
	page.add_child(_label("vs " + LeagueState.next_opponent_label(), 44, RED if favourite else Color.WHITE))
	if opponent != null:
		var ratings := HBoxContainer.new()
		ratings.add_theme_constant_override("separation", TILE_GAP)
		ratings.add_child(_rating_box("Keeper", opponent.keeper))
		ratings.add_child(_rating_box("Defence", opponent.defence))
		ratings.add_child(_rating_box("Attack", opponent.attack))
		ratings.add_child(_box("STRENGTH", str(LeagueState.opponent_strength()),
				"League level", Color("2a3a30"), Color.WHITE))
		page.add_child(ratings)
		if favourite and opponent.effect_text != "":
			page.add_child(_label("★ " + opponent.effect_text, 24, RED))

	## On the pitch: the picked players, then the coaches.
	page.add_child(_label("ON THE PITCH", 24, GREY))
	pitch_row = _tile_row()
	page.add_child(pitch_row)

	## The bench: everyone not picked. The message line sits next to the heading.
	var bench_heading := HBoxContainer.new()
	bench_heading.add_theme_constant_override("separation", 30)
	bench_heading.add_child(_label("BENCH   (click a player to bring him on)", 24, GREY))
	message_label = _label("", 24, GOLD)
	bench_heading.add_child(message_label)
	page.add_child(bench_heading)
	bench_row = _tile_row()
	page.add_child(bench_row)

	_show_team()

	## Push the buttons to the bottom.
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(spacer)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 24)
	page.add_child(buttons)
	var kick_off := _button("Kick off", _kick_off)
	UiStyle.primary(kick_off)
	buttons.add_child(kick_off)
	var back := _button("Back to hub", _back_to_hub)
	UiStyle.secondary(back)
	buttons.add_child(back)

# ---------- Your team ----------

## Rebuild both rows from RunState.picked.
func _show_team() -> void:
	for row in [pitch_row, bench_row]:
		for child in row.get_children():
			child.queue_free()

	## On the pitch: one slot per matchday place, filled in the order picked.
	var starters := RunState.match_players()
	for i in RunState.MATCHDAY_PLAYERS:
		if i < starters.size():
			var ui := _player_tile(starters[i], pitch_row)
			_outline(ui, GOLD)
		else:
			pitch_row.add_child(_empty_slot())

	## Coaches always play: shown after a divider, not clickable.
	if not RunState.coaches().is_empty():
		var divider := ColorRect.new()
		divider.color = GREY
		divider.custom_minimum_size = Vector2(2, 0)
		pitch_row.add_child(divider)
		for c in RunState.coaches():
			var ui = PLAYER_UI.instantiate()
			pitch_row.add_child(ui)
			ui.setup(c)
			ui.custom_minimum_size = TILE_SIZE
			ui.text += "\nCoach: always plays"
			ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_outline(ui, BLUE)

	## The bench: everyone else, faded; no games left = greyed out and can't come on.
	var bench := RunState.players().filter(func(p): return not starters.has(p))
	if RunState.players().is_empty():
		bench_row.add_child(_label("No players yet: buy some in the shop.", 24, GREY))
	elif bench.is_empty():
		bench_row.add_child(_label("Nobody on the bench.", 24, GREY))
	for p in bench:
		var ui := _player_tile(p, bench_row)
		if LeagueState.appearances_left(p) == 0:
			ui.disabled = true
			ui.modulate = UNAVAILABLE
		else:
			ui.modulate.a = BENCHED_ALPHA

## A clickable player tile: name, description, games left this season.
func _player_tile(p: PlayerCard, row: HBoxContainer) -> Button:
	var ui = PLAYER_UI.instantiate()
	row.add_child(ui)
	ui.setup(p)
	ui.custom_minimum_size = TILE_SIZE
	var left := LeagueState.appearances_left(p)
	if left == 0:
		ui.text += "\nNo games left this season"
	else:
		ui.text += "\nGames left: %d / %d" % [left, p.max_appearances()]
	ui.player_clicked.connect(_on_player_clicked)
	return ui

## An open place in the team: outlined, "Pick a player".
func _empty_slot() -> PanelContainer:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = TILE_SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(GREY, 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	slot.add_theme_stylebox_override("panel", style)
	var label := _label("Pick a player", 22, Color(GREY, 0.7))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slot.add_child(label)
	return slot

func _on_player_clicked(p: StaffCard) -> void:
	if RunState.picked.has(p):
		RunState.picked.erase(p)                 ## back to the bench
	elif RunState.match_players().size() < RunState.MATCHDAY_PLAYERS:
		RunState.picked.append(p)                ## onto the pitch
	else:
		message_label.text = "Team full: drop a starter first"
		return
	message_label.text = ""
	_show_team()

## A coloured border round a tile (starters gold, coaches blue).
func _outline(ui: Button, colour: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1f2a22")
	style.border_color = colour
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	for state in ["normal", "hover", "pressed", "focus"]:
		ui.add_theme_stylebox_override(state, style)

# ---------- Opponent boxes ----------

## One coloured box per rating: "KEEPER / Very Low / Easier to score".
func _rating_box(title: String, value: float) -> PanelContainer:
	var hint := "About average"
	if value > 1.0 and not is_equal_approx(value, 1.0):
		hint = RATING_HINTS[title][0]
	elif value < 1.0 and not is_equal_approx(value, 1.0):
		hint = RATING_HINTS[title][1]
	var colour: Color = RATING_COLOURS.get(OpponentTeam.rating_short(value), Color.GRAY)
	return _box(title.to_upper(), OpponentTeam.rating_word(value), hint, colour, BOX_TEXT)

## A filled, rounded box: small title, big value, small hint underneath.
func _box(title: String, value: String, hint: String, fill: Color, text: Color) -> PanelContainer:
	var box := PanelContainer.new()
	box.custom_minimum_size = RATING_BOX_SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(10)
	style.set_content_margin_all(10)
	box.add_theme_stylebox_override("panel", style)
	var inside := VBoxContainer.new()
	inside.alignment = BoxContainer.ALIGNMENT_CENTER
	inside.add_theme_constant_override("separation", 0)
	box.add_child(inside)
	var parts := [title, value, hint]
	for i in parts.size():
		var label := _label(parts[i], BOX_FONTS[i], text)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inside.add_child(label)
	return box

# ---------- Helpers ----------

func _tile_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", TILE_GAP)
	return row

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

func _kick_off() -> void:
	get_tree().change_scene_to_file("res://Scenes/match_screen.tscn")

func _back_to_hub() -> void:
	get_tree().change_scene_to_file("res://Scenes/hub_screen.tscn")
