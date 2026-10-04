extends Node
## Autoload: everything that lasts for a whole run (your deck, matches played).
## Register as "RunState" in Project Settings > Globals > Autoload.

const STARTING_DECK := [
	"res://Resources/short_pass.tres", "res://Resources/short_pass.tres", "res://Resources/short_pass.tres",
	"res://Resources/dribble.tres", "res://Resources/dribble.tres",
	"res://Resources/through_ball.tres",
	"res://Resources/overlap.tres", "res://Resources/overlap.tres",
	"res://Resources/cross.tres", "res://Resources/cross.tres",
	"res://Resources/shot.tres",
	"res://Resources/tackle.tres", "res://Resources/tackle.tres",
	"res://Resources/track_back.tres", "res://Resources/track_back.tres",
	"res://Resources/block.tres", "res://Resources/lump_clear.tres",
	"res://Resources/retain_possession.tres"]

## Cards that can be offered as rewards.
const REWARD_POOL := [
	"res://Resources/short_pass.tres", "res://Resources/dribble.tres",
	"res://Resources/through_ball.tres", "res://Resources/overlap.tres",
	"res://Resources/cross.tres", "res://Resources/shot.tres",
	"res://Resources/track_back.tres", "res://Resources/block.tres",
	"res://Resources/lump_clear.tres"]
const REWARD_CHOICES := 3

var deck: Array = []
var matches_played := 0

func _ready() -> void:
	new_run()

func new_run() -> void:
	deck.clear()
	for path in STARTING_DECK:
		deck.append(load(path))
	matches_played = 0

## Three different random cards from the pool.
func reward_options() -> Array:
	var pool := REWARD_POOL.duplicate()
	pool.shuffle()
	var options := []
	for path in pool.slice(0, REWARD_CHOICES):
		options.append(load(path))
	return options

func add_card(card: ActionData) -> void:
	deck.append(card)
