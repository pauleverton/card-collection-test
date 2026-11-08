extends Control
## The team sheet, between the hub and the match: who you're playing (big, with their
## ratings) and which of your players start. Click a player to pick or drop them.
## Everything is built in code; the scene is just this root node.

const PLAYER_UI := preload("res://Scenes/player_card_view.tscn")
const BACKGROUND := Color("16231c")         ## dark pitch green (same as the hub)
const GOLD := Color("f2c14e")
const GREY := Color(0.65, 0.65, 0.65)
const RED := Color("e05a4f")
const GREEN := Color("7ccf6a")
const TILE_SIZE := Vector2(240, 130)
## How player tiles look: picked = normal, benched = faded, no games left = greyed out.
const BENCHED_ALPHA := 0.55
const UNAVAILABLE := Color(0.45, 0.45, 0.45, 0.6)
## What each opponent rating makes harder for you.
const RATING_HINTS := {
	"Keeper": "scoring in their box",
	"Defence": "moving up the pitch, and keeping the ball in their box",
	"Attack": "winning the ball back"}

var players_row: HFlowContainer
var count_label: Label

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
	page.add_theme_constant_override("separation", 24)
	margin.add_child(page)

	## The opponent, big.
	var opponent := LeagueState.next_opponent()
	page.add_child(_label("TEAM SHEET   |   %s   |   Round %d of %d" % [
			LeagueState.current_tournament_name(), LeagueState.matches_played + 1,
			LeagueState.matches_per_season()], 24, GREY))
	var favourite := opponent != null and opponent.is_favourite
	page.add_child(_label("vs " + LeagueState.next_opponent_label(), 44, RED if favourite else Color.WHITE))
	if opponent != null:
		var ratings := VBoxContainer.new()
		ratings.add_child(_rating_row("Keeper", opponent.keeper))
		ratings.add_child(_rating_row("Defence", opponent.defence))
		ratings.add_child(_rating_row("Attack", opponent.attack))
		page.add_child(ratings)
		if favourite and opponent.effect_text != "":
			page.add_child(_label("★ " + opponent.effect_text, 24, RED))
	page.add_child(_label("Strength %d" % LeagueState.opponent_strength(), 24, GREY))

	## Your players: click to pick or drop.
	page.add_child(_label("YOUR PLAYERS   (click to pick or drop)", 24, GREY))
	count_label = _label("", 28, GOLD)
	page.add_child(count_label)
	players_row = _tile_row()
	page.add_child(players_row)
	_show_players()

	## Coaches always play, so they're shown but can't be clicked.
	if not RunState.coaches().is_empty():
		page.add_child(_label("COACHES   (always play)", 24, GREY))
		var coach_row := _tile_row()
		page.add_child(coach_row)
		for c in RunState.coaches():
			var ui = PLAYER_UI.instantiate()
			coach_row.add_child(ui)
			ui.setup(c)
			ui.custom_minimum_size = TILE_SIZE
			ui.disabled = true

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

## One tile per player you own, showing whether they're picked and how many games are left.
func _show_players() -> void:
	for child in players_row.get_children():
		child.queue_free()
	var players := RunState.players()
	if players.is_empty():
		players_row.add_child(_label("No players yet: buy some in the shop.", 24, GREY))
	for p in players:
		var ui = PLAYER_UI.instantiate()
		players_row.add_child(ui)
		ui.setup(p)
		ui.custom_minimum_size = TILE_SIZE
		var left := LeagueState.appearances_left(p)
		var games := "Games left: %d / %d" % [left, p.max_appearances()]
		if left == 0:
			ui.text += "\nNo games left this season"
			ui.disabled = true
			ui.modulate = UNAVAILABLE
		elif RunState.picked.has(p):
			ui.text += "\n✓ PICKED   " + games
		else:
			ui.text += "\n" + games
			ui.modulate.a = BENCHED_ALPHA
		ui.player_clicked.connect(_on_player_clicked)
	count_label.text = "Picked %d / %d" % [RunState.match_players().size(), RunState.MATCHDAY_PLAYERS]

func _on_player_clicked(p: StaffCard) -> void:
	if RunState.picked.has(p):
		RunState.picked.erase(p)
	elif RunState.match_players().size() < RunState.MATCHDAY_PLAYERS:
		RunState.picked.append(p)
	else:
		count_label.text = "Team full: drop a picked player first"
		return
	_show_players()

## "Keeper    High    makes scoring in their box harder"
func _rating_row(name: String, value: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	var title := _label(name, 28, GREY)
	title.custom_minimum_size.x = 160
	row.add_child(title)
	var colour := Color.WHITE
	var effect := "about average"
	if value > 1.0 and not is_equal_approx(value, 1.0):
		colour = RED
		effect = "makes %s harder" % RATING_HINTS[name]
	elif value < 1.0 and not is_equal_approx(value, 1.0):
		colour = GREEN
		effect = "makes %s easier" % RATING_HINTS[name]
	var word := _label(OpponentTeam.rating_word(value), 28, colour)
	word.custom_minimum_size.x = 160
	row.add_child(word)
	row.add_child(_label(effect, 22, GREY))
	return row

func _tile_row() -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 16)
	row.add_theme_constant_override("v_separation", 16)
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
