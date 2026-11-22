extends Node
## Autoload: everything that lasts for a whole run (your deck, matches played).
## Register as "RunState" in Project Settings > Globals > Autoload.
## Every card in this folder goes in the starting deck (each card's Starting Copies says how many).
const STARTING_FOLDER := "res://Resources/cards/starting_cards/"
## Rewards and the training ground offer every card in these folders.
## The upgrade folders are left out on purpose: you only get "+" cards by upgrading.
const REWARD_FOLDERS := [
	"res://Resources/cards/starting_cards/",
	"res://Resources/cards/cards_to_buy/"]
const REWARD_CHOICES := 3
const PLAYER_FOLDER := "res://Resources/players/"
const COACH_FOLDER := "res://Resources/coaches/"

## Chance of each rarity when generating a card or player (Balatro-style:
## roll the rarity first, then pick something of that rarity).
## They don't need to add up to 100: each one is "how many tickets in the hat".
const RARITY_WEIGHTS := {"common": 60, "uncommon": 25, "rare": 12, "special": 3}

var deck: Array = []
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
	for card in _load_folder(STARTING_FOLDER):
		for i in card.starting_copies:
			deck.append(card)
	squad.clear()
	picked.clear()
	team_name = ""
	start_preseason()                ## every run starts with a transfer window
	roll_training()

## Up to `count` different cards from the REWARD_FOLDERS, weighted by rarity.
## (Cards you already own can still appear: you can have several copies.)
func reward_options(count: int = REWARD_CHOICES) -> Array:
	var pool := []
	for folder in REWARD_FOLDERS:
		pool += _load_folder(folder)
	return _pick_by_rarity(pool, count)

## Load every card/staff file in a folder, skipping (with a warning) any that won't load.
## Uses ResourceLoader.list_directory, not DirAccess: in an exported game Godot renames
## .tres files, and DirAccess would find nothing. This one sees through that.
func _load_folder(folder: String) -> Array:
	var loaded := []
	for file in ResourceLoader.list_directory(folder):
		if not (file.ends_with(".tres") or file.ends_with(".res")):
			continue                     ## skips sub-folders (they end in "/") and anything else
		var res = load(folder + file)
		if res == null:
			push_warning("RunState: couldn't load %s%s, skipped" % [folder, file])
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

## Player/coach prices by rarity; selling gets half. One place, so every screen agrees.
const STAFF_PRICE := {"common": 150, "uncommon": 200, "rare": 300, "special": 500}
const HUB_SCENE := "res://Scenes/hub_screen.tscn"
const TRANSFER_SCENE := "res://Scenes/transfer_window_screen.tscn"
## True from the end of a season (or the start of a run) until "Start the season".
var transfer_window_due := false

func staff_price(s: StaffCard) -> int:
	return STAFF_PRICE.get(s.rarity, 150)

func sell_price(s: StaffCard) -> int:
	return int(staff_price(s) / 2.0)

## A season is about to start: fill the transfer window and send the player there next.
func start_preseason() -> void:
	open_transfer_window()
	transfer_window_due = true

## Where to go after the menu, a match or the reward screen: the transfer window when a
## season is about to start, otherwise the hub.
func next_break_screen() -> String:
	return TRANSFER_SCENE if transfer_window_due else HUB_SCENE


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
	var players_left := _load_folder(PLAYER_FOLDER).filter(func(s): return not squad.has(s))
	free_agents = _pick_by_rarity(players_left, TRANSFER_FREE, FREE_RARITY_WEIGHTS)
	_roll_transfer_list()

