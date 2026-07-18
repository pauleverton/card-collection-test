# main.gd
extends Node

var coins = 100
var score = 0

func _enter_tree() -> void:
	add_to_group("main")

func _ready() -> void:
	update_scoreboard()

func add_coins(amount: int) -> void:
	coins += amount
	update_scoreboard()
	coins_changed.emit(coins)

func deduct_coins(amount: int) -> void:
	coins -= amount
	update_scoreboard()
	coins_changed.emit(coins)

func add_score(amount: int) -> void:
	score += amount
	update_scoreboard()
	
func spin_player(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	update_scoreboard()
	coins_changed.emit(coins) 
	return true

func update_scoreboard() -> void:
	if $ScoreBoard == null:
		print("ScoreBoard node not found")
		return
	$ScoreBoard.update_display(coins, score)

signal coins_changed(new_amount: int)
