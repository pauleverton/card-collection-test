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
