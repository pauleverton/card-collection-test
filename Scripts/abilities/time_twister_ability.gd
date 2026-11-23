class_name TimeTwisterAbility
extends Ability
## Time Twister: when winning, each card uses double the minutes (the clock runs down);
## when losing, half (more time to come back).

func minutes_multiplier(m: MatchRules) -> float:
	var diff := m.goals - m.conceded
	if diff > 0:
		return 2.0
	if diff < 0:
		return 0.5
	return 1.0
