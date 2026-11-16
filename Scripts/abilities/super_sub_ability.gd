class_name SuperSubAbility
extends Ability
## Super Sub: every shot inside their box goes in. Long shots still roll as normal.

func box_shot_always_scores(_m: MatchRules) -> bool:
	return true
