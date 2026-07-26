class_name ConsumableCard
extends Resource

## A one-use item card. Holds identity/metadata plus one ConsumableEffect
## (the actual mechanic) and how many times it can be used per match.
##
## Create these as .tres resources (e.g. res://data/consumables/lucky_boots.tres)
## the same way you already do for cards and boss conditions — most will
## just point at an existing ConsumableEffect subclass with different values,
## since many cards will share the same underlying mechanic.

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""

## How many times this card can be used in a single match. Normally 1 —
## a future "captain" mechanic or similar could grant extra charges by
## setting this higher, without anything else here needing to change.
@export var max_uses: int = 1

## The actual mechanic this card performs when used.
@export var effect: ConsumableEffect

## Runtime-only — how many uses are left THIS match. Call reset_uses() when
## a match starts (or when this card is added to a loadout for a match).
var uses_remaining: int = 1


func reset_uses() -> void:
	uses_remaining = max_uses


func can_use() -> bool:
	return uses_remaining > 0 and effect != null


## Applies the effect and consumes one use. Returns false (and does nothing
## else) if there are no uses left or no effect is assigned.
func use(battle_manager: BattleManager) -> bool:
	if not can_use():
		push_warning("ConsumableCard '%s': cannot be used (no uses left or no effect assigned)" % display_name)
		return false
	effect.apply(battle_manager)
	uses_remaining -= 1
	return true
