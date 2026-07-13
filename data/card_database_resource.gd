class_name CardDatabaseResource
extends Resource

## The single source of truth for every card in the game.
## Edit res://card_database.tres in the Godot Inspector to add/tweak cards —
## click the array, increase size, and assign or create a new CardData
## sub-resource per element. All 150+ cards live in this one file.
@export var cards: Array[CardData] = []
