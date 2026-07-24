extends Control

## Test harness for BattleManager, with a home vs away layout: YOUR squad
## always sits in the left column, the OPPONENT always in the right —
## regardless of who's attacking or defending in a given exchange. Each
## column shows its card's role ("Attacking"/"Defending") for that exchange
## instead of names swapping sides.
##
## Round flow, player-paced:
##   1. See the full opponent squad (name + stats) and pick a target
##   2. Matchup panel fills in: your card (left) vs their card (right),
##      each labelled with its role this exchange, chance in the middle
##   3. Press "Take Shot!" -> both dice spin in their own column -> settle
##   4. Press "Opponent's Turn" -> same panel, roles reversed -> dice -> settle
##   5. Press "Next Round" to continue
##
## DEBUG_MODE registers a small set of clearly-named Home/Away test cards at
## runtime (not saved to card_database.tres) so squads are easy to tell apart
## while testing. Set DEBUG_MODE = false and this reverts to real squads.

const DEBUG_MODE := true

@onready var battle_manager: BattleManager = $BattleManager
@onready var round_label: Label = $VBoxContainer/RoundLabel
@onready var score_label: Label = $VBoxContainer/ScoreLabel
@onready var result_label: Label = $VBoxContainer/ResultLabel
@onready var start_button: Button = $VBoxContainer/StartButton
@onready var take_shot_button: Button = $VBoxContainer/TakeShotButton
@onready var opponent_turn_button: Button = $VBoxContainer/OpponentTurnButton
@onready var next_round_button: Button = $VBoxContainer/NextRoundButton
@onready var opponent_buttons: Array[Button] = [
	$VBoxContainer/OpponentRow/Button1,
	$VBoxContainer/OpponentRow/Button2,
	$VBoxContainer/OpponentRow/Button3
]

# Matchup panel. Node names are historical (AttackerColumn/DefenderColumn
# from an earlier layout) but are now used as fixed HOME (you) / AWAY
# (opponent) columns — left is always yours, right is always theirs.
@onready var player_name_label: Label = $VBoxContainer/MatchupPanel/AttackerColumn/AttackerNameLabel
@onready var player_roll_label: Label = $VBoxContainer/MatchupPanel/AttackerColumn/AttackerRollLabel
@onready var chance_label: Label = $VBoxContainer/MatchupPanel/VsColumn/ChanceLabel
@onready var opponent_name_label: Label = $VBoxContainer/MatchupPanel/DefenderColumn/DefenderNameLabel
@onready var opponent_roll_label: Label = $VBoxContainer/MatchupPanel/DefenderColumn/DefenderRollLabel

const ROLL_ANIMATION_STEPS := 10
const ROLL_ANIMATION_STEP_DELAY := 0.15
const TARGET_REVEAL_PAUSE := 1.5

var player_squad: Array[String] = []
var opponent_squad: Array[String] = []
var selected_defender_id: String = ""
var _last_shot: Dictionary = {}


func _ready() -> void:
	_setup_debug_cards()

	battle_manager.shot_resolved.connect(_on_shot_resolved)
	battle_manager.round_started.connect(_on_round_started)
	battle_manager.match_ended.connect(_on_match_ended)

	start_button.pressed.connect(_on_start_pressed)
	take_shot_button.pressed.connect(_on_take_shot_pressed)
	opponent_turn_button.pressed.connect(_on_opponent_turn_pressed)
	next_round_button.pressed.connect(_on_next_round_pressed)

	for i in range(opponent_buttons.size()):
		opponent_buttons[i].pressed.connect(_on_opponent_button_pressed.bind(i))

	_clear_matchup_panel()
	result_label.text = ""
	score_label.text = ""
	round_label.text = ""
	take_shot_button.visible = false
	opponent_turn_button.visible = false
	next_round_button.visible = false


