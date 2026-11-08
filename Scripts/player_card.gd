@tool
class_name PlayerCard
extends StaffCard
## Players change the numbers: all the +bonuses first, then all the ×multipliers.

@export var bonus: int = 0
@export var multiplier: float = 1.0
## Games this player can play per season. 0 = use DEFAULT_APPEARANCES
## (the dial that moves every ordinary player at once).
const DEFAULT_APPEARANCES := 3
@export var appearances: int = 0

func max_appearances() -> int:
	return appearances if appearances > 0 else DEFAULT_APPEARANCES


func bonus_for(card: ActionCard) -> int:
	return bonus if applies_to(card) else 0

func affects(card: ActionCard) -> bool:
	return applies_to(card) and (bonus != 0 or multiplier != 1.0)

## e.g. "+10", "×2" or "+10 ×1.5"
func effect_label() -> String:
	var parts: PackedStringArray = []
	if bonus != 0:
		parts.append("+%d" % bonus)
	if multiplier != 1.0:
		parts.append("×" + String.num(multiplier))
	return " ".join(parts)
