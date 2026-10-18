@tool
class_name PlayerCard
extends Resource

@export var display_name: String = ""
@export_multiline var description: String = ""
@export_enum("common","uncommon","rare","special") var rarity: String = "common"
@export var boosts_type: String = "any"
@export var boosts_tags: String = "any"
@export var bonus: int = 0
@export var multiplier: float = 1.0
## "card" = multiplies only the card's own value; "total" = multiplies everything, bonuses included.
@export_enum("card", "total") var multiplies: String = "total"

## Does this player care about this card at all? (type and tag filters)
func applies_to(card: ActionCard) -> bool:
	if boosts_type != "any" and card.card_type != boosts_type:
		return false
	if boosts_tags != "any" and card.tag != boosts_tags:
		return false
	return true

## How much this player adds to a given card.
func bonus_for(card: ActionCard) -> int:
	return bonus if applies_to(card) else 0

## True if this player changes this card in any way (bonus or multiplier).
func affects(card: ActionCard) -> bool:
	return applies_to(card) and (bonus != 0 or multiplier != 1.0)

## Short text for the reaction pop-up, e.g. "+10", "×2" or "+10 ×1.5".
func effect_label() -> String:
	var parts: PackedStringArray = []
	if bonus != 0:
		parts.append("+%d" % bonus)
	if multiplier != 1.0:
		parts.append("×" + String.num(multiplier))
	return " ".join(parts)

## Dropdowns built from the same lists as the cards, plus "any".
func _validate_property(property: Dictionary) -> void:
	if property.name == "boosts_tags":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(["any"] + CardTags.TAGS)
	elif property.name == "boosts_type":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(["any"] + CardTags.TYPES)
