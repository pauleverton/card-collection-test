extends Node
class_name MatchLogic

## Turn-based match logic using an opposed d20 check, D&D-style: both the
## attacker and defender roll a die and add their own modifier. Whoever's
## total is higher wins that exchange. This gives jeopardy on both sides
## (a strong attacker can still miss on a bad roll; a weak defender can
## still make a save on a good one) and leaves room for future cards to
## add bonuses/rerolls to either roll without changing the core structure.
##
## Squad composition bonuses (GK / midfielder) are additive support rolls,
## not die swaps — the acting player's own d20 always stays a d20. See
## _defense_support_bonus() / _attack_support_bonus() below.
##
## Flow for one round, driven by the UI (see match_attempt.gd):
##   1. preview_chance(defender_id)      -- true probability, no roll yet
##   2. resolve_player_shot(defender_id) -- rolls + resolves the player's shot
##   3. resolve_opponent_shot()          -- rolls + resolves the opponent's shot
##   4. advance_round()                  -- moves to next round / ends match

signal shot_resolved(
	attacker_id: String, defender_id: String,
	attacker_roll: int, attacker_modifier: int, attacker_dice_sides: int, attacker_bonus: int,
	defender_roll: int, defender_modifier: int, defender_dice_sides: int, defender_bonus: int,
	scored: bool, is_player_shot: bool
)
signal round_started(round_number: int)
signal match_ended(player_goals: int, opponent_goals: int, player_won: bool)

# --- Config ---
@export var total_rounds: int = 1
const DICE_SIDES := 20

# --- Match state ---
var player_squad: Array[String] = []      # card ids
var opponent_squad: Array[String] = []    # card ids
var player_goals: int = 0
var opponent_goals: int = 0
var current_round: int = 0
var opponent_shooter_index: int = 0       # opponent still auto-cycles (AI-controlled)
var match_over: bool = false

## Boss-fight rules for this match, e.g. "midfield attack halved". Empty for
## normal matches. Set via start_match()'s conditions argument.
var active_conditions: Array[MatchCondition] = []

## One-shot override for the player's NEXT attacking roll only (e.g. a
## consumable card that widens the die for a single shot). -1 means "no
## override, use the standard die". Automatically consumed and reset back
## to -1 the moment resolve_player_shot() is called. Takes priority over
## the passive midfielder support bonus below if both are active at once.
var _player_attacker_dice_override: int = -1


## conditions is optional — pass a boss's MatchCondition list for boss fights,
## or leave empty for a normal random match.
func start_match(p_squad: Array[String], o_squad: Array[String], conditions: Array[MatchCondition] = []) -> void:
	player_squad = p_squad.duplicate()
	opponent_squad = o_squad.duplicate()
	active_conditions = conditions.duplicate()
	player_goals = 0
	opponent_goals = 0
	current_round = 0
	opponent_shooter_index = 0
	match_over = false
	_begin_round()


func _begin_round() -> void:
	current_round += 1
	round_started.emit(current_round)


## Whichever of the opponent's cards is up to shoot this round.
func get_current_opponent_shooter() -> String:
	return opponent_squad[opponent_shooter_index]


## Lets the UI reveal who the AI is about to target BEFORE rolling, mirroring
## the player's own target-preview step. As targeting difficulty scales up
## later, swap the logic in _opponent_pick_target() — this (and
## resolve_opponent_shot) will automatically reflect whatever it decides.
func preview_opponent_target() -> String:
	return _opponent_pick_target()


func preview_opponent_chance() -> int:
	return calculate_goal_chance(get_current_opponent_shooter(), preview_opponent_target())


