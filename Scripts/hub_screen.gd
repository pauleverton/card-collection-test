extends Control
## The hub: "the week" between matches. The league table and your fixtures on the left;
## on the right, this week's choice as two big buttons:
##   TRAIN (pay, then do this week's one activity at the training ground, then back here)
##   REST & GO TO MATCH (free: a random player who has played gets +1 game this season)
## After training, the bottom button just says "Go to match". The team sheet has no way back.
## Everything is built in code; the scene is just this root node.

const LEAGUE_TABLE := preload("res://Scenes/league_table_view.tscn")
const FIXTURES_VIEW := preload("res://Scenes/fixtures_view.tscn")
const TRAINING_SCENE := "res://Scenes/training_ground_screen.tscn"
const TEAM_SHEET_SCENE := "res://Scenes/team_sheet_screen.tscn"
const BACKGROUND := Color("0f1a14")
const GOLD := Color("f2c14e")
const GREY := Color("9fb09f")
const WHITE := Color("edefe9")
const WARN := Color("e8a05e")
const PANEL := Color("16261b")
const PANEL_EDGE := Color("2b4232")
const TRAIN_FILL := Color("1b3524")
const TRAIN_EDGE := Color("3e6b4a")
const REST_FILL := Color("142338")
const REST_EDGE := Color("7fb3ff")
const REST_TEXT := Color("a9c3e8")
const DISABLED := Color(1, 1, 1, 0.5)
const ACTIVITIES := {
	"new_card": ["New card", "Pick one of %d new cards for your deck." % RunState.TRAINING_NEW_CARDS],
	"upgrade": ["Upgrade a card", "Pick one card in your deck and improve it."],
	"cut": ["Remove a card", "Take one card out of your deck for good."],
	"duplicate": ["Duplicate a card", "Pick one card in your deck and add a copy."]}

func _ready() -> void:
	var background := ColorRect.new()
	background.color = BACKGROUND
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 56)
	margin.add_theme_constant_override("margin_right", 56)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 24)
	margin.add_child(page)

	## Header: league and week, your team, the next opponent, coins.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 24)
	page.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_child(_label("%s  ·  WEEK %d OF %d" % [LeagueState.current_tournament_name().to_upper(),
			LeagueState.matches_played + 1, LeagueState.matches_per_season()], 20, GREY))
	titles.add_child(_label(LeagueState.your_name().to_upper(), 56, GOLD))
	header.add_child(titles)
	var next := _label("NEXT:  " + LeagueState.next_opponent_label(), 24, WHITE)
	next.size_flags_vertical = Control.SIZE_SHRINK_END
	header.add_child(next)
	var coins := _panel(Color("1e2a22"), GOLD, 2, 10)
	coins.size_flags_vertical = Control.SIZE_SHRINK_END
	coins.add_child(_label("%d coins" % CoinState.coins, 32, GOLD))
	header.add_child(coins)

	var main := HBoxContainer.new()
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 40)
	page.add_child(main)

	## Left: the league table and your fixtures.
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 760
	left.add_theme_constant_override("separation", 22)
	main.add_child(left)
	var table_panel := _panel(PANEL, PANEL_EDGE, 1, 18)
	table_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var table_box := VBoxContainer.new()
	table_box.add_theme_constant_override("separation", 10)
	table_box.add_child(_label("LEAGUE TABLE", 20, GREY))
	table_box.add_child(LEAGUE_TABLE.instantiate())
	table_panel.add_child(table_box)
	left.add_child(table_panel)
	var fixtures_panel := _panel(PANEL, PANEL_EDGE, 1, 18)
	fixtures_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fixtures_panel.add_child(FIXTURES_VIEW.instantiate())    ## has its own "YOUR FIXTURES" title
	left.add_child(fixtures_panel)

	## Right: this week, as two big buttons sharing the height.
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 20)
	main.add_child(right)
	right.add_child(_train_button())
	right.add_child(_match_button())

## Top: go to training (activity, what it does, cost) — or "trained" once done.
func _train_button() -> Button:
	var info: Array = ACTIVITIES.get(RunState.training_activity, ["Training", ""])
	var trained := RunState.week_choice == "train"
	var button := _big_button(TRAIN_FILL, TRAIN_EDGE)
	var box := _inner(button)
	if trained:
		box.add_child(_label("TRAINED THIS WEEK", 20, GREY))
		box.add_child(_label(info[0].to_upper() + "  ✓", 52, WHITE))
		button.disabled = true
	else:
		box.add_child(_label("GO TO TRAINING", 20, GREY))
		box.add_child(_label(info[0].to_upper(), 56, WHITE))
		box.add_child(_label(info[1], 20, Color("b9c4b8")))
		box.add_child(_spacer())
		box.add_child(_label("%d coins" % RunState.TRAINING_COST, 40, GOLD))
		var reason := RunState.training_blocked_reason()
		if reason == "" and not CoinState.can_afford(RunState.TRAINING_COST):
			reason = "Not enough coins to train."
		if reason != "":
			box.add_child(_label(reason, 20, WARN))
			button.disabled = true
		button.pressed.connect(_train)
	if button.disabled:
		button.modulate = DISABLED
	_ignore_mouse(button)
	return button

## Bottom: rest and go to the match — or just "Go to match" after training.
func _match_button() -> Button:
	var button := _big_button(REST_FILL, REST_EDGE)
	var box := _inner(button)
	if RunState.week_choice == "train":
		box.add_child(_label("NEXT: TEAM SHEET", 20, REST_TEXT))
		box.add_child(_label("GO TO MATCH", 56, WHITE))
		box.add_child(_label("vs " + LeagueState.next_opponent_label(), 22, REST_TEXT))
	else:
		box.add_child(_label("SKIP TRAINING", 20, REST_TEXT))
		box.add_child(_label("REST & GO TO MATCH", 56, WHITE))
		box.add_child(_label("Rest day: a random player who's played this season gets +1 game.", 20, REST_TEXT))
	button.pressed.connect(_to_team_sheet)
	_ignore_mouse(button)
	return button

func _train() -> void:
	CoinState.deduct_coins(RunState.TRAINING_COST)
	RunState.week_choice = "train"
	get_tree().change_scene_to_file(TRAINING_SCENE)

## Off to the team sheet (no way back). If you didn't train this week, it's a rest day.
func _to_team_sheet() -> void:
	if RunState.week_choice == "":
		RunState.week_choice = "rest"
		var p := RunState.rest_day()
		if p != null:
			RunState.rest_message = "Rest day: %s +1 game" % p.display_name
		else:
			RunState.rest_message = "Rest day: everyone's fresh"
	get_tree().change_scene_to_file(TEAM_SHEET_SCENE)

# ---------- Helpers ----------

## A big button that shares the column's height with the other one.
func _big_button(fill: Color, edge: Color) -> Button:
	var button := Button.new()
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = fill.lightened(0.08) if state == "hover" else fill
		style.border_color = GOLD if state == "hover" else edge
		style.set_border_width_all(3 if state == "hover" else 2)
		style.set_corner_radius_all(14)
		button.add_theme_stylebox_override(state, style)
	return button

## A padded column inside a big button.
func _inner(button: Button) -> VBoxContainer:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	button.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	return box

func _spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return spacer

func _panel(fill: Color, edge: Color, edge_width: int, padding: int) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(edge_width)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(padding)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _label(text: String, font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	return label

## Clicks go to the button, not the pieces inside it.
func _ignore_mouse(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_mouse(child)
