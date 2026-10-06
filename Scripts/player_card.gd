class_name PlayerCard
extends Resource

@export var display_name: String = ""
@export_multiline var description: String = ""
@export var rarity: String = "common"
## Boost cards of this card_type ("" = don't filter by type).
@export var boosts_type: String = ""
## Or boost only these tags, e.g. ["cross"] (empty = don't filter by tag).
@export var boosts_tags: Array[String] = []
@export var bonus: int = 1

## How much this player adds to a given card.
func bonus_for(card: ActionData) -> int:
	if boosts_type != "" and card.card_type != boosts_type:
		return 0
	if not boosts_tags.is_empty() and not card.tag in boosts_tags:
		return 0
	return bonus
