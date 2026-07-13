extends Node

## Autoload singleton. Add this as "CardDatabase" in Project Settings > Autoload.
##
## Loads res://card_database.tres ONCE at startup and builds a Dictionary
## keyed by card id for O(1) lookups. Safe for 150+ cards with no
## per-frame or per-lookup performance cost.

const DATABASE_PATH := "res://data/card_database.tres"

var _cards_by_id: Dictionary = {}  # id (String) -> CardData
var all_ids: Array = []

func _ready() -> void:
	_load_database()

func _load_database() -> void:
	if not ResourceLoader.exists(DATABASE_PATH):
		push_error("CardDatabase: could not find %s" % DATABASE_PATH)
		return

	var db: CardDatabaseResource = load(DATABASE_PATH)
	if db == null:
		push_error("CardDatabase: failed to load database resource")
		return

	_cards_by_id.clear()
	all_ids.clear()

	for card in db.cards:
		if card == null or card.id.is_empty():
			push_warning("CardDatabase: skipping card with empty id")
			continue
		if _cards_by_id.has(card.id):
			push_warning("CardDatabase: duplicate card id '%s'" % card.id)
		_cards_by_id[card.id] = card
		all_ids.append(card.id)

	print("CardDatabase: loaded %d cards" % all_ids.size())

## Returns the CardData for a given id, or null if not found.
func get_card(id: String) -> CardData:
	return _cards_by_id.get(id, null)

## Returns the sell value for a card id, with a safe fallback.
func get_sell_value(id: String, fallback: int = 10) -> int:
	var card := get_card(id)
	if card == null:
		push_warning("CardDatabase: no card data for id '%s', using fallback" % id)
		return fallback
	return card.sell_value

## Returns a copy of all known card ids (safe to shuffle without mutating the source).
func get_all_ids() -> Array:
	return all_ids.duplicate()
