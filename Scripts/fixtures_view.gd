extends VBoxContainer
## Your season: results so far (W/D/L), fixtures still to come (next in gold),
## each opponent's ratings (GK / DEF / ATT), a star for the favourites,
## and the favourites' ability underneath.
## Call refresh() to redraw it, or refresh(list) to show a saved list.

const HEADING_COLOUR := Color(0.65, 0.65, 0.65)
const WIN_COLOUR := Color("6cc46c")
const DRAW_COLOUR := Color(0.85, 0.85, 0.85)
const LOSS_COLOUR := Color("e07a6a")
const UPCOMING_COLOUR := Color(0.65, 0.65, 0.65)
const NEXT_COLOUR := Color("f2c14e")
const FAVOURITE_COLOUR := Color("e07a6a")    ## same red as the favourites in the table
const FAVOURITE_MARK := "★"                  ## shown in the last column for the favourites
const FAVOURITE_MARK_COLOUR := Color("f2c14e")
const SMALL_COLUMN_WIDTH := 56
const OPPONENT_COLUMN := 3                   ## round, W/D/L, score, OPPONENT, GK, DEF, ATT, star
const HEADINGS := ["", "", "", "", "GK", "DEF", "ATT", "FAV"]

func _ready() -> void:
	refresh()

func refresh(list: Array = []) -> void:
	if list.is_empty():
		list = LeagueState.your_fixtures()
	for child in get_children():          ## clear the old version
		remove_child(child)
		child.queue_free()

	var title := Label.new()
	title.text = "YOUR FIXTURES"
	title.add_theme_color_override("font_color", HEADING_COLOUR)
	add_child(title)

	var grid := GridContainer.new()
	grid.columns = HEADINGS.size()
	grid.add_theme_constant_override("h_separation", 14)
	add_child(grid)
	_add_row(grid, HEADINGS, HEADING_COLOUR)

	var next_shown := false
	for f in list:
		var team: OpponentTeam = f["team"]
		var ratings := [OpponentTeam.rating_short(team.keeper),
				OpponentTeam.rating_short(team.defence), OpponentTeam.rating_short(team.attack),
				FAVOURITE_MARK if team.is_favourite else ""]
		if f["played"]:
			var letter := "D"
			var colour := DRAW_COLOUR
			if f["scored"] > f["conceded"]:
				letter = "W"
				colour = WIN_COLOUR
			elif f["scored"] < f["conceded"]:
				letter = "L"
				colour = LOSS_COLOUR
			_add_row(grid, ["R%d" % f["round"], letter,
					"%d - %d" % [f["scored"], f["conceded"]], team.team_name] + ratings, colour)
		else:
			var marker := ""
			var colour := UPCOMING_COLOUR
			if not next_shown:             ## the first unplayed round is the next match
				next_shown = true
				marker = "Next"
				colour = NEXT_COLOUR
			_add_row(grid, ["R%d" % f["round"], marker, "v", team.team_name] + ratings, colour)
		if team.is_favourite:              ## the star is the last cell of this row: make it gold
			var star: Label = grid.get_child(grid.get_child_count() - 1)
			star.add_theme_color_override("font_color", FAVOURITE_MARK_COLOUR)

	## The favourites' ability (description only for now).
	for f in list:
		var team: OpponentTeam = f["team"]
		if team.is_favourite and team.effect_text != "":
			var effect := Label.new()
			effect.text = "%s %s (R%d): %s" % [FAVOURITE_MARK, team.team_name, f["round"], team.effect_text]
			effect.add_theme_color_override("font_color", FAVOURITE_COLOUR)
			effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   ## long abilities wrap
			add_child(effect)

func _add_row(grid: GridContainer, cells: Array, colour: Color) -> void:
	for i in cells.size():
		var cell := Label.new()
		cell.text = cells[i]
		cell.add_theme_color_override("font_color", colour)
		if i == OPPONENT_COLUMN:           ## opponent column takes the spare width
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			cell.custom_minimum_size.x = SMALL_COLUMN_WIDTH
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(cell)
