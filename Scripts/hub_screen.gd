extends Control
## The manager hub between matches: who you are, the next match, the league table,
## your fixtures, and the way into the next match or the shop.
## Everything is built in code; the scene is just this root node.

const LEAGUE_TABLE := preload("res://Scenes/league_table_view.tscn")
const FIXTURES_VIEW := preload("res://Scenes/fixtures_view.tscn")
const BACKGROUND := Color("16231c")         ## dark pitch green
const GOLD := Color("f2c14e")
const GREY := Color(0.65, 0.65, 0.65)

func _ready() -> void:
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
	page.add_theme_constant_override("separation", 30)
	margin.add_child(page)

	## Header: your team, then league / round / coins.
	page.add_child(_label(LeagueState.your_name(), 44, GOLD))
	page.add_child(_label("%s   |   Round %d of %d   |   Coins: %d" % [
			LeagueState.current_tournament_name(), LeagueState.matches_played + 1,
			LeagueState.matches_per_season(), CoinState.coins], 24, GREY))

	## Next match: its own band across the top, so the two columns below line up.
	var next_match := VBoxContainer.new()
	next_match.add_child(_label("NEXT MATCH", 24, GREY))
	next_match.add_child(_label("vs %s     Strength %d" % [
			LeagueState.next_opponent_label(), LeagueState.opponent_strength()], 32, Color.WHITE))
	page.add_child(next_match)

	## Two columns that start the same way (title, heading row, rows), so rows line up:
	## the table on the left, your fixtures on the right.
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 80)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(columns)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(_label("LEAGUE TABLE", 24, GREY))
	left.add_child(LEAGUE_TABLE.instantiate())
	columns.add_child(left)

	var fixtures = FIXTURES_VIEW.instantiate()   ## has its own "YOUR FIXTURES" title
	fixtures.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(fixtures)

	## Buttons along the bottom.
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 24)
	page.add_child(buttons)
	var play := _button("Play next match", _play_next_match)
	UiStyle.primary(play)
	buttons.add_child(play)
	var shop := _button("Shop", _open_shop)
	UiStyle.secondary(shop)
	buttons.add_child(shop)

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

func _play_next_match() -> void:
	get_tree().change_scene_to_file("res://Scenes/match_screen.tscn")

func _open_shop() -> void:
	get_tree().change_scene_to_file("res://Scenes/shop_screen.tscn")
