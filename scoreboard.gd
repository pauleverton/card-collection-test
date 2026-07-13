# scoreboard.gd
extends VBoxContainer

@onready var coins_label = $CoinsLabel
@onready var score_label = $ScoreLabel

func update_display(coins: int, score: int) -> void:
	coins_label.text = "Coins: " + str(coins)
	score_label.text = "Score: " + str(score)