## Registers clearly-named, clearly-different Home/Away test cards at
## runtime so the two squads are never confusingly similar while debugging.
## Doesn't touch card_database.tres — safe to delete this whole function
## (and DEBUG_MODE) once real squad-building is wired up.
func _setup_debug_cards() -> void:
	if not DEBUG_MODE:
		return

	var home_data := [
		{"id": "debug_home_striker", "name": "Test Striker (Home)", "position": "FWD", "attack": 80, "defense": 30},
		{"id": "debug_home_mid", "name": "Test Midfielder (Home)", "position": "MID", "attack": 55, "defense": 55},
		{"id": "debug_home_keeper", "name": "Test Keeper (Home)", "position": "GK", "attack": 10, "defense": 85},
	]
	var away_data := [
		{"id": "debug_away_striker", "name": "Test Striker (Away)", "position": "FWD", "attack": 70, "defense": 25},
		{"id": "debug_away_mid", "name": "Test Midfielder (Away)", "position": "MID", "attack": 50, "defense": 50},
		{"id": "debug_away_keeper", "name": "Test Keeper (Away)", "position": "GK", "attack": 15, "defense": 90},
	]

	player_squad.clear()
	for data in home_data:
		player_squad.append(_register_debug_card(data))

	opponent_squad.clear()
	for data in away_data:
		opponent_squad.append(_register_debug_card(data))


func _register_debug_card(data: Dictionary) -> String:
	var card := CardData.new()
	card.id = data.id
	card.display_name = data.name
	card.position = data.position
	card.attack = data.attack
	card.defense = data.defense
	CardDatabase.register_debug_card(card)
	return card.id


func _clear_matchup_panel() -> void:
	player_name_label.text = ""
	player_roll_label.text = ""
	chance_label.text = ""
	opponent_name_label.text = ""
	opponent_roll_label.text = ""


func _on_start_pressed() -> void:
	if not DEBUG_MODE:
		opponent_squad = SquadGenerator.generate_random_squad(3)

	_refresh_opponent_buttons()
	_clear_matchup_panel()
	result_label.text = "Match started! Pick a target."
	score_label.text = "You: 0   Opponent: 0"
	take_shot_button.visible = false
	opponent_turn_button.visible = false
	next_round_button.visible = false
	battle_manager.start_match(player_squad, opponent_squad)


## Shows each opponent card's name and stats right on the button, so you can
## actually see who you're playing against before choosing a target.
func _refresh_opponent_buttons() -> void:
	for i in range(opponent_buttons.size()):
		if i < opponent_squad.size():
			opponent_buttons[i].text = _card_display_text(opponent_squad[i])
			opponent_buttons[i].disabled = false
		else:
			opponent_buttons[i].disabled = true


func _card_display_text(card_id: String) -> String:
	var card: CardData = CardDatabase.get_card(card_id)
	if card == null:
		return card_id
	var name := card.display_name if card.display_name != "" else card_id
	return "%s\n(%s)  ATK %d / DEF %d" % [name, card.position, card.attack, card.defense]


# --- Player's turn ---

func _on_opponent_button_pressed(index: int) -> void:
	if index >= opponent_squad.size():
		return

	selected_defender_id = opponent_squad[index]
	for btn in opponent_buttons:
		btn.disabled = true

	var attacker_id := battle_manager.get_current_player_shooter()
	_show_matchup(attacker_id, "Attacking", selected_defender_id, "Defending")

	result_label.text = ""
	take_shot_button.visible = true
	take_shot_button.disabled = false


func _on_take_shot_pressed() -> void:
	take_shot_button.disabled = true
	take_shot_button.visible = false

	battle_manager.resolve_player_shot(selected_defender_id)
	await _animate_dual_roll()
	_reveal_last_shot()

	# Opponent's turn is a separate, deliberate step from here —
	# nothing happens until the player chooses to continue.
	opponent_turn_button.visible = true
	opponent_turn_button.disabled = false


# --- Opponent's turn (separate phase, player-initiated) ---

func _on_opponent_turn_pressed() -> void:
	opponent_turn_button.disabled = true
	opponent_turn_button.visible = false

	var shooter := battle_manager.get_current_opponent_shooter()
	var target := battle_manager.preview_opponent_target()  # one of YOUR cards
	_show_matchup(target, "Defending", shooter, "Attacking")

	result_label.text = "%s is targeting your %s!" % [_display_name(shooter), _display_name(target)]

	await get_tree().create_timer(TARGET_REVEAL_PAUSE).timeout

	battle_manager.resolve_opponent_shot()
	await _animate_dual_roll()
	_reveal_last_shot()

	next_round_button.visible = true
	next_round_button.disabled = false


func _on_next_round_pressed() -> void:
	next_round_button.disabled = true
	next_round_button.visible = false
	_clear_matchup_panel()
	result_label.text = ""
	battle_manager.advance_round()
	_refresh_opponent_buttons()


