@tool
class_name BossRules
extends BossEffect
## The general-purpose boss: every simple effect is a setting here. Set just the one(s)
## you want; the rest stay at "no change". One .tres per boss
## (e.g. no_crosses.tres = Banned Tag "cross", low_energy.tres = Max Energy Limit 3).
## Only a boss that needs real logic gets its own script (extending BossEffect).

@export var banned_tag: String = "none"        ## "none" = no card banned
@export var max_energy_limit: int = 0          ## 0 = no limit
@export var minutes_each_action: int = 0       ## 0 = normal (3)
@export var they_take_every_kick_off := false
@export var they_start_with_goals: int = 0

func allows_card(_m: MatchRules, card: ActionCard) -> bool:
	return banned_tag == "none" or card.tag != banned_tag

func max_energy(_m: MatchRules) -> int:
	return max_energy_limit

func minutes_per_action(_m: MatchRules) -> int:
	return minutes_each_action

func they_kick_off(_m: MatchRules) -> bool:
	return they_take_every_kick_off

func their_starting_goals(_m: MatchRules) -> int:
	return they_start_with_goals

## Turns banned_tag into a dropdown from CardTags (plus "none"), like on the cards.
func _validate_property(property: Dictionary) -> void:
	if property.name == "banned_tag":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(["none"] + CardTags.TAGS)
