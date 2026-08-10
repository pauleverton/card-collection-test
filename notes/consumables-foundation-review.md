# Consumables foundation — proposed changes for review

Scope: data layer + inventory autoload, following the CardDatabase/SquadState
pattern already in the project. No scene/UI changes yet — `match_attempt.gd`
still uses its hardcoded `_lucky_boots` until you're ready for that pass.

Nothing here has been applied to the project. Copy scripts into Godot's
script editor / create resources via the Inspector as described.

---

## 1. `data/consumable_effect.gd` — EDIT existing file

Adds `target_type` so callers know what an effect needs before invoking it
(NONE = usable anywhere e.g. coins, CARD = needs a specific owned card e.g.
permanent stat boost, MATCH = mid-match only e.g. dice boost).

```gdscript
class_name ConsumableEffect
extends Resource

## Base class for a consumable card's actual game effect. Subclass this for
## each distinct MECHANIC (e.g. DiceBoostEffect) — a single subclass gets
## reused by many ConsumableCards with different exported values, so ~30
## cards doesn't mean ~30 scripts, just a handful of mechanics plus data.
##
## target_type declares what apply() actually needs, so whichever screen is
## offering "use" (match, locker room, shop) knows what to provide/prompt
## for before calling it:
##   NONE  — needs nothing, e.g. a coin reward. Usable from anywhere.
##   CARD  — needs a specific owned card, e.g. a permanent stat boost.
##   MATCH — only usable mid-match, e.g. a dice boost for the next shot.
##
## To add a new mechanic: create a new script extending ConsumableEffect,
## override apply(), set target_type in _init(), and give it whatever
## @export fields it needs. Then any ConsumableCard can use it by assigning
## an instance to its `effect` field.

enum TargetType { NONE, CARD, MATCH }

var target_type: TargetType = TargetType.NONE

## match_logic and card are both nullable — only whichever one(s) match
## target_type will actually be non-null when a caller invokes apply().
func apply(_match_logic: MatchLogic = null, _card: CardData = null) -> void:
	push_warning("ConsumableEffect: apply() not implemented on this subclass")
```

Note: `target_type` is set in each subclass's `_init()`, not `@export`ed —
it's a property of the *mechanic*, not something you'd want to accidentally
change per-card in the Inspector.

---

## 2. `data/effects/dice_boost_effect.gd` — EDIT existing file

```gdscript
class_name DiceBoostEffect
extends ConsumableEffect

## Boosts the player's next attacking roll to use a bigger die for one shot
## (e.g. d30 instead of the standard d20). Reused by any card that wants
## this mechanic — only dice_sides needs to differ between cards.

@export var dice_sides: int = 30

func _init() -> void:
	target_type = TargetType.MATCH

func apply(match_logic: MatchLogic = null, _card: CardData = null) -> void:
	match_logic.apply_player_dice_boost(dice_sides)
```

---

## 3. `data/consumable_card.gd` — EDIT existing file

Adds `cost` (for the shop, coming later) and lets `use()` pass a card
through for CARD-targeted effects.

```gdscript
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

## Shop price in coins.
@export var cost: int = 50

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


## Applies the effect and consumes one use. Pass whichever of match_logic /
## card the effect's target_type actually needs — the caller decides based
## on effect.target_type, this just forwards both through. Returns false
## (and does nothing else) if there are no uses left or no effect assigned.
func use(match_logic: MatchLogic = null, card: CardData = null) -> bool:
	if not can_use():
		push_warning("ConsumableCard '%s': cannot be used (no uses left or no effect assigned)" % display_name)
		return false
	effect.apply(match_logic, card)
	uses_remaining -= 1
	return true
```

`match_attempt.gd`'s existing call site (`_lucky_boots.use(match_logic)`)
still works unchanged — `card` just defaults to null.

---

## 4. `data/consumable_database_resource.gd` — NEW file

```gdscript
class_name ConsumableDatabaseResource
extends Resource

## The single source of truth for every consumable in the game.
## Edit res://data/consumable_database.tres in the Godot Inspector to add/
## tweak consumables — click the array, increase size, and assign each
## element to one of the per-consumable .tres files in res://data/consumables/.
@export var consumables: Array[ConsumableCard] = []
```

---

## 5. `data/consumable_database.gd` — NEW file (autoload)

Direct mirror of `card_database.gd`.

