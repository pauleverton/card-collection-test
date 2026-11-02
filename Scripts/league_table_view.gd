extends GridContainer
## The league table: TEAM, W, D, L, GF, GA, GD, PTS.
## Builds its own cells. Call refresh() to redraw it, or refresh(rows) to show
## a saved table (the full-time panel passes the table from before a promotion).

const HEADINGS := ["TEAM", "W", "D", "L", "GF", "GA", "GD", "PTS"]
const NUMBER_WIDTH := 48                 ## width of each number column
const HEADING_COLOUR := Color(0.65, 0.65, 0.65)
const YOUR_COLOUR := Color("f2c14e")     ## gold: your row
const FAVOURITE_COLOUR := Color("e07a6a") ## red: the favourites
const NORMAL_COLOUR := Color.WHITE

func _ready() -> void:
	columns = HEADINGS.size()
	add_theme_constant_override("h_separation", 12)
	refresh()

## Redraw the table. With no rows given, shows the current season.
func refresh(rows: Array = []) -> void:
	if rows.is_empty():
		rows = LeagueState.standings()
	for child in get_children():         ## clear the old cells
		remove_child(child)
		child.queue_free()

	for heading in HEADINGS:
		_add_cell(heading, heading == "TEAM", HEADING_COLOUR)

	for i in rows.size():
		var r: Dictionary = rows[i]
		var colour := NORMAL_COLOUR
		var team: OpponentTeam = r["team"]
		if team == null:
			colour = YOUR_COLOUR
		elif team.is_favourite:
			colour = FAVOURITE_COLOUR
		var goal_difference: int = r["for"] - r["against"]
		_add_cell("%d. %s" % [i + 1, r["name"]], true, colour)
		_add_cell(str(r["won"]), false, colour)
		_add_cell(str(r["drawn"]), false, colour)
		_add_cell(str(r["lost"]), false, colour)
		_add_cell(str(r["for"]), false, colour)
		_add_cell(str(r["against"]), false, colour)
		_add_cell("%+d" % goal_difference if goal_difference != 0 else "0", false, colour)
		_add_cell(str(r["points"]), false, colour)

## One cell. The team column stretches; number columns are narrow and centred.
func _add_cell(text: String, is_team_column: bool, colour: Color) -> void:
	var cell := Label.new()
	cell.text = text
	if is_team_column:
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		cell.custom_minimum_size.x = NUMBER_WIDTH
		cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.add_theme_color_override("font_color", colour)
	add_child(cell)
