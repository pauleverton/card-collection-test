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

## Cards that can be offered as rewards, on the shop shelf and in packs.
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
	"res://Resources/players/stopper.tres",
	"res://Resources/players/super_sub.tres",
	"res://Resources/players/kitchen_sink.tres",
	"res://Resources/players/park_the_bus.tres"]
	
const COACH_POOL:= [
	"res://Resources/coaches/attacking_coach.tres",
	"res://Resources/coaches/assistant_manager.tres"]

## Chance of each rarity when generating a card or player (Balatro-style:
## roll the rarity first, then pick something of that rarity).
## They don't need to add up to 100: each one is "how many tickets in the hat".
const RARITY_WEIGHTS := {"common": 60, "uncommon": 25, "rare": 12, "special": 3}

var deck: Array = []
var matches_played := 0
var squad: Array = []          ## players AND coaches
var team_name := ""            ## built on the main menu; "" = use the default name
## Set when a run ends: the main menu then opens the team name box straight away.
var start_with_team_name := false
const MAX_PLAYERS := 7         ## players you can OWN
## How many of your players take the pitch in one match. Coaches don't count: they always play.
const MATCHDAY_PLAYERS := 3
## The players picked for the next match (always a subset of the players in `squad`).
var picked: Array = []
const MAX_COACHES := 2
## The shop's stock for the current break between matches. Rolled once by
## restock_shop() (new run, and after every match), so leaving the shop and
## coming back shows the same shelf. The pack and the upgrade are once per break.
const SHOP_CARDS := 3
const SHOP_STAFF := 3
var shop_cards: Array = []
var shop_staff: Array = []
var shop_pack_opened := false
var shop_upgrade_used := false

func restock_shop() -> void:
	shop_cards = reward_options(SHOP_CARDS)
	shop_staff = staff_for_sale(SHOP_STAFF)
	shop_pack_opened = false
	shop_upgrade_used = false

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
	picked.clear()
	team_name = ""
	restock_shop()

## Up to `count` different cards from REWARD_POOL, weighted by rarity.
## (Cards you already own can still appear: you can have several copies.)
func reward_options(count: int = REWARD_CHOICES) -> Array:
	return _pick_by_rarity(_load_pool(REWARD_POOL), count)

## Up to `count` different players/coaches you don't already own, weighted by rarity.
func staff_for_sale(count: int = 1) -> Array:
	var available := _load_pool(PLAYER_POOL + COACH_POOL).filter(
		func(s): return not squad.has(s))
	return _pick_by_rarity(available, count)

## Load every path in a pool, skipping (with a warning) any file that won't load.
func _load_pool(paths: Array) -> Array:
	var loaded := []
	for path in paths:
		var res = load(path)
		if res == null:
			push_warning("RunState: couldn't load %s, skipped" % path)
			continue
		loaded.append(res)
	return loaded

## Cards store their rarity as `card_rarity`, staff as `rarity`.
func _rarity_of(item: Resource) -> String:
	if item is ActionCard:
		return item.card_rarity
	return item.rarity

## Pick up to `count` different items. Each slot rolls a rarity first (using `weights`),
## then picks something of that rarity.
func _pick_by_rarity(items: Array, count: int, weights: Dictionary = RARITY_WEIGHTS) -> Array:
	## Sort into piles by rarity: {"common": [...], "uncommon": [...]}
	var piles := {}
	for item in items:
		var r := _rarity_of(item)
		if not piles.has(r):
			piles[r] = []
		piles[r].append(item)

	var chosen := []
	while chosen.size() < count and not piles.is_empty():
		var rarity := roll_rarity(piles.keys(), weights)
		var pile: Array = piles[rarity]
		var item = pile.pick_random()
		chosen.append(item)
		pile.erase(item)               ## no duplicates in one offer
		if pile.is_empty():
			piles.erase(rarity)        ## nothing left of that rarity: stop rolling it
	return chosen

## Pick one rarity from `available`, using `weights` (RARITY_WEIGHTS unless told otherwise).
## Only pass rarities that still have something in them.
func roll_rarity(available: Array, weights: Dictionary = RARITY_WEIGHTS) -> String:
	var total := 0
	for r in available:
		total += weights.get(r, 0)
	if total == 0:
		return available.pick_random()   ## e.g. a typo'd rarity: just pick any
	var roll := randi_range(1, total)
	for r in available:
		roll -= weights.get(r, 0)
		if roll <= 0:
			return r
	return available.back()

func add_card(card: ActionCard) -> void:
	deck.append(card)

