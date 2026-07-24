extends Node
class_name BattleManager

## Turn-based match logic using an opposed d20 check, D&D-style: both the
## attacker and defender roll a die and add their own modifier. Whoever's
## total is higher wins that exchange. This gives jeopardy on both sides
## (a strong attacker can still miss on a bad roll; a weak defender can
## still make a save on a good one) and leaves room for future cards to
## add bonuses/rerolls to either roll without changing the core structure.
##
## Flow for one round, driven by the UI (see battle.gd):
##   1. preview_chance(defender_id)      -- true probability, no roll yet
##   2. resolve_player_shot(defender_id) -- rolls + resolves the player's shot
##   3. resolve_opponent_shot()          -- rolls + resolves the opponent's shot
##   4. advance_round()                  -- moves to next round / ends match

signal shot_resolved(
	attacker_id: String, defender_id: String,
	attacker_roll: int, attacker_modifier: int,
	defender_roll: int, defender_modifier: int,
	scored: bool, is_player_shot: bool
)
signal round_started(round_number: int)
signal match_ended(player_goals: int, opponent_goals: int, player_won: bool)

# --- Config ---
@export var total_rounds: int = 5
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
## chose to target. Rolls both dice, updates score, emits shot_resolved.
## Does NOT trigger the opponent's turn — call resolve_opponent_shot()
## separately once the UI has shown this result.
func resolve_player_shot(attacker_id: String, defender_id: String) -> bool:
	if match_over:
		push_warning("BattleManager: match already over, ignoring shot")
		return false

	var scored := _resolve_shot(attacker_id, defender_id, true)
	if scored:
		player_goals += 1
	return scored


## Resolves the opponent's mirrored turn (auto target selection). Call this
## after resolve_player_shot(), once the UI is ready to show it.
func resolve_opponent_shot() -> bool:
	if match_over:
		push_warning("BattleManager: match already over, ignoring shot")
		return false

	var attacker_id: String = opponent_squad[opponent_shooter_index]
	var defender_id: String = _opponent_pick_target()

	var scored := _resolve_shot(attacker_id, defender_id, false)
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


## Core resolution: both sides roll a d20 and add their modifier. Higher
## total wins the exchange — a genuine opposed check, not a single roll
## against a fixed percentage.
func _resolve_shot(attacker_id: String, defender_id: String, is_player_shot: bool) -> bool:
	var attacker_mod := _get_attack_modifier(attacker_id)
	var defender_mod := _get_defense_modifier(defender_id)

	var attacker_roll := roll_die()
	var defender_roll := roll_die()

	var attacker_total := attacker_roll + attacker_mod
	var defender_total := defender_roll + defender_mod
	var scored := attacker_total > defender_total

	shot_resolved.emit(
		attacker_id, defender_id,
		attacker_roll, attacker_mod,
		defender_roll, defender_mod,
		scored, is_player_shot
	)
	return scored


func roll_die() -> int:
	return randi_range(1, DICE_SIDES)


## True probability of the attacker beating the defender given both sides'
## current modifiers — computed by checking every one of the 400 possible
## d20-vs-d20 outcomes, so it's always accurate rather than hand-tuned.
func calculate_goal_chance(attacker_id: String, defender_id: String) -> int:
	var attacker_mod := _get_attack_modifier(attacker_id)
	var defender_mod := _get_defense_modifier(defender_id)

	var favorable := 0
	var total := 0
	for a in range(1, DICE_SIDES + 1):
		for d in range(1, DICE_SIDES + 1):
			total += 1
			if (a + attacker_mod) > (d + defender_mod):
				favorable += 1

	return int(round(100.0 * favorable / total))


func _get_attack_modifier(card_id: String) -> int:
	var card: CardData = CardDatabase.get_card(card_id)
	if card == null:
		push_warning("BattleManager: no card data for '%s', using default modifier" % card_id)
		return 5

	var attack := float(card.attack)
	for condition in active_conditions:
		if condition.applies_to(card.position):
			attack *= condition.attack_multiplier
	return int(round(attack / 10.0))


func _get_defense_modifier(card_id: String) -> int:
	var card: CardData = CardDatabase.get_card(card_id)
	if card == null:
		push_warning("BattleManager: no card data for '%s', using default modifier" % card_id)
		return 5

	var defense := float(card.defense)
	for condition in active_conditions:
		if condition.applies_to(card.position):
			defense *= condition.defense_multiplier
	return int(round(defense / 10.0))
