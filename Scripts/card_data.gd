class_name CardData
extends Resource

## Unique identifier used for texture lookup and dictionary keys.
## Must match the filename in res://Cards/ (without .png), e.g. "james_garner_bronze"
@export var id: String = ""

@export var display_name: String = ""

@export_enum("bronze", "silver", "gold") var rarity: String = "bronze"

## Base coin value when this card is sold.
@export var sell_value: int = 10

## Drag the card's PNG from res://Cards/ directly onto this field in the
## Inspector. This is the actual link to the image — no string matching,
## no risk of a typo or rename silently breaking the connection.
@export var texture: Texture2D

## --- Future roguelike expansion ---
## Uncomment / extend as your stat system grows. Keeping these here now
## Shooting/finishing ability, used when this card is the attacker in a match.
@export_range(1, 99) var attack: int = 50
 
## Tackling/goalkeeping ability, used when this card is the defender in a match.
@export_range(1, 99) var defense: int = 50
 
## Used by boss MatchConditions to target specific positions (e.g.
## "midfield attack halved this match").
@export_enum("GK", "DEF", "MID", "FWD") var position: String = "MID"
 
## --- Future roguelike expansion ---
## Uncomment / extend as your stat system grows. Keeping these here now
## means the schema doesn't need to change shape later, just get used.
#@export var modifiers: Array[CardModifier] = []
