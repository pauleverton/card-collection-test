extends Node

## Autoload singleton. Register as "LeagueState" in Project Settings > Autoload.
## Tracks progress through the CURRENT tournament, within the current run.
## current_tournament_index is run-scoped — reset via CareerState.start_new_run(),
## never touched directly by season resets. Losing the boss match at any
## tournament ends the run immediately (see resolve_final_match()).

signal season_complete(final_points: int, promoted: bool)

const POINTS_WIN := 3
const POINTS_DRAW := 1
const POINTS_LOSS := 0

## Placeholder names/lengths — adjust freely. "matches" = regular-season
## games BEFORE the boss match (not including it). boss_rarity feeds
## SquadGenerator.generate_boss_squad().
const TOURNAMENTS := [
	{"name": "Non-League",       "type": "league", "matches": 3, "boss_rarity": "bronze"},
	{"name": "League Two",       "type": "league", "matches": 3, "boss_rarity": "bronze"},
	{"name": "League One",       "type": "league", "matches": 4, "boss_rarity": "silver"},
	{"name": "Championship",     "type": "league", "matches": 4, "boss_rarity": "silver"},
	{"name": "Premier League",   "type": "league", "matches": 5, "boss_rarity": "gold"},
	{"name": "Europa League",    "type": "cup",    "matches": 4, "boss_rarity": "gold"},
	{"name": "Champions League", "type": "cup",    "matches": 5, "boss_rarity": "gold"},
	{"name": "World Cup",        "type": "cup",    "matches": 5, "boss_rarity": "gold"},
]

var current_tournament_index: int = 0   # run-scoped
var season_points: int = 0              # resets each tournament
var matches_played: int = 0             # resets each tournament
var awaiting_final: bool = false        # true once regular matches done, before boss match

func current_tournament() -> Dictionary:
	return TOURNAMENTS[current_tournament_index]

func current_tournament_name() -> String:
	return current_tournament().name

func matches_remaining() -> int:
	return max(0, current_tournament().matches - matches_played)

func is_final_tournament() -> bool:
	return current_tournament_index >= TOURNAMENTS.size() - 1

## Call after every regular-season match (not the boss match).
func record_match_result(player_goals: int, opponent_goals: int) -> void:
	if awaiting_final:
		push_warning("LeagueState: season matches already complete, call resolve_final_match() instead")
		return

	if player_goals > opponent_goals:
		season_points += POINTS_WIN
	elif player_goals == opponent_goals:
		season_points += POINTS_DRAW
	else:
		season_points += POINTS_LOSS

	matches_played += 1
	if matches_played >= current_tournament().matches:
		awaiting_final = true

## Call once the player has completed the end-of-season boss match.
func resolve_final_match(won_against_boss: bool) -> void:
	if not awaiting_final:
		push_warning("LeagueState: no boss match pending")
		return

	if not won_against_boss:
		season_complete.emit(season_points, false)
		CareerState.end_run()
		return

	if is_final_tournament():
		# Won the boss match of the LAST tournament — run complete, victory.
		season_complete.emit(season_points, true)
		CareerState.end_run()
		return

	current_tournament_index += 1
	season_complete.emit(season_points, true)
	reset_for_new_tournament()

func reset_for_new_tournament() -> void:
	season_points = 0
	matches_played = 0
	awaiting_final = false
