class_name DiceBoostEffect
extends ConsumableEffect

## Boosts the player's next attacking roll to use a bigger die for one shot
## (e.g. d30 instead of the standard d20). Reused by any card that wants
## this mechanic — only dice_sides needs to differ between cards.

@export var dice_sides: int = 30

func apply(match_logic: MatchLogic) -> void:
	match_logic.apply_player_dice_boost(dice_sides)
