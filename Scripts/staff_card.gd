@tool
class_name StaffCard
extends Resource
## Everything players and coaches have in common.

@export var display_name: String = ""
@export_multiline var description: String = ""
@export_enum("common","uncommon","rare","special") var rarity: String = "common"
## Which cards (and, for coaches, which coach effects) this one cares about.
@export var boosts_type: String = "any"
@export var boosts_tags: String = "any"
## Optional special ability (see Scripts/abilities/ability.gd). Empty = none.
@export var ability: Ability

## The card type his badge shows. "auto" = what he boosts (or a coach's category).
## Set it by hand for anyone who only has an ability or boosts a tag (Super Sub = attacking,
## Twinkle Toes = move). Only changes the badge, never the numbers.
@export var badge_type: String = "auto"

const WHEN_WORDS := {"any": "any score", "winning": "when winning", "drawing": "when drawing",
		"losing": "when losing", "not_winning": "when not winning", "not_losing": "when not losing"}

## The type his badge shows ("" = no badge).
func shown_type() -> String:
	if badge_type != "auto":
		return badge_type
	if boosts_type != "any":
		return boosts_type
	return ""

## "FROM 75'" for an ability that switches on later in the match ("" if it's on from kick-off).
func timed_text() -> String:
	if ability == null or ability.active_from_minute <= 0:
		return ""
	return "FROM %d'" % ability.active_from_minute

## "any score", "when losing" … for that ability.
func when_text() -> String:
	return WHEN_WORDS.get(ability.when_score, "") if ability != null else ""

## Does this match a card/effect type? ("attacking", "defending", …)
func applies_to_type(type: String) -> bool:
	return boosts_type == "any" or boosts_type == type

## Does this care about this card at all? (type and tag filters)
func applies_to(card: ActionCard) -> bool:
	if not applies_to_type(card.card_type):
		return false
	return boosts_tags == "any" or card.tag == boosts_tags

## Overridden by PlayerCard and CoachCard.
func affects(_card: ActionCard) -> bool:
	return false

func effect_label() -> String:
	return ""

## Dropdowns built from the same lists as the cards, plus "any".
func _validate_property(property: Dictionary) -> void:
	if property.name == "boosts_tags":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(["any"] + CardTags.TAGS)
	elif property.name == "boosts_type":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(["any"] + CardTags.TYPES)
	elif property.name == "badge_type":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(["auto"] + CardTags.TYPES)