# --- Matchup panel (fixed home/away columns) ---

## player_id/player_role always populate the LEFT column, opponent_id/
## opponent_role always populate the RIGHT column — regardless of which
## side is attacking this exchange. Role text ("Attacking"/"Defending")
## is what changes, not which side the names appear on.
func _show_matchup(player_id: String, player_role: String, opponent_id: String, opponent_role: String) -> void:
	player_name_label.text = "%s\n(%s)" % [_display_name(player_id), player_role]
	player_roll_label.text = "d20: —"
	opponent_name_label.text = "%s\n(%s)" % [_display_name(opponent_id), opponent_role]
	opponent_roll_label.text = "d20: —"

	var chance: int
	if player_role == "Attacking":
		chance = battle_manager.calculate_goal_chance(player_id, opponent_id)
	else:
		chance = battle_manager.calculate_goal_chance(opponent_id, player_id)
	chance_label.text = "Chance to\nscore: %d%%" % chance


## Spins both dice independently in their own (fixed) column before landing
## on the real rolls. Reads _last_shot to work out which roll belongs to
## the player's side vs the opponent's side, since BattleManager only knows
## "attacker"/"defender", not "home"/"away".
func _animate_dual_roll() -> void:
	var shot := _last_shot
	var final_player_roll: int
	var player_mod: int
	var final_opponent_roll: int
	var opponent_mod: int

	if shot.is_player:
		final_player_roll = shot.attacker_roll
		player_mod = shot.attacker_modifier
		final_opponent_roll = shot.defender_roll
		opponent_mod = shot.defender_modifier
	else:
		final_player_roll = shot.defender_roll
		player_mod = shot.defender_modifier
		final_opponent_roll = shot.attacker_roll
		opponent_mod = shot.attacker_modifier

	for i in range(ROLL_ANIMATION_STEPS):
		player_roll_label.text = "d20: %d" % randi_range(1, 20)
		opponent_roll_label.text = "d20: %d" % randi_range(1, 20)
		await get_tree().create_timer(ROLL_ANIMATION_STEP_DELAY).timeout

	player_roll_label.text = "d20: %d  %s  = %d" % [
		final_player_roll, _format_modifier(player_mod), final_player_roll + player_mod
	]
	opponent_roll_label.text = "d20: %d  %s  = %d" % [
		final_opponent_roll, _format_modifier(opponent_mod), final_opponent_roll + opponent_mod
	]
	await get_tree().create_timer(1.0).timeout


func _format_modifier(modifier: int) -> String:
	return ("+%d" % modifier) if modifier >= 0 else str(modifier)


func _reveal_last_shot() -> void:
	var shot := _last_shot
	var who := "You" if shot.is_player else "Opponent"
	var outcome := "GOAL!" if shot.scored else "Missed"
	result_label.text = "%s: %s" % [who, outcome]
	score_label.text = "You: %d   Opponent: %d" % [battle_manager.player_goals, battle_manager.opponent_goals]


# --- Shared helpers ---

func _display_name(card_id: String) -> String:
	var card: CardData = CardDatabase.get_card(card_id)
	if card == null or card.display_name == "":
		return card_id
	return card.display_name


func _on_round_started(round_number: int) -> void:
	round_label.text = "Round %d / %d" % [round_number, battle_manager.total_rounds]


func _on_shot_resolved(
	attacker_id: String, defender_id: String,
	attacker_roll: int, attacker_modifier: int,
	defender_roll: int, defender_modifier: int,
	scored: bool, is_player_shot: bool
) -> void:
	_last_shot = {
		"attacker": attacker_id,
		"defender": defender_id,
		"attacker_roll": attacker_roll,
		"attacker_modifier": attacker_modifier,
		"defender_roll": defender_roll,
		"defender_modifier": defender_modifier,
		"scored": scored,
		"is_player": is_player_shot
	}


func _on_match_ended(player_goals: int, opponent_goals: int, player_won: bool) -> void:
	var verdict := "You win!" if player_won else "You lose."
	result_label.text += "\n\nMATCH OVER — %s (%d-%d)" % [verdict, player_goals, opponent_goals]
	for btn in opponent_buttons:
		btn.disabled = true
	take_shot_button.visible = false
	opponent_turn_button.visible = false
	next_round_button.visible = false
