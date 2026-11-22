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
@export var their_shot_boost: float = 1.0          ## 1.5 = their chance ×1.5 when they shoot
@export var power_in_your_half: float = 1.0        ## your box + your half (0.5 = half power)
@export var power_in_attacking_half: float = 1.0   ## their half + their box (1.25 = +25%)
@export_enum("none", "defensive", "coaches") var staff_switched_off: String = "none"
@export var max_players_on_pitch: int = 0          ## 0 = normal; extras dropped at random at kick-off

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
	
func their_shot_multiplier(_m: MatchRules) -> float:
	return their_shot_boost

func power_multiplier(m: MatchRules, _card: ActionCard) -> float:
	if m.zone <= 1:
		return power_in_your_half         ## your box and your half
	if m.zone >= 3:
		return power_in_attacking_half    ## their half and their box
	return 1.0                            ## midfield: no change

func staff_counts(_m: MatchRules, staff: StaffCard) -> bool:
	match staff_switched_off:
		"defensive":
			return staff.shown_type() != "defending"   ## whoever shows a defending badge
		"coaches":
			return not staff is CoachCard
	return true

## Turns banned_tag into a dropdown from CardTags (plus "none"), like on the cards.
func _validate_property(property: Dictionary) -> void:
	if property.name == "banned_tag":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(["none"] + CardTags.TAGS)

func players_allowed(_m: MatchRules) -> int:
	return max_players_on_pitch