## Resolves the player's shot: attacker_id is whichever of the player's cards
## THEY chose to attack with, defender_id is whichever opponent card they
## chose to target. Rolls both dice (plus any GK/midfielder support bonus),
## updates score, emits shot_resolved. Does NOT trigger the opponent's turn
## — call resolve_opponent_shot() separately once the UI has shown this result.
func resolve_player_shot(attacker_id: String, defender_id: String) -> bool:
	if match_over:
		push_warning("MatchLogic: match already over, ignoring shot")
		return false

	var attacker_dice_sides: int
	if _player_attacker_dice_override > 0:
		attacker_dice_sides = _player_attacker_dice_override  # consumable takes priority
	else:
		attacker_dice_sides = DICE_SIDES
	_player_attacker_dice_override = -1  # consumed — one-shot only

	var attacker_bonus := _attack_support_bonus(attacker_id, player_squad)
	var defender_bonus := _defense_support_bonus(defender_id, opponent_squad)

	var scored := _resolve_shot(
		attacker_id, defender_id, true,
		attacker_dice_sides, DICE_SIDES,
		attacker_bonus, defender_bonus
	)
	if scored:
		player_goals += 1
	return scored


## Applies a one-shot dice override for the player's NEXT attacking roll
## only — e.g. a consumable card that widens the die from d20 to d30 for a
## single shot. Automatically reverts to the standard die afterwards.
func apply_player_dice_boost(sides: int) -> void:
	_player_attacker_dice_override = sides


## What the player's next attacking roll will actually use — the standard
## die, unless a boost is currently pending. Lets the UI preview the
## boosted odds before the shot is taken.
func get_pending_player_dice_sides() -> int:
	return _player_attacker_dice_override if _player_attacker_dice_override > 0 else DICE_SIDES


## Resolves the opponent's mirrored turn (auto target selection). Call this
## after resolve_player_shot(), once the UI is ready to show it.
func resolve_opponent_shot() -> bool:
	if match_over:
		push_warning("MatchLogic: match already over, ignoring shot")
		return false

	var attacker_id: String = opponent_squad[opponent_shooter_index]
	var defender_id: String = _opponent_pick_target()

	var attacker_bonus := _attack_support_bonus(attacker_id, opponent_squad)
	var defender_bonus := _defense_support_bonus(defender_id, player_squad)

	var scored := _resolve_shot(
		attacker_id, defender_id, false,
		DICE_SIDES, DICE_SIDES,
		attacker_bonus, defender_bonus
	)
	if scored:
		opponent_goals += 1

	opponent_shooter_index = (opponent_shooter_index + 1) % opponent_squad.size()
	return scored


## Call once both shots for the round have been shown to the player, to move
## on to the next round (or end the match if this was the last one).
func advance_round() -> void:
	if current_round >= total_rounds:
		match_over = true
		var player_won := player_goals > opponent_goals
		match_ended.emit(player_goals, opponent_goals, player_won)
	else:
		_begin_round()


## Simple AI: opponent targets whichever of your cards has the lowest defense.
## Swap this out for something smarter later (e.g. weighted by rarity).
func _opponent_pick_target() -> String:
	var weakest_id: String = player_squad[0]
	var weakest_defense: int = _get_defense_modifier(weakest_id)

	for id in player_squad:
		var d := _get_defense_modifier(id)
		if d < weakest_defense:
			weakest_defense = d
			weakest_id = id

	return weakest_id


## Core resolution: both sides roll a die (standard d20 unless overridden)
## and add their modifier — plus any GK/midfielder support bonus already
## folded into attacker_bonus/defender_bonus by the caller. Higher total
## wins the exchange.
func _resolve_shot(
	attacker_id: String, defender_id: String, is_player_shot: bool,
	attacker_dice_sides: int = DICE_SIDES, defender_dice_sides: int = DICE_SIDES,
	attacker_bonus: int = 0, defender_bonus: int = 0
) -> bool:
	var attacker_mod := _get_attack_modifier(attacker_id) + attacker_bonus
	var defender_mod := _get_defense_modifier(defender_id) + defender_bonus

	var attacker_roll := roll_die(attacker_dice_sides)
	var defender_roll := roll_die(defender_dice_sides)

	var attacker_total := attacker_roll + attacker_mod
	var defender_total := defender_roll + defender_mod
	var scored := attacker_total > defender_total

	shot_resolved.emit(
		attacker_id, defender_id,
		attacker_roll, attacker_mod, attacker_dice_sides, attacker_bonus,
		defender_roll, defender_mod, defender_dice_sides, defender_bonus,
		scored, is_player_shot
	)
	return scored


