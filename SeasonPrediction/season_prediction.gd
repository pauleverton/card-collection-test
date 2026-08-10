extends Control

## Shown once, right after being promoted into a new season — before the
## player can reach the locker room or transfer market (see locker_room.gd,
## which redirects here while LeagueState.season_prediction_shown is false).
##
## Reveals which boss this season's decider match will be against and what
## their signature rule does (e.g. "your midfielder's support bonus won't
## apply"), so the player can plan their transfer window around it BEFORE
## spending coins, rather than finding out on matchday 4.

@onready var tournament_label: Label = $VBoxContainer/TournamentLabel
@onready var boss_label: Label = $VBoxContainer/BossLabel
@onready var effect_label: Label = $VBoxContainer/EffectLabel
@onready var continue_button: Button = $VBoxContainer/ContinueButton


func _ready() -> void:
	tournament_label.text = "Welcome to %s!" % LeagueState.current_tournament_name()

	var boss: BossTeam = LeagueState.current_season_boss
	if boss == null:
		# Shouldn't normally happen — LeagueState only sends the player here
		# once a boss has actually been picked. Fails gracefully just in case.
		boss_label.text = ""
		effect_label.text = "This season's decider opponent hasn't been set yet."
	else:
		boss_label.text = "This season's decider: %s" % boss.boss_name
		var lines: Array[String] = []
		for condition in boss.conditions:
			lines.append(condition.description)
		effect_label.text = "\n".join(lines) if not lines.is_empty() else "No special rules this time — just a tough match."

	continue_button.pressed.connect(_on_continue_pressed)


func _on_continue_pressed() -> void:
	LeagueState.mark_season_prediction_shown()
	get_tree().change_scene_to_file("res://lockerroom.tscn")
