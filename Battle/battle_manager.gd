extends Node
class_name BattleManager

## Turn-based match logic: player picks a target each round, a dice roll
## decides whether a goal is scored based on attacker vs defender stats.
##
## Drop this script onto a Node in your Battle scene (or make it an Autoload
## if you want match state to persist across scene changes). Hook your UI
## buttons up to `player_take_shot(defender_id)` and listen to the signals
## below to update labels/animations.

# --- Signals for UI to hook into ---
signal shot_resolved(attacker_id: String, defender_id: String, roll: int, chance: int, scored: bool)
signal round_started(round_number: int)
signal match_ended(player_goals: int, opponent_goals: int, player_won: bool)

# --- Config ---
@export var total_rounds: int = 5

# --- Match state ---
var player_squad: Array[String] = []      # card ids
var opponent_squad: Array[String] = []    # card ids
var player_goals: int = 0
var opponent_goals: int = 0
var current_round: int = 0
var player_shooter_index: int = 0         # cycles through player_squad
var opponent_shooter_index: int = 0       # cycles through opponent_squad
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
	player_shooter_index = 0
	opponent_shooter_index = 0
	match_over = false
	_start_next_round()


func _start_next_round() -> void:
	current_round += 1
	round_started.emit(current_round)
	# Waits here for player_take_shot() to be called from UI.


## Call this from your UI when the player picks which opponent card to target.
## Uses the current cycling player shooter as the attacker.
func player_take_shot(defender_id: String) -> void:
	if match_over:
		push_warning("BattleManager: match already over, ignoring shot")
		return

	var attacker_id: String = player_squad[player_shooter_index]
	var scored := _resolve_shot(attacker_id, defender_id, true)

	if scored:
		player_goals += 1

	# Advance to next player shooter for next round (cycle through squad).
	player_shooter_index = (player_shooter_index + 1) % player_squad.size()

	# Opponent immediately takes their mirrored turn (auto target selection).
	_opponent_take_shot()

	_check_match_end()


func _opponent_take_shot() -> void:
	var attacker_id: String = opponent_squad[opponent_shooter_index]
	var defender_id: String = _opponent_pick_target()

	var scored := _resolve_shot(attacker_id, defender_id, false)
	if scored:
		opponent_goals += 1

	opponent_shooter_index = (opponent_shooter_index + 1) % opponent_squad.size()


## Simple AI: opponent targets whichever of your cards has the lowest defense.
## Swap this out for something smarter later (e.g. weighted by rarity).
func _opponent_pick_target() -> String:
	var weakest_id: String = player_squad[0]
	var weakest_defense: int = _get_defense(weakest_id)

	for id in player_squad:
		var d := _get_defense(id)
		if d < weakest_defense:
			weakest_defense = d
			weakest_id = id

	return weakest_id


## Core resolution: works out goal chance, rolls the dice, emits the result.
func _resolve_shot(attacker_id: String, defender_id: String, is_player_shot: bool) -> bool:
	var chance := calculate_goal_chance(attacker_id, defender_id)
	var roll := roll_dice()
	var scored := roll <= chance

	shot_resolved.emit(attacker_id, defender_id, roll, chance, scored)
	return scored


## chance = 50 + (attacker.attack - defender.defense), clamped 5-95.
## Even matchup = 50/50. Stat gaps push the odds, but never guarantee
## a result either way.
func calculate_goal_chance(attacker_id: String, defender_id: String) -> int:
	var attack := _get_attack(attacker_id)
	var defense := _get_defense(defender_id)
	var chance := 50 + (attack - defense)
	return clampi(chance, 5, 95)


func roll_dice() -> int:
	return randi_range(1, 100)


func _get_attack(card_id: String) -> int:
	var card: CardData = CardDatabase.get_card(card_id)
	if card == null:
		push_warning("BattleManager: no card data for '%s', using default attack 50" % card_id)
		return 50

	var attack := float(card.attack)
	for condition in active_conditions:
		if condition.applies_to(card.position):
			attack *= condition.attack_multiplier
	return int(round(attack))


func _get_defense(card_id: String) -> int:
	var card: CardData = CardDatabase.get_card(card_id)
	if card == null:
		push_warning("BattleManager: no card data for '%s', using default defense 50" % card_id)
		return 50

	var defense := float(card.defense)
	for condition in active_conditions:
		if condition.applies_to(card.position):
			defense *= condition.defense_multiplier
	return int(round(defense))


func _check_match_end() -> void:
	if current_round >= total_rounds:
		match_over = true
		var player_won := player_goals > opponent_goals
		match_ended.emit(player_goals, opponent_goals, player_won)
	else:
		_start_next_round()
