extends Node

## Autoload singleton. Register as "MatchSquadState" in Project Settings > Autoload.
## Holds up to 3 card ids selected for the upcoming match.

const MAX_SELECTED := 3

var selected: Array[String] = []

func is_selected(id: String) -> bool:
	return selected.has(id)

func clear() -> void:
	selected.clear()

func remove(id: String) -> void:
	selected.erase(id)

func toggle_selection(id: String) -> bool:
	if selected.has(id):
		selected.erase(id)
		return true

	if selected.size() >= MAX_SELECTED:
		push_warning("MatchSquadState: already have 3 players selected")
		return false

	var card: CardData = CardDatabase.get_card(id)
	if card != null and card.position == "GK":
		for existing_id in selected:
			var existing_card: CardData = CardDatabase.get_card(existing_id)
			if existing_card != null and existing_card.position == "GK":
				push_warning("MatchSquadState: already selected a goalkeeper")
				return false

	selected.append(id)
	return true

## Returns selected ids with any goalkeeper first — slot 1 = GK.
func get_ordered_selection() -> Array:
	var goalkeepers: Array = []
	var others: Array = []
	for id in selected:
		var card: CardData = CardDatabase.get_card(id)
		if card != null and card.position == "GK":
			goalkeepers.append(id)
		else:
			others.append(id)
	return goalkeepers + others
