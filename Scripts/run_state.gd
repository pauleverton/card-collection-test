extends Node
## Autoload: everything that lasts for a whole run (your deck, matches played).
## Register as "RunState" in Project Settings > Globals > Autoload.

const STARTING_DECK := [
	"res://Resources/cards/starting_cards/short_pass.tres", "res://Resources/cards/starting_cards/short_pass.tres", "res://Resources/cards/starting_cards/short_pass.tres",
	"res://Resources/cards/starting_cards/dribble.tres", "res://Resources/cards/starting_cards/dribble.tres",
	"res://Resources/cards/starting_cards/through_ball.tres",
	"res://Resources/cards/starting_cards/overlap.tres", "res://Resources/cards/starting_cards/overlap.tres",
	"res://Resources/cards/starting_cards/cross.tres", "res://Resources/cards/starting_cards/cross.tres",
	"res://Resources/cards/starting_cards/shot.tres",
	"res://Resources/cards/starting_cards/tackle.tres", "res://Resources/cards/starting_cards/tackle.tres",
	"res://Resources/cards/starting_cards/track_back.tres", "res://Resources/cards/starting_cards/track_back.tres",
	"res://Resources/cards/starting_cards/block.tres", "res://Resources/cards/starting_cards/lump_clear.tres",
	"res://Resources/cards/starting_cards/retain_possession.tres"]

## Cards that can be offered as rewards.
const REWARD_POOL := [
	"res://Resources/cards/starting_cards/short_pass.tres", "res://Resources/cards/starting_cards/dribble.tres",
	"res://Resources/cards/starting_cards/through_ball.tres", "res://Resources/cards/starting_cards/overlap.tres",
	"res://Resources/cards/starting_cards/cross.tres", "res://Resources/cards/starting_cards/shot.tres","res://Resources/cards/starting_cards/long_shot.tres",
	"res://Resources/cards/starting_cards/track_back.tres", "res://Resources/cards/starting_cards/block.tres",
	"res://Resources/cards/starting_cards/lump_clear.tres"]
const REWARD_CHOICES := 3

var deck: Array = []
var matches_played := 0
var squad: Array = []


func _ready() -> void:
	new_run()

func new_run() -> void:
	deck.clear()
	for path in STARTING_DECK:
		deck.append(load(path))
	matches_played = 0
	squad.clear()
	squad.append(load("res://Resources/Players/the_wall.tres"))     ## TEMPORARY, for testing
	squad.append(load("res://Resources/Players/twinkle_toes.tres"))  ## TEMPORARY, for testing

## Three different random cards from the pool.
func reward_options(count: int = REWARD_CHOICES) -> Array:
	var pool := REWARD_POOL.duplicate()
	pool.shuffle()
	var options := []
	for path in pool.slice(0, count):
		options.append(load(path))
	return options

func add_card(card: ActionCard) -> void:
	deck.append(card)

func add_player(player: PlayerCard) -> void:
	squad.append(player)
	
func squad_bonus(card: ActionCard) -> int:
	var total := 0
	for player in squad:
		total += player.bonus_for(card)
	return total
	
## Names of the players who boost this card (for showing it on screen).
func squad_helpers(card: ActionCard) -> PackedStringArray:
	var names: PackedStringArray = []
	for p in squad:
		if p.bonus_for(card) > 0:
			names.append(p.display_name)
	return names
	
const UPGRADE_BONUS := 2

## Upgrade ONE card in the deck, by its position, without touching any other copies.
func upgrade_card(index: int) -> void:
	var card: ActionCard = deck[index]
	if card.is_upgraded:
		return
	if card.upgrades_to != null:
		deck[index] = card.upgrades_to
	else:
		var upgraded: ActionCard = card.duplicate()
		upgraded.base_value += UPGRADE_BONUS
		upgraded.display_name += "+"
		upgraded.is_upgraded = true
		deck[index] = upgraded
