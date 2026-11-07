class_name OpponentTeam
extends Resource
## One opponent from the team sheet (Resources/data/opponents.csv).
## Plain data: the league table and match rules read these numbers.

## How far apart the ratings are. Each step away from Medium adds or removes this much:
## 0.1 → Very Low 0.8 / Low 0.9 / Medium 1.0 / High 1.1 / Very High 1.2.
## Bigger = bigger gap between the best and worst teams in a league. 0 = all the same.
const RATING_SPREAD := 0.1

## The sheet's words → a multiplier on the league's strength. Medium = 1.0 = the league average.
const RATING_VALUES := {
	"very low": 1.0 - 2 * RATING_SPREAD,
	"low": 1.0 - RATING_SPREAD,
	"medium": 1.0,
	"high": 1.0 + RATING_SPREAD,
	"very high": 1.0 + 2 * RATING_SPREAD}
	
## Short labels for screens (fixtures list): the same order as RATING_VALUES.
const RATING_SHORT := {
	"very low": "VL", "low": "L", "medium": "M", "high": "H", "very high": "VH"}

## A rating multiplier back to its short label (1.15 → "H").
static func rating_short(value: float) -> String:
	for word in RATING_VALUES:
		if is_equal_approx(RATING_VALUES[word], value):
			return RATING_SHORT[word]
	return "?"

var team_name := ""
var leagues: Array[int] = []     ## 1 = Non-League … 5 = Premier League, 6–8 = cups
var keeper := 1.0
var defence := 1.0
var attack := 1.0
var is_favourite := false        ## the "Boss?" column
var effect_text := ""            ## the "Boss effect" column, shown to the player
var effect_id := ""              ## optional "Effect ID" column (see below)

func can_play_in(league: int) -> bool:
	return league in leagues

## Read every team from the CSV. Columns are found by their heading
## (capitals don't matter), so you can reorder or add columns in the sheet.
static func load_all(path: String) -> Array[OpponentTeam]:
	var teams: Array[OpponentTeam] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("OpponentTeam: can't open %s" % path)
		return teams
	var headings := _clean(file.get_csv_line())
	for i in headings.size():
		headings[i] = headings[i].to_lower()
	while not file.eof_reached():
		var row := _clean(file.get_csv_line())
		if row.size() < 2 or row[0] == "":
			continue                   ## blank line
		var t := OpponentTeam.new()
		t.team_name = row[headings.find("team name")]
		for part in _cell(row, headings, "leagues available").split(","):
			if part.strip_edges().is_valid_int():
				t.leagues.append(part.strip_edges().to_int())
		t.keeper = _rating(_cell(row, headings, "keeper strength"), t.team_name)
		t.defence = _rating(_cell(row, headings, "defensive strength"), t.team_name)
		t.attack = _rating(_cell(row, headings, "attacking strength"), t.team_name)
		t.is_favourite = _cell(row, headings, "boss?").to_lower() in ["yes", "y", "true"]
		t.effect_text = _cell(row, headings, "boss effect")
		t.effect_id = _cell(row, headings, "effect id")
		teams.append(t)
	return teams

## The value in this row under a heading ("" if the column or cell is missing).
static func _cell(row: PackedStringArray, headings: PackedStringArray, heading: String) -> String:
	var i := headings.find(heading)
	if i < 0 or i >= row.size():
		return ""
	return row[i]

## Trim spaces (and the stray line-ending character) off every cell.
static func _clean(line: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for s in line:
		out.append(s.strip_edges())
	return out

static func _rating(word: String, team: String) -> float:
	var key := word.to_lower()
	if not RATING_VALUES.has(key):
		push_warning("OpponentTeam: %s has unknown rating '%s', using Medium" % [team, word])
		return 1.0
	return RATING_VALUES[key]
