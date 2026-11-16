class_name PenaltySaverAbility
extends Ability
## Penalty saving: your keeper saves more of THEIR penalties.
## Use save_percent for a keeper ("saves 50%"), save_bonus for a helper ("+5% saves").
## Both can be used together: the % is set first, then the bonus is added.

## Your keeper saves this % of their penalties (normally 11%). -1 = leave it as it is.
@export var save_percent: int = -1
## Extra % saves on top of whatever the save % is. 0 = no effect.
@export var save_bonus: int = 0

func penalty_save_percent(_m: MatchRules) -> int:
	return save_percent

func penalty_save_bonus(_m: MatchRules) -> int:
	return save_bonus
