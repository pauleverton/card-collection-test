class_name ConsumableEffect
extends Resource

## Base class for a consumable card's actual game effect. Subclass this for
## each distinct MECHANIC (e.g. DiceBoostEffect) — a single subclass gets
## reused by many ConsumableCards with different exported values, so ~30
## cards doesn't mean ~30 scripts, just a handful of mechanics plus data.
##
## To add a new mechanic: create a new script extending ConsumableEffect,
## override apply(), and give it whatever @export fields it needs. Then any
## ConsumableCard can use it by assigning an instance to its `effect` field.

func apply(_battle_manager: BattleManager) -> void:
	push_warning("ConsumableEffect: apply() not implemented on this subclass")
