extends Node

## Autoload singleton. Register as "LeagueState" in Project Settings > Autoload.
## Tracks the CURRENT season of the run: the 6 teams in it, the fixtures, the table,
## and every result (yours played, the rest simulated).
## current_tournament_index is run-scoped: reset via CareerState.start_new_run().
##
## Promotion: finish TOP of the table. There is no points target; instead the
## favourites chase a points PACE (see _pace), so they usually finish near it and
## you have to beat them to top spot.

const POINTS_WIN := 3
const POINTS_DRAW := 1
const POINTS_LOSS := 0

## You + 5 opponents; everyone plays everyone once = 5 matches.
const TEAMS_PER_LEAGUE := 6
const DEFAULT_MATCHES_PER_SEASON := TEAMS_PER_LEAGUE - 1

## The team sheet numbers these 1–8 in this order. Cups run as 6-team leagues for now.
const TOURNAMENTS := [
	{"name": "Non-League",       "type": "league"},
	{"name": "League Two",       "type": "league"},
	{"name": "League One",       "type": "league"},
	{"name": "Championship",     "type": "league", "strength": 1.5},
	{"name": "Premier League",   "type": "league", "strength": 1.5},
	{"name": "Europa League",    "type": "cup",    "strength": 1.75},
	{"name": "Champions League", "type": "cup",    "strength": 2.0},
	{"name": "World Cup",        "type": "cup",    "strength": 2.0},
]

var current_tournament_index: int = 0   # run-scoped, NOT reset by reset_for_new_tournament()
var matches_played: int = 0             # YOUR matches this season (= rounds played)

## Opponent strength: the first match of a run, and how fast it grows per match at each stake.
const BASE_STRENGTH := 40
const GROWTH_PER_STAKE := [0.06, 0.08, 0.10, 0.12, 0.15]
## Playing the favourites is tougher.
const BOSS_MULTIPLIER := 1.25

## Every opponent, read from the team sheet when the game starts.
const TEAMS_CSV := "res://Resources/data/opponents.csv"
var all_teams: Array[OpponentTeam] = []

# ---------- The season ----------

## Row 0 of the table is always you.
const YOU := 0
const YOUR_NAME := "Your team"

## Your team's name: the one built on the menu, or YOUR_NAME if there isn't one.
func your_name() -> String:
	if RunState.team_name != "":
		return RunState.team_name
	return YOUR_NAME

## One Dictionary per team: name, team (OpponentTeam, null for you), played, won,
## drawn, lost, for, against, points. Index = position in this list, NOT league position.
var table: Array = []
## One entry per round; each round is a list of [home, away] table indexes.
var fixtures: Array = []
## One entry per round played: that round's results (see _record).
var round_results: Array = []

## Games each of your players has played THIS season, keyed by the player's file path
## (so selling and buying a player back doesn't reset their count). Cleared by start_season().
var appearances_used := {}

func appearances_left(p: PlayerCard) -> int:
	return maxi(p.max_appearances() - appearances_used.get(p.resource_path, 0), 0)

func use_appearance(p: PlayerCard) -> void:
	appearances_used[p.resource_path] = appearances_used.get(p.resource_path, 0) + 1
	
## A rest day: give one used game back (never more than his maximum).
func give_appearance(p: PlayerCard) -> void:
	appearances_used[p.resource_path] = maxi(appearances_used.get(p.resource_path, 0) - 1, 0)

## Simulated matches: each side gets SIM_CHANCES chances, each scoring with
## SIM_GOAL_CHANCE × their attack ÷ the other side's defence/keeper.
const SIM_CHANCES := 6
const SIM_GOAL_CHANCE := 0.22
## The simulated matches exaggerate the ratings by this much, so the rest of the table
## still has clear good and bad teams even when RATING_SPREAD is tight.
## 1.5 with a spread of 0.1 = steps of 0.15 (exactly how the sim played before).
const SIM_STRETCH := 1.5

## Favourites' points pace for a season: 9 in league 1, +1 per league after.
const FAVOURITE_PACE_BASE := 9
## How much better/worse the favourites play when behind/ahead of their pace.
const PACE_BEHIND := 1.25
const PACE_AHEAD := 0.85

func _ready() -> void:
	all_teams = OpponentTeam.load_all(TEAMS_CSV)
	start_season()