```gdscript
extends Node

## Autoload singleton. Add this as "ConsumableDatabase" in Project Settings > Autoload.
##
## Loads res://data/consumable_database.tres ONCE at startup and builds a
## Dictionary keyed by consumable id for O(1) lookups.

const DATABASE_PATH := "res://data/consumable_database.tres"

var _consumables_by_id: Dictionary = {}  # id (String) -> ConsumableCard
var all_ids: Array = []

func _ready() -> void:
	_load_database()

func _load_database() -> void:
	if not ResourceLoader.exists(DATABASE_PATH):
		push_error("ConsumableDatabase: could not find %s" % DATABASE_PATH)
		return

	var db: ConsumableDatabaseResource = load(DATABASE_PATH)
	if db == null:
		push_error("ConsumableDatabase: failed to load database resource")
		return

	_consumables_by_id.clear()
	all_ids.clear()

	for consumable in db.consumables:
		if consumable == null or consumable.id.is_empty():
			push_warning("ConsumableDatabase: skipping consumable with empty id")
			continue
		if _consumables_by_id.has(consumable.id):
			push_warning("ConsumableDatabase: duplicate consumable id '%s'" % consumable.id)
		_consumables_by_id[consumable.id] = consumable
		all_ids.append(consumable.id)

	print("ConsumableDatabase: loaded %d consumables" % all_ids.size())

## Returns the ConsumableCard for a given id, or null if not found.
func get_consumable(id: String) -> ConsumableCard:
	return _consumables_by_id.get(id, null)

## Returns a copy of all known consumable ids (safe to shuffle without mutating the source).
func get_all_ids() -> Array:
	return all_ids.duplicate()
```

---

## 6. `data/consumable_inventory_state.gd` — NEW file (autoload)

Mirrors `squad_state.gd`'s shape but capped at 5. Stores ids (not live
`ConsumableCard` instances) — same reasoning as `SquadState.squad`: the
data is looked up from the database on demand, so there's nothing to keep
in sync.

**Open question for you**: should duplicates be allowed (e.g. carry 2x the
same coin-boost item)? `SquadState` blocks duplicate players because each
card is a unique athlete, but that logic doesn't obviously apply to
consumables. I've left it allowed below (no uniqueness check) — flag if you
want it blocked instead.

```gdscript
extends Node

## Autoload singleton. Registered as "ConsumableInventoryState" in Project
## Settings > Autoload. Holds the consumable ids the player currently
## carries, capped at MAX_SLOTS. Mirrors SquadState's shape, but duplicates
## ARE allowed here (e.g. carrying two coin-boost items) — revisit if that
## turns out to be wrong for a specific consumable.

signal inventory_changed()

const MAX_SLOTS := 5

var inventory: Array[String] = []

func has_consumable(id: String) -> bool:
	return inventory.has(id)

func is_full() -> bool:
	return inventory.size() >= MAX_SLOTS

func add_to_inventory(id: String) -> bool:
	var consumable: ConsumableCard = ConsumableDatabase.get_consumable(id)
	if consumable == null:
		push_warning("ConsumableInventoryState: no consumable data for id '%s'" % id)
		return false
	if is_full():
		push_warning("ConsumableInventoryState: inventory is full (max %d)" % MAX_SLOTS)
		return false
	inventory.append(id)
	inventory_changed.emit()
	return true

func remove_from_inventory(id: String) -> void:
	inventory.erase(id)
	inventory_changed.emit()
```

---

## 7. Resources to create in the Godot editor (not hand-written .tres)

Better done through the Inspector than hand-authored — Godot assigns
correct internal resource ids/uids for you and it's less error-prone.

1. **`res://data/consumables/lucky_boots.tres`**
   New Resource → `ConsumableCard`. Fields:
   - `id`: `lucky_boots`
   - `display_name`: `Lucky Boots`
   - `description`: `Your next shot rolls a d30 instead of a d20.`
   - `cost`: `75` (placeholder — tune later)
   - `max_uses`: `1`
   - `effect`: New Resource → `DiceBoostEffect`, `dice_sides` = `30`

   This replaces the hardcoded block in `match_attempt.gd:85-92` — once
   this `.tres` exists, that `_ready()` block can load it via
   `ConsumableDatabase.get_consumable("lucky_boots")` instead of
   constructing it in code. (Leaving that wiring for the next pass, per
   your earlier scoping — happy to do it now too if you'd rather.)

2. **`res://data/consumable_database.tres`**
   New Resource → `ConsumableDatabaseResource`. `consumables` array, size
   1, element 0 = the `lucky_boots.tres` you just made (drag it in, or
   "Load" and pick the file).

---

## 8. Autoload registration (Project Settings → Autoload)

Add two, same panel where `CardDatabase`/`SquadState`/etc. already are:

| Name | Path |
|---|---|
| `ConsumableDatabase` | `res://data/consumable_database.gd` |
| `ConsumableInventoryState` | `res://data/consumable_inventory_state.gd` |

Godot will write the resulting `uid://...` lines into `project.godot`'s
`[autoload]` section itself once added via the UI.

---

## Not included here (deliberately)

- Shop scene/UI (next phase once this loads cleanly)
- Wiring `match_attempt.gd` to read from `ConsumableInventoryState` instead
  of the hardcoded `_lucky_boots` (currently still hardcoded — safe to
  leave as-is until the shop exists, since there's nothing to buy yet)
- Any new effect subclasses beyond `DiceBoostEffect` (coin reward, stat
  boost, reroll, etc.) — worth doing once you're happy with this shape
