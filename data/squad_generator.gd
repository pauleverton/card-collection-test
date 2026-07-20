class_name SquadGenerator
extends RefCounted

## Builds opponent squads for matches.
##
## Normal matches: fully random pull from the whole card database.
## Boss matches: mostly pulls from one target rarity tier, but each slot has
## a chance to pull from the tier above instead — so a boss is recognisably
## "a gold-tier boss" but might unluckily/luckily field one standout rare
## card, keeping runs varied without making bosses fully random.

const RARITY_ORDER := ["bronze", "silver", "gold"]


## Fully random squad, used for regular (non-boss) matches.
static func generate_random_squad(size: int) -> Array[String]:
	var pool: Array = CardDatabase.get_all_ids()
	pool.shuffle()

	var squad: Array[String] = []
	for i in range(min(size, pool.size())):
		squad.append(pool[i])
	return squad


## Boss squad generation.
## base_rarity: the boss's baseline tier ("bronze", "silver", "gold").
## upgrade_chance: 0.0-1.0 chance PER SLOT to pull from the tier above instead.
static func generate_boss_squad(size: int, base_rarity: String, upgrade_chance: float = 0.25) -> Array[String]:
	var base_index := RARITY_ORDER.find(base_rarity)
	if base_index == -1:
		push_warning("SquadGenerator: unknown rarity '%s', defaulting to bronze" % base_rarity)
		base_index = 0

	var squad: Array[String] = []
	for i in range(size):
		var rarity_to_use := base_rarity
		if base_index < RARITY_ORDER.size() - 1 and randf() < upgrade_chance:
			rarity_to_use = RARITY_ORDER[base_index + 1]

		var card_id := _pick_random_of_rarity(rarity_to_use)
		if card_id != "":
			squad.append(card_id)
		else:
			# Fallback: no cards of that rarity exist yet, just grab anything.
			push_warning("SquadGenerator: no cards found for rarity '%s'" % rarity_to_use)
			var fallback := generate_random_squad(1)
			if not fallback.is_empty():
				squad.append(fallback[0])

	return squad


static func _pick_random_of_rarity(rarity: String) -> String:
	var matches: Array = []
	for id in CardDatabase.get_all_ids():
		var card: CardData = CardDatabase.get_card(id)
		if card != null and card.rarity == rarity:
			matches.append(id)

	if matches.is_empty():
		return ""

	matches.shuffle()
	return matches[0]