## Pick this season's 5 opponents (one favourite + four others from the teams
## allowed in this league), make the fixtures and clear the table.
func start_season() -> void:
	matches_played = 0
	round_results.clear()
	appearances_used.clear()
	var league := current_tournament_index + 1          ## the sheet numbers leagues from 1
	var eligible := all_teams.filter(func(t): return t.can_play_in(league))
	var favourites := eligible.filter(func(t): return t.is_favourite)
	var others := eligible.filter(func(t): return not t.is_favourite)
	favourites.shuffle()
	others.shuffle()
	var opponents := favourites.slice(0, 1)
	opponents += others.slice(0, TEAMS_PER_LEAGUE - 1 - opponents.size())

	table.clear()
	table.append(_new_row(your_name(), null))
	for t in opponents:
		table.append(_new_row(t.team_name, t))
	if table.size() != TEAMS_PER_LEAGUE:
		push_error("LeagueState: only %d teams can play in league %d" % [table.size(), league])
	fixtures = _make_fixtures(table.size())
	if OS.is_debug_build():
		_print_season()

func _new_row(team_name: String, team: OpponentTeam) -> Dictionary:
	return {"name": team_name, "team": team, "played": 0, "won": 0, "drawn": 0,
			"lost": 0, "for": 0, "against": 0, "points": 0}

## Everyone plays everyone once (the "circle method"): keep the first team still,
## rotate the others one place each round.
func _make_fixtures(team_count: int) -> Array:
	var order := range(team_count)          ## [0, 1, 2, 3, 4, 5]
	var rounds := []
	for r in team_count - 1:
		var this_round := []
		for i in int(team_count / 2.0):
			this_round.append([order[i], order[team_count - 1 - i]])
		rounds.append(this_round)
		order.insert(1, order.pop_back())
	rounds.shuffle()                        ## so the favourites can be any round
	return rounds

func _print_season() -> void:
	print("New season: %s" % current_tournament_name())
	for r in fixtures.size():
		print("  Round %d: you vs %s" % [r + 1, _label(_your_opponent_index(r))])

# ---------- Questions the screens ask ----------

func current_tournament() -> Dictionary:
	return TOURNAMENTS[current_tournament_index]

func current_tournament_name() -> String:
	return current_tournament().name

func matches_per_season() -> int:
	return fixtures.size()

func matches_remaining() -> int:
	return max(0, matches_per_season() - matches_played)

func is_final_tournament() -> bool:
	return current_tournament_index >= TOURNAMENTS.size() - 1

func your_points() -> int:
	return table[YOU]["points"]

## The team you play next (null once the season is over).
func next_opponent() -> OpponentTeam:
	var i := _your_opponent_index(matches_played)
	if i < 0:
		return null
	return table[i]["team"]

## "Hangover Rovers", or "Cold Wet Tuesday Athletic (favourites)".
func next_opponent_label() -> String:
	var i := _your_opponent_index(matches_played)
	if i < 0:
		return "nobody"
	return _label(i)
	
## Your season round by round: who you play, and your score once it's played.
## Each entry: {round, opponent (name label), team (OpponentTeam), played, scored, conceded}.
func your_fixtures() -> Array:
	var list := []
	for r in fixtures.size():
		var i := _your_opponent_index(r)
		var f := {"round": r + 1, "opponent": _label(i), "team": table[i]["team"],
				"played": r < round_results.size(), "scored": 0, "conceded": 0}
		if f["played"]:
			for res in round_results[r]:
				if res["yours"]:
					var you_home: bool = res["home_i"] == YOU
					f["scored"] = res["home_goals"] if you_home else res["away_goals"]
					f["conceded"] = res["away_goals"] if you_home else res["home_goals"]
		list.append(f)
	return list

func _label(i: int) -> String:
	var team: OpponentTeam = table[i]["team"]
	if team != null and team.is_favourite:
		return "%s (favourites)" % table[i]["name"]
	return table[i]["name"]

## Which table row you play in this round (-1 if there's no such round).
func _your_opponent_index(round_number: int) -> int:
	if round_number < 0 or round_number >= fixtures.size():
		return -1
	for pair in fixtures[round_number]:
		if pair[0] == YOU:
			return pair[1]
		if pair[1] == YOU:
			return pair[0]
	return -1

## The table sorted into league order.
func standings() -> Array:
	var rows := table.duplicate()
	rows.sort_custom(_is_above)
	return rows

## Points, then goal difference, then goals scored. Still level: you go above
## (head-to-head isn't checked yet).
func _is_above(a: Dictionary, b: Dictionary) -> bool:
	if a["points"] != b["points"]:
		return a["points"] > b["points"]
	var gd_a: int = a["for"] - a["against"]
	var gd_b: int = b["for"] - b["against"]
	if gd_a != gd_b:
		return gd_a > gd_b
	if a["for"] != b["for"]:
		return a["for"] > b["for"]
	return a["team"] == null

## League position (1 = top) of a table row.
func position_of(i: int) -> int:
	var rows := standings()
	for p in rows.size():
		if is_same(rows[p], table[i]):
			return p + 1
	return 0

# ---------- Opponent strength ----------

