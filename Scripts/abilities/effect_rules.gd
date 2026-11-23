@tool
class_name EffectRules
extends Ability
## The general-purpose effect: every simple effect is a setting here. Used by bosses
## (Resources/boss_effects/) AND in players' and management's Ability slot. Set just the one(s)
## you want; the rest stay at "no change". Only an effect that needs real logic gets its own script.

@export_group("Cards")
@export var banned_tag: String = "none"            ## "none" = no card banned
@export var power_in_your_half: float = 1.0        ## your box + your half (0.5 = half power)
@export var power_in_attacking_half: float = 1.0   ## their half + their box (1.25 = +25%)

@export_group("Energy and clock")
@export var energy_boost: int = 0                  ## extra energy each possession
@export var max_energy_limit: int = 0              ## 0 = no limit
@export var minutes_each_action: int = 0           ## 0 = normal (3)

@export_group("Attacking and defending")
@export var press_target_multiplier: float = 1.0   ## their press when you attack (0.5 = half)
@export var hold_target_multiplier: float = 1.0    ## the hold you need to win it back (0.5 = half)
@export var their_shot_boost: float = 1.0          ## their chance when they shoot (1.5 = ×1.5, 0.9 = -10%)

@export_group("Bosses")
@export var they_take_every_kick_off := false
@export var they_start_with_goals: int = 0
@export_enum("none", "defensive", "coaches") var staff_switched_off: String = "none"
@export var max_players_on_pitch: int = 0          ## 0 = normal; extras dropped at random at kick-off
@export var win_by_at_least: int = 1               ## 2 = anything less than a 2-goal win is a loss

func allows_card(_m: MatchRules, card: ActionCard) -> bool:
	return banned_tag == "none" or card.tag != banned_tag

func power_multiplier(m: MatchRules, _card: ActionCard) -> float:
	if m.zone <= 1:
		return power_in_your_half         ## your box and your half
	if m.zone >= 3:
		return power_in_attacking_half    ## their half and their box
	return 1.0                            ## midfield: no change

func energy_bonus(_m: MatchRules) -> int:
	return energy_boost

func max_energy(_m: MatchRules) -> int:
	return max_energy_limit

func minutes_per_action(_m: MatchRules) -> int:
	return minutes_each_action

func press_multiplier(_m: MatchRules) -> float:
	return press_target_multiplier

func hold_multiplier(_m: MatchRules) -> float:
	return hold_target_multiplier

func their_shot_multiplier(_m: MatchRules) -> float:
	return their_shot_boost

func they_kick_off(_m: MatchRules) -> bool:
	return they_take_every_kick_off

func their_starting_goals(_m: MatchRules) -> int:
	return they_start_with_goals

func staff_counts(_m: MatchRules, staff: StaffCard) -> bool:
	match staff_switched_off:
		"defensive":
			return staff.shown_type() != "defending"   ## whoever shows a defending badge
		"coaches":
			return not staff is CoachCard
	return true

func players_allowed(_m: MatchRules) -> int:
	return max_players_on_pitch

func win_margin(_m: MatchRules) -> int:
	return win_by_at_least

## Turns banned_tag into a dropdown from CardTags (plus "none"), like on the cards.
func _validate_property(property: Dictionary) -> void:
	if property.name == "banned_tag":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(["none"] + CardTags.TAGS)