func remove_card(card: ActionCard) -> void:
	deck.erase(card)

func add_player(staff: StaffCard) -> void:
	squad.append(staff)
	## A new player goes straight into the team if there's room (change it on the team sheet).
	if staff is PlayerCard and match_players().size() < MATCHDAY_PLAYERS:
		picked.append(staff)

func remove_player(staff: StaffCard) -> void:
	squad.erase(staff)
	picked.erase(staff)

## The players actually playing the next match (picked AND still owned).
func match_players() -> Array:
	return picked.filter(func(p): return squad.has(p))

## Everyone taking part in a match: the picked players plus every coach.
func match_squad() -> Array:
	return match_players() + coaches()

## Drop anyone from the team who has been sold or has no games left this season.
func tidy_picked() -> void:
	picked = match_players().filter(func(p): return LeagueState.appearances_left(p) > 0)

## Kick-off: tidy the team, then everyone still picked uses up one appearance.
func start_match_day() -> void:
	tidy_picked()
	for p in picked:
		LeagueState.use_appearance(p)

func squad_bonus(card: ActionCard) -> int:
	var total := 0
	for p in match_players():
		total += p.bonus_for(card)
	return total

## All matching player multipliers, multiplied together.
func squad_multiplier(card: ActionCard) -> float:
	var total := 1.0
	for p in match_players():
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
	for s in match_squad():
		if s.affects(card):
			names.append(s.display_name)
	return names
	
## Swap ONE deck slot for its hand-made upgraded version.
func upgrade_card(index: int) -> void:
	var card: ActionCard = deck[index]
	if card.can_upgrade():
		deck[index] = card.upgrades_to

# ---------- Transfer window (once a season, before round 1) ----------

const TRANSFER_PAID := 3          ## players and coaches on the transfer list
const TRANSFER_FREE := 2          ## free agents (players only, never coaches)
## Free agents lean hard towards common, but anything can turn up.
const FREE_RARITY_WEIGHTS := {"common": 85, "uncommon": 12, "rare": 2, "special": 1}
const SCOUT_BASE := 25            ## the first "Scout again" in a window
const SCOUT_STEP := 10            ## each one after that costs this much more
var transfer_list: Array = []
var free_agents: Array = []
var scouts_used := 0

## Fill the window: free agents first, then the transfer list (never the same player twice).
func open_transfer_window() -> void:
	scouts_used = 0
	var players_left := _load_pool(PLAYER_POOL).filter(func(s): return not squad.has(s))
	free_agents = _pick_by_rarity(players_left, TRANSFER_FREE, FREE_RARITY_WEIGHTS)
	_roll_transfer_list()

func _roll_transfer_list() -> void:
	var pool := _load_pool(PLAYER_POOL + COACH_POOL).filter(
			func(s): return not squad.has(s) and not free_agents.has(s))
	transfer_list = _pick_by_rarity(pool, TRANSFER_PAID)

func scout_cost() -> int:
	return SCOUT_BASE + SCOUT_STEP * scouts_used

## New names on the transfer list; free agents stay. The screen checks and takes the coins.
func scout_again() -> void:
	scouts_used += 1
	_roll_transfer_list()

# ---------- Training (between matches) ----------

const TRAINING_COST := 50
## This week's activity is picked with these weights (repeats allowed).
const TRAINING_WEIGHTS := {"new_card": 35, "upgrade": 30, "cut": 25, "duplicate": 10}
const TRAINING_NEW_CARDS := 3     ## new card week: pick 1 of this many
var training_activity := ""       ## "new_card", "upgrade", "cut" or "duplicate"

func roll_training() -> void:
	training_activity = _weighted_pick(TRAINING_WEIGHTS)

## One key from {key: weight}, chosen by weight.
func _weighted_pick(weights: Dictionary) -> String:
	var total := 0
	for k in weights:
		total += weights[k]
	var roll := randi_range(1, total)
	for k in weights:
		roll -= weights[k]
		if roll <= 0:
			return k
	return weights.keys().back()

## Skipping training: a random player who has played this season gets +1 game.
## Returns him, or null if everyone is fresh.
func rest_day() -> PlayerCard:
	var tired := players().filter(func(p): return LeagueState.appearances_left(p) < p.max_appearances())
	if tired.is_empty():
		return null
	var p: PlayerCard = tired.pick_random()
	LeagueState.give_appearance(p)
	return p

## Duplicate week: a second copy of one deck card, placed next to it.
func duplicate_card(index: int) -> void:
	deck.insert(index + 1, deck[index])
