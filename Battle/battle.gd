extends Control

## Minimal test harness for BattleManager. Wires up the Start button, three
## opponent target buttons, and result/score/round labels so you can run
## this scene directly (F6) and try a full match end-to-end.
##
## Once DrawCards/squad-building is ready, swap out the hardcoded
## TEST_PLAYER_SQUAD below for whatever the player actually built.

@onready var battle_manager: BattleManager = $BattleManager
@onready var round_label: Label = $VBoxContainer/RoundLabel
@onready var score_label: Label = $VBoxContainer/ScoreLabel
@onready var result_label: Label = $VBoxContainer/ResultLabel
@onready var start_button: Button = $VBoxContainer/StartButton
@onready var opponent_buttons: Array[Button] = [
	$VBoxContainer/OpponentRow/Button1,
	$VBoxContainer/OpponentRow/Button2,
	$VBoxContainer/OpponentRow/Button3
]

# Swap this for real squad-builder output later.
const TEST_PLAYER_SQUAD: Array[String] = [
	"james_garner_bronze",
	"jake_obrien_bronze",
	"iliman_ndiaye_silver"
]

var opponent_squad: Array[String] = []


func _ready() -> void:
	battle_manager.round_started.connect(_on_round_started)
	battle_manager.shot_resolved.connect(_on_shot_resolved)
	battle_manager.match_ended.connect(_on_match_ended)

	start_button.pressed.connect(_on_start_pressed)

	for i in range(opponent_buttons.size()):
		opponent_buttons[i].pressed.connect(_on_opponent_button_pressed.bind(i))

	result_label.text = ""
	score_label.text = ""
	round_label.text = ""


func _on_start_pressed() -> void:
	opponent_squad = SquadGenerator.generate_random_squad(3)
	_refresh_opponent_buttons()
	result_label.text = "Match started!"
	score_label.text = "You: 0   Opponent: 0"
	battle_manager.start_match(TEST_PLAYER_SQUAD, opponent_squad)


func _refresh_opponent_buttons() -> void:
	for i in range(opponent_buttons.size()):
		if i < opponent_squad.size():
			opponent_buttons[i].text = opponent_squad[i]
			opponent_buttons[i].disabled = false
		else:
			opponent_buttons[i].disabled = true


func _on_opponent_button_pressed(index: int) -> void:
	if index >= opponent_squad.size():
		return
	battle_manager.player_take_shot(opponent_squad[index])


func _on_round_started(round_number: int) -> void:
	round_label.text = "Round %d / %d" % [round_number, battle_manager.total_rounds]


func _on_shot_resolved(attacker_id: String, defender_id: String, roll: int, chance: int, scored: bool) -> void:
	var outcome := "GOAL!" if scored else "Missed"
	result_label.text = "%s shoots at %s — rolled %d vs %d%% chance — %s" % [
		attacker_id, defender_id, roll, chance, outcome
	]
	score_label.text = "You: %d   Opponent: %d" % [battle_manager.player_goals, battle_manager.opponent_goals]


func _on_match_ended(player_goals: int, opponent_goals: int, player_won: bool) -> void:
	var verdict := "You win!" if player_won else "You lose."
	result_label.text += "\n\nMATCH OVER — %s (%d-%d)" % [verdict, player_goals, opponent_goals]
	for btn in opponent_buttons:
		btn.disabled = true