func roll_die(sides: int = DICE_SIDES) -> int:
	return randi_range(1, sides)


## True probability of the attacker beating the defender given both sides'
## current modifiers and dice sizes — computed by checking every possible
## outcome, so it's always accurate rather than hand-tuned. Pass a
## non-default dice_sides to preview the effect of a boosted die.
##
## NOTE: does not currently factor in the GK/midfielder support bonus,
## since that's a second random roll rather than a dice-size change — the
## percentage shown here is the base chance before that bonus is applied.
func calculate_goal_chance(attacker_id: String, defender_id: String, attacker_dice_sides: int = DICE_SIDES, defender_dice_sides: int = DICE_SIDES) -> int:
	var attacker_mod := _get_attack_modifier(attacker_id)
	var defender_mod := _get_defense_modifier(defender_id)

	var favorable := 0
	var total := 0
	for a in range(1, attacker_dice_sides + 1):
		for d in range(1, defender_dice_sides + 1):
			total += 1
			if (a + attacker_mod) > (d + defender_mod):
				favorable += 1

	return int(round(100.0 * favorable / total))


func _get_attack_modifier(card_id: String) -> int:
	var card: CardData = CardDatabase.get_card(card_id)
	if card == null:
		push_warning("MatchLogic: no card data for '%s', using default modifier" % card_id)
		return 5

	var attack := float(card.attack)
	for condition in active_conditions:
		if condition.applies_to(card.position):
			attack *= condition.attack_multiplier
	return int(round(attack / 10.0))


func _get_defense_modifier(card_id: String) -> int:
	var card: CardData = CardDatabase.get_card(card_id)
	if card == null:
		push_warning("MatchLogic: no card data for '%s', using default modifier" % card_id)
		return 5

	var defense := float(card.defense)
	for condition in active_conditions:
		if condition.applies_to(card.position):
			defense *= condition.defense_multiplier
	return int(round(defense / 10.0))


## True if any card in the squad has the given position ("GK", "MID", etc.)
func _squad_has_position(squad: Array[String], position: String) -> bool:
	for id in squad:
		var card: CardData = CardDatabase.get_card(id)
		if card != null and card.position == position:
			return true
	return false


## True if any of this match's active_conditions disables the support
## bonus for the given position (see MatchCondition.disables_support_bonus)
## — set by a boss's signature rule (see BossTeam / BossRoster).
func _support_bonus_disabled_for(position: String) -> bool:
	for condition in active_conditions:
		if condition.disables_support_bonus and condition.applies_to(position):
			return true
	return false


## GK's presence adds a supporting d8 roll on top of the normal defense roll
## whenever another player on their squad is defending — representing the
## keeper organizing/covering. The GK's own defense roll (when THEY'RE the
## one being shot at) is unaffected — no bonus, plain d20 only.
func _defense_support_bonus(defender_id: String, defending_squad: Array[String]) -> int:
	if _support_bonus_disabled_for("GK"):
		return 0
	var defender_card: CardData = CardDatabase.get_card(defender_id)
	var defender_is_gk := defender_card != null and defender_card.position == "GK"
	if not defender_is_gk and _squad_has_position(defending_squad, "GK"):
		return roll_die(8)
	return 0


## A midfielder's presence adds a supporting d5 roll on top of the normal
## attack roll whenever another player on their squad is attacking —
## representing the extra buildup/service. The midfielder's own attack roll
## (when THEY'RE the one shooting) is unaffected — no bonus, plain d20 only.
func _attack_support_bonus(attacker_id: String, attacking_squad: Array[String]) -> int:
	if _support_bonus_disabled_for("MID"):
		return 0
	var attacker_card: CardData = CardDatabase.get_card(attacker_id)
	var attacker_is_mid := attacker_card != null and attacker_card.position == "MID"
	if not attacker_is_mid and _squad_has_position(attacking_squad, "MID"):
		return roll_die(5)
	return 0
