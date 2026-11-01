class_name KitchenSinkAbility
extends Ability
## Kitchen Sink: everyone forward. Their press is much weaker, but nobody defends.

## Fraction of their normal press. The default 1.0 does nothing on purpose:
## type the real value in the Inspector so it's always saved in the file.
@export var press_factor: float = 1.0

func press_multiplier(_m: MatchRules) -> float:
	return press_factor

func no_defence(_m: MatchRules) -> bool:
	return true
