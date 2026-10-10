@tool
class_name PlayerCard
extends Resource

@export var display_name: String = ""
@export_multiline var description: String = ""
@export var rarity: String = "common"
@export var boosts_type: String = "any"
@export var boosts_tags: String = "any"
@export var bonus: int = 1

## How much this player adds to a given card.
func bonus_for(card: ActionCard) -> int:
	if boosts_type != "any" and card.card_type != boosts_type:
		return 0
	if boosts_tags != "any" and card.tag != boosts_tags:
		return 0
	return bonus
	
## Dropdowns built from the same lists as the cards, plus "any".
func _validate_property(property: Dictionary) -> void:
	if property.name == "boosts_tags":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(["any"] + CardTags.TAGS)
	elif property.name == "boosts_type":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(["any"] + CardTags.TYPES)
