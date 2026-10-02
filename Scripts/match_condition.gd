class_name MatchCondition
extends Resource

## Describes a temporary rule applied to a single match — mainly for boss
## fights, e.g. "midfield attack is halved this match".
##
## Create these as .tres resources per boss (same pattern as your card
## database) so each boss can carry its own list of conditions in the
## Inspector, e.g. res://data/bosses/boss_1_conditions.tres

@export var condition_name: String = ""
@export var description: String = ""  # shown to the player before the match starts

## Which position this rule affects. Leave as "ANY" to apply to every
## card regardless of position.
@export_enum("ANY", "GK", "DEF", "MID", "FWD") var affected_position: String = "ANY"

## Multiplier applied to attack when a card of the affected position is shooting.
@export var attack_multiplier: float = 1.0

## Multiplier applied to defense when a card of the affected position is defending.
@export var defense_multiplier: float = 1.0

## If true, cancels the GK/midfielder SUPPORT bonus (see MatchLogic's
## _defense_support_bonus/_attack_support_bonus) for the affected_position
## this match — e.g. "your midfielder's usual +d5 support doesn't apply
## here". Separate from attack_multiplier/defense_multiplier above, which
## affect the acting card's own stat directly rather than the team's
## passive squad-composition bonus.
@export var disables_support_bonus: bool = false


## True if this condition applies to a card in a given position.
func applies_to(card_position: String) -> bool:
	return affected_position == "ANY" or affected_position == card_position