func _roll_transfer_list() -> void:
	var pool := (_load_folder(PLAYER_FOLDER) + _load_folder(COACH_FOLDER)).filter(
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

const MIN_DECK := 8               ## Cut can't take the deck below this
var week_choice := ""             ## "" = not decided yet, "train" or "rest" (reset every week)
var rest_message := ""            ## shown once on the team sheet after a rest day
var last_result := {}             ## {scored, conceded, opponent}: the match just played (reward screen)
## Cards offered on the reward screen and in a new-card training week. Rolled once (when a match
## is won, or the week starts) and saved, so reloading can't re-roll them.
var reward_offers: Array = []
var training_offers: Array = []
## The dice for the next match: picked on Kick off and saved, so quitting mid-match and
## continuing replays it with the same luck.
var match_seed := 0



## A new week: roll this week's activity; nothing chosen yet.
func roll_training() -> void:
	training_activity = _weighted_pick(TRAINING_WEIGHTS)
	week_choice = ""
	training_offers = reward_options(TRAINING_NEW_CARDS) if training_activity == "new_card" else []	

## Why this week's activity can't be done ("" = it can).
func training_blocked_reason() -> String:
	match training_activity:
		"upgrade":
			if not deck.any(func(c): return c.can_upgrade()):
				return "Nothing in your deck can be upgraded yet."
		"cut":
			if deck.size() <= MIN_DECK:
				return "Your deck can't go below %d cards." % MIN_DECK
	return ""

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
	var tired := players().filter(func(player): return LeagueState.appearances_left(player) < player.max_appearances())
	if tired.is_empty():
		return null
	var p: PlayerCard = tired.pick_random()
	LeagueState.give_appearance(p)
	return p

## Duplicate week: a second copy of one deck card, placed next to it.
func duplicate_card(index: int) -> void:
	deck.insert(index + 1, deck[index])
	
	
	

# ---------- Saving (save_state.gd decides where and when) ----------

## Write this run's deck, squad and week down. Cards and staff go in as file paths.
func save_to(cfg: ConfigFile) -> void:
	cfg.set_value("run", "deck", SaveState.paths(deck))
	cfg.set_value("run", "squad", SaveState.paths(squad))
	cfg.set_value("run", "picked", SaveState.paths(picked))
	cfg.set_value("run", "team_name", team_name)
	cfg.set_value("run", "transfer_window_due", transfer_window_due)
	cfg.set_value("run", "transfer_list", SaveState.paths(transfer_list))
	cfg.set_value("run", "free_agents", SaveState.paths(free_agents))
	cfg.set_value("run", "scouts_used", scouts_used)
	cfg.set_value("run", "training_activity", training_activity)
	cfg.set_value("run", "week_choice", week_choice)
	cfg.set_value("run", "rest_message", rest_message)
	cfg.set_value("run", "last_result", last_result)
	cfg.set_value("run", "reward_offers", SaveState.paths(reward_offers))
	cfg.set_value("run", "training_offers", SaveState.paths(training_offers))
	cfg.set_value("run", "match_seed", match_seed)

## Read it back (the second value in each get_value is what to use if it's missing).
func load_from(cfg: ConfigFile) -> void:
	deck = SaveState.load_paths(cfg.get_value("run", "deck", []))
	squad = SaveState.load_paths(cfg.get_value("run", "squad", []))
	picked = SaveState.load_paths(cfg.get_value("run", "picked", []))
	tidy_picked()
	team_name = cfg.get_value("run", "team_name", "")
	transfer_window_due = cfg.get_value("run", "transfer_window_due", false)
	transfer_list = SaveState.load_paths(cfg.get_value("run", "transfer_list", []))
	free_agents = SaveState.load_paths(cfg.get_value("run", "free_agents", []))
	scouts_used = cfg.get_value("run", "scouts_used", 0)
	training_activity = cfg.get_value("run", "training_activity", "")
	week_choice = cfg.get_value("run", "week_choice", "")
	rest_message = cfg.get_value("run", "rest_message", "")
	last_result = cfg.get_value("run", "last_result", {})
	reward_offers = SaveState.load_paths(cfg.get_value("run", "reward_offers", []))
	training_offers = SaveState.load_paths(cfg.get_value("run", "training_offers", []))
	match_seed = cfg.get_value("run", "match_seed", 0)
