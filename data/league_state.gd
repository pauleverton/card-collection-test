extends Node

## Autoload singleton. Register as "LeagueState" in Project Settings > Autoload.
## Tracks progress through the CURRENT tournament, within the current run.
## current_tournament_index is run-scoped — reset via CareerState.start_new_run(),
## never touched directly by a season ending on its own.
##
## Promotion model: every tournament is MATCHES_PER_SEASON matches long.
## Earn league points as you go (win/draw/loss), same as a real table. Once
## the season's matches are used up, hit that season's promotion_target()
## or better and you're promoted to the next tournament, points reset for
## the new one. Fall short and the run ends (see CareerState.end_run()).

signal season_complete(final_points: int, promoted: bool)

const POINTS_WIN := 3
const POINTS_DRAW := 1
const POINTS_LOSS := 0

const MATCHES_PER_SEASON := 4

## Points needed for promotion out of tournament index 0. Each tournament
## after that needs one more point than the last (6, 7, 8, ...) — see
## promotion_target().
const BASE_PROMOTION_POINTS := 6

## Placeholder names — adjust freely. boss_rarity is reserved for a future
## "toughest opponent of the season" feature; not used by any promotion
## logic here, promotion is purely points-based now.
const TOURNAMENTS := [
	{"name": "Non-League",       "type": "league", "boss_rarity": "bronze"},
	{"name": "League Two",       "type": "league", "boss_rarity": "bronze"},
	{"name": "League One",       "type": "league", "boss_rarity": "silver"},
	{"name": "Championship",     "type": "league", "boss_rarity": "silver"},
	{"name": "Premier League",   "type": "league", "boss_rarity": "gold"},
	{"name": "Europa League",    "type": "cup",    "boss_rarity": "gold"},
	{"name": "Champions League", "type": "cup",    "boss_rarity": "gold"},
	{"name": "World Cup",        "type": "cup",    "boss_rarity": "gold"},
]

var current_tournament_index: int = 0   # run-scoped, NOT reset by reset_for_new_tournament()
var season_points: int = 0              # resets each new tournament
var matches_played: int = 0             # resets each new tournament

## This season's decider-match opponent, picked randomly the moment a new
## season starts (see _resolve_season()). Null for tournament index 0 —
## there's no "previous season won" yet to reveal one for.
var current_season_boss: BossTeam = null

## True once the player has seen the Season Prediction screen for the
## CURRENT season. Starts true so season 1 doesn't try to show a reveal
## before any season has actually been won — see locker_room.gd, which
## redirects to the prediction scene while this is false.
var season_prediction_shown: bool = true


func current_tournament() -> Dictionary:
	return TOURNAMENTS[current_tournament_index]


func current_tournament_name() -> String:
	return current_tournament().name


func matches_remaining() -> int:
	return max(0, MATCHES_PER_SEASON - matches_played)


func is_final_tournament() -> bool:
	return current_tournament_index >= TOURNAMENTS.size() - 1


## Points needed to be promoted out of the CURRENT tournament — gets one
## point harder each successive tournament (6, 7, 8, ...).
func promotion_target() -> int:
	return BASE_PROMOTION_POINTS + current_tournament_index


## True only before ANY match has been played in the current season — this
## is what gates the transfer market (see locker_room.gd): once it's false,
## the market stays locked until a new season starts.
func is_before_first_match_of_season() -> bool:
	return matches_played == 0


## True when the NEXT match played will be this season's decider — the
## last of MATCHES_PER_SEASON. match_attempt.gd checks this before
## start_match() to decide whether to use current_season_boss's squad and
## conditions instead of the normal random opponent.
func is_last_match_of_season() -> bool:
	return matches_played == MATCHES_PER_SEASON - 1


func mark_season_prediction_shown() -> void:
	season_prediction_shown = true


## Call after every match in the season — win, draw, or loss, doesn't
## matter which, the caller (match_attempt.gd) just passes the score.
## Automatically detects the end of the season (once MATCHES_PER_SEASON
## matches have been played) and resolves promotion/elimination.
##
## Returns a Dictionary: {"season_ended": bool, "promoted": bool, "final_points": int}
## If season_ended is false, promoted/final_points aren't meaningful yet —
## that's the normal case, since a season is MATCHES_PER_SEASON matches long.
func record_match_result(player_goals: int, opponent_goals: int) -> Dictionary:
	if player_goals > opponent_goals:
		season_points += POINTS_WIN
	elif player_goals == opponent_goals:
		season_points += POINTS_DRAW
	else:
		season_points += POINTS_LOSS

	matches_played += 1

	if matches_played < MATCHES_PER_SEASON:
		return {"season_ended": false, "promoted": false, "final_points": season_points}

	return _resolve_season()


func _resolve_season() -> Dictionary:
	var final_points := season_points
	var promoted := final_points >= promotion_target()

	if not promoted:
		season_complete.emit(final_points, false)
		CareerState.end_run()
		return {"season_ended": true, "promoted": false, "final_points": final_points}

	if is_final_tournament():
		# Hit the target in the LAST tournament — run complete, victory.
		season_complete.emit(final_points, true)
		CareerState.end_run()
		return {"season_ended": true, "promoted": true, "final_points": final_points}

	current_tournament_index += 1
	season_complete.emit(final_points, true)
	reset_for_new_tournament()
	current_season_boss = BossRoster.get_random_boss()
	season_prediction_shown = false
	return {"season_ended": true, "promoted": true, "final_points": final_points}


func reset_for_new_tournament() -> void:
	season_points = 0
	matches_played = 0
