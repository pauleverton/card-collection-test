extends Node

## Autoload singleton. Registered as "SquadState" in Project Settings > Autoload.
## Holds the card ids the player currently owns/has in their squad.

const MAX_GOALKEEPERS := 1
const MAX_OUTFIELD := 6

var squad: Array[String] = []

func has_card(id: String) -> bool:
	return squad.has(id)

func goalkeeper_count() -> int:
	var count := 0
	for id in squad:
		var card: CardData = CardDatabase.get_card(id)
		if card != null and card.position == "GK":
			count += 1
	return count

func outfield_count() -> int:
	return squad.size() - goalkeeper_count()

func add_to_squad(id: String) -> bool:
	var card: CardData = CardDatabase.get_card(id)
	if card == null:
		return false

	if card.position == "GK":
		if goalkeeper_count() >= MAX_GOALKEEPERS:
			push_warning("SquadState: already have a goalkeeper")
			return false
	else:
		if outfield_count() >= MAX_OUTFIELD:
			push_warning("SquadState: outfield squad is full")
			return false

	squad.append(id)
	return true

func remove_from_squad(id: String) -> void:
	squad.erase(id)
