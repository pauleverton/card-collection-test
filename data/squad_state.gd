extends Node

## Autoload singleton. Add this as "SquadState" in Project Settings > Autoload.
## Holds the card ids the player currently owns/has in their squad.

const MAX_SQUAD_SIZE := 7

var squad: Array[String] = []

func has_card(id: String) -> bool:
	return squad.has(id)

func is_full() -> bool:
	return squad.size() >= MAX_SQUAD_SIZE

func add_to_squad(id: String) -> bool:
	if is_full():
		push_warning("SquadState: squad is full, cannot add %s" % id)
		return false
	squad.append(id)
	return true

func remove_from_squad(id: String) -> void:
	squad.erase(id)
