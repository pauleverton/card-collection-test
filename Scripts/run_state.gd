extends Node
## Autoload: everything that lasts for a whole run (your deck, matches played).
## Register as "RunState" in Project Settings > Globals > Autoload.

const STARTING_DECK := [
	"res://Resources/cards/starting_cards/short_pass.tres", 
	"res://Resources/cards/starting_cards/short_pass.tres", 
	"res://Resources/cards/starting_cards/short_pass.tres",
	"res://Resources/cards/starting_cards/dribble.tres", 
	"res://Resources/cards/starting_cards/through_ball.tres",
	"res://Resources/cards/starting_cards/overlap.tres", 
	"res://Resources/cards/starting_cards/cross.tres",
	"res://Resources/cards/starting_cards/shoot.tres",
	"res://Resources/cards/starting_cards/shoot.tres",
	"res://Resources/cards/starting_cards/tackle.tres", 
	"res://Resources/cards/starting_cards/tackle.tres",
	"res://Resources/cards/starting_cards/track_back.tres", 
	"res://Resources/cards/starting_cards/track_back.tres",
	"res://Resources/cards/starting_cards/block.tres",
	"res://Resources/cards/starting_cards/lump_clear.tres",
	"res://Resources/cards/starting_cards/retain_possession.tres"]

## Cards that can be offered as rewards.
const REWARD_POOL := [
	"res://Resources/cards/starting_cards/short_pass.tres", 
	"res://Resources/cards/starting_cards/dribble.tres",
	"res://Resources/cards/starting_cards/through_ball.tres", 
	"res://Resources/cards/starting_cards/overlap.tres",
	"res://Resources/cards/starting_cards/cross.tres", 
	"res://Resources/cards/starting_cards/shoot.tres",
	"res://Resources/cards/cards_to_buy/long_shot.tres",
	"res://Resources/cards/starting_cards/track_back.tres", 
	"res://Resources/cards/starting_cards/block.tres",
	"res://Resources/cards/starting_cards/lump_clear.tres"]
const REWARD_CHOICES := 3

const PLAYER_POOL:= [
	"res://Resources/players/the_wall.tres",
	"res://Resources/players/twinkle_toes.tres",
	"res://Resources/players/stopper.tres"]
	
const COACH_POOL:= [
	"res://Resources/coaches/attacking_coach.tres",
	"res://Resources/coaches/assistant_manager.tres"]

var deck: Array = []
var matches_played := 0
var squad: Array = []          ## players AND coaches
const MAX_PLAYERS := 5
const MAX_COACHES := 2

func players() -> Array:
	return squad.filter(func(s): return s is PlayerCard)

func coaches() -> Array:
	return squad.filter(func(s): return s is CoachCard)

## Is there room for this one? (players and coaches have separate limits)
func squad_full_for(staff: StaffCard) -> bool:
	if staff is CoachCard:
		return coaches().size() >= MAX_COACHES
	return players().size() >= MAX_PLAYERS

func _ready() -> void:
	new_run()

func new_run() -> void:
	deck.clear()
	for path in STARTING_DECK:
		deck.append(load(path))
	matches_played = 0
	squad.clear()

## Three different random cards from the pool.
func reward_options(count: int = REWARD_CHOICES) -> Array:
	var pool := REWARD_POOL.duplicate()
	pool.shuffle()
	var options := []
	for path in pool.slice(0, count):
		options.append(load(path))
	return options

## Up to `count` random players/coaches you don't already own.
func staff_for_sale(count: int = 1) -> Array:
	var pool: Array = PLAYER_POOL + COACH_POOL
	pool.shuffle()
	var options := []
	for path in pool:
		var staff: StaffCard = load(path)
		if staff in squad:
			continue
		options.append(staff)
		if options.size() == count:
			break
	return options

func add_card(card: ActionCard) -> void:
	deck.append(card)

func remove_card(card: ActionCard) -> void:
	deck.erase(card)

func add_player(staff: StaffCard) -> void:
	squad.append(staff)

func remove_player(staff: StaffCard) -> void:
	squad.erase(staff)

func squad_bonus(card: ActionCard) -> int:
	var total := 0
	for p in players():
		total += p.bonus_for(card)
	return total

## All matching player multipliers, multiplied together.
func squad_multiplier(card: ActionCard) -> float:
	var total := 1.0
	for p in players():
		if p.applies_to(card):
			total *= p.multiplier
	return total

## Extra triggers a played card gets from coaches.
func retriggers_for_card(card: ActionCard) -> int:
	var total := 0
	for c in coaches():
		if c.applies_to(card):
			total += c.retriggers
	return total

## Extra triggers a coach EFFECT of this category gets (only coaches without a tag filter count).
func retriggers_for_type(type: String) -> int:
	var total := 0
	for c in coaches():
		if c.boosts_tags == "any" and c.applies_to_type(type):
			total += c.retriggers
	return total

## Coaches whose effect fires at this moment ("on_goal", …).
func coaches_for(when: String) -> Array:
	return coaches().filter(func(c): return c.when == when)

## Names of everyone who boosts this card (for the commentary).
func squad_helpers(card: ActionCard) -> PackedStringArray:
	var names: PackedStringArray = []
	for s in squad:
		if s.affects(card):
			names.append(s.display_name)
	return names
	
## Swap ONE deck slot for its hand-made upgraded version.
func upgrade_card(index: int) -> void:
	var card: ActionCard = deck[index]
	if card.can_upgrade():
		deck[index] = card.upgrades_to