## Which match of the whole run this is (0 = the first).
func run_match_number() -> int:
	var n := matches_played
	for i in current_tournament_index:
		n += TOURNAMENTS[i].get("matches", DEFAULT_MATCHES_PER_SEASON)
	return n

## How strong the current opponent is. Every zone's target is built from this.
func opponent_strength() -> int:
	var growth: float = GROWTH_PER_STAKE[CareerState.current_stake_index]
	var s := BASE_STRENGTH * pow(1.0 + growth, run_match_number())
	s *= current_tournament().get("strength", 1.0)
	var opponent := next_opponent()
	if opponent != null and opponent.is_favourite:
		s *= BOSS_MULTIPLIER
	return roundi(s)

# ---------- Results ----------

## Call after every match with your score. Records your result, simulates the
## other matches in this round and, after the last round, resolves the season.
## Returns {"season_ended", "promoted", "final_points", "position",
##          "standings" (the table, sorted), "results" (this round's scores),
##          "fixtures" (your season so far, see your_fixtures)}.
## standings/results/fixtures are copied BEFORE a promotion starts the next season.
func record_match_result(player_goals: int, opponent_goals: int) -> Dictionary:
	var results := []
	for pair in fixtures[matches_played]:
		var home: int = pair[0]
		var away: int = pair[1]
		if home == YOU:
			results.append(_record(home, away, player_goals, opponent_goals))
		elif away == YOU:
			results.append(_record(home, away, opponent_goals, player_goals))
		else:
			results.append(_record(home, away, _sim_goals(home, away), _sim_goals(away, home)))
	round_results.append(results)
	matches_played += 1

	var outcome := {"season_ended": false, "promoted": false,
			"final_points": your_points(), "position": position_of(YOU),
			"standings": standings(), "results": results, "fixtures": your_fixtures()}
	if matches_played >= matches_per_season():
		_resolve_season(outcome)
	return outcome

## Add one match to both teams' rows; returns it as a line for the results list.
func _record(home: int, away: int, home_goals: int, away_goals: int) -> Dictionary:
	_add_result(table[home], home_goals, away_goals)
	_add_result(table[away], away_goals, home_goals)
	return {"home": table[home]["name"], "away": table[away]["name"],
			"home_i": home, "away_i": away,
			"home_goals": home_goals, "away_goals": away_goals,
			"yours": home == YOU or away == YOU}

func _add_result(row: Dictionary, scored: int, let_in: int) -> void:
	row["played"] += 1
	row["for"] += scored
	row["against"] += let_in
	if scored > let_in:
		row["won"] += 1
		row["points"] += POINTS_WIN
	elif scored == let_in:
		row["drawn"] += 1
		row["points"] += POINTS_DRAW
	else:
		row["lost"] += 1
		row["points"] += POINTS_LOSS

## Goals `attacker` scores against `defender` in a simulated match.
func _sim_goals(attacker: int, defender: int) -> int:
	var a: OpponentTeam = table[attacker]["team"]
	var d: OpponentTeam = table[defender]["team"]
	var chance := SIM_GOAL_CHANCE * _sim_rating(a.attack) * _pace(attacker) \
			/ ((_sim_rating(d.defence) + _sim_rating(d.keeper)) / 2.0 * _pace(defender))
	chance = clampf(chance, 0.02, 0.8)
	var goals := 0
	for i in SIM_CHANCES:
		if randf() < chance:
			goals += 1
	return goals

## A rating stretched away from Medium for the simulated matches (see SIM_STRETCH).
func _sim_rating(value: float) -> float:
	return 1.0 + (value - 1.0) * SIM_STRETCH

## The favourites play better when behind their pace and ease off when ahead.
## Everyone else just plays to their ratings (1.0).
func _pace(i: int) -> float:
	var team: OpponentTeam = table[i]["team"]
	if team == null or not team.is_favourite:
		return 1.0
	var expected := favourite_pace() * float(table[i]["played"]) / matches_per_season()
	if table[i]["points"] < expected:
		return PACE_BEHIND
	if table[i]["points"] > expected:
		return PACE_AHEAD
	return 1.0

func favourite_pace() -> int:
	return mini(FAVOURITE_PACE_BASE + current_tournament_index, matches_per_season() * POINTS_WIN)

## End of season: 1st goes up (or wins the run in the last tournament); anything else ends the run.
func _resolve_season(outcome: Dictionary) -> void:
	outcome["season_ended"] = true
	outcome["promoted"] = outcome["position"] == 1
	if not outcome["promoted"]:
		CareerState.end_run(false)
		return
	if is_final_tournament():
		CareerState.end_run(true)            ## top of the last one: run won
		return
	current_tournament_index += 1
	reset_for_new_tournament()

func reset_for_new_tournament() -> void:
	start_season()
