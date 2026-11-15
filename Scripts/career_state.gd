extends Node

## Autoload singleton. Register as "CareerState" in Project Settings > Autoload.
## Persists across runs. This is where permanent meta-progression lives.

signal run_ended(reached_tournament_index: int, won_all_tournaments: bool)

var current_stake_index: int = 0
var best_tournament_ever_reached: int = 0
var total_runs_completed: int = 0
var has_won_all_tournaments: bool = false

func start_new_run() -> void:
	LeagueState.current_tournament_index = 0
	LeagueState.reset_for_new_tournament()

## Call once when a run finishes. won_all = finished top of the final tournament.
func end_run(won_all: bool) -> void:
	var reached := LeagueState.current_tournament_index
	if reached > best_tournament_ever_reached:
		best_tournament_ever_reached = reached
	if won_all:
		has_won_all_tournaments = true
	total_runs_completed += 1
	run_ended.emit(reached, won_all)
