class_name ParkTheBusAbility
extends Ability
## Park the Bus: everyone behind the ball. Much easier to win it back,
## but with the ball the only thing you can do is try a Long Shot.

## Fraction of the normal hold target. The default 1.0 does nothing on purpose:
## type the real value in the Inspector so it's always saved in the file.
@export var hold_factor: float = 1.0

func hold_multiplier(_m: MatchRules) -> float:
	return hold_factor

func allows_card(_m: MatchRules, card: ActionCard) -> bool:
	if card.card_type != "attacking":
		return true                     ## moves, utility and defending cards still work
	return card.tag == "long_shot"      ## attacking cards: only Long Shot
