@tool
class_name BanCardTag
extends BossEffect
## Switches off every one of your cards with this tag ("cross" = Crossing is nullified).

@export var banned_tag: String = "cross"

func allows_card(_m: MatchRules, card: ActionCard) -> bool:
	return card.tag != banned_tag

## Turns banned_tag into a dropdown from CardTags, like on the cards.
func _validate_property(property: Dictionary) -> void:
	if property.name == "banned_tag":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(CardTags.TAGS)
