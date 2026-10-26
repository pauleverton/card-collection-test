class_name MatchRules
extends RefCounted

## Zones: 0 = your box, 1 = your half, 2 = midfield, 3 = their half, 4 = their box
const ZONE_NAMES := ["Your box", "Your half", "Midfield", "Their half", "Their box"]
const START_ENERGY := 5
const POSSESSION_DRAW := 2   ## cards drawn every time the ball changes hands
## Each zone's target = opponent strength × this. Index = zone (0 your box … 4 their box).
const PRESS_WEIGHT := [0.8, 0.9, 1.0, 1.2, 1.0]
const ATTACK_WEIGHT := [1.0, 1.2, 1.0, 0.9, 0.8]

var strength := 40


## --- You attacking: their box ---
const BOX_DEFENCE_DECK := ["block", "block", "block", "tackle", "tackle",
		"clearance", "clearance", "slip", "slip"]
const DEFENDER_TEXT := {
	"tackle": "Tackle (-30 on the ground, can't stop a cross)",
	"block": "Block (-20, but a dribble goes round him)",
	"clearance": "Header (wins a cross if chance 40 or less, no use on the ground)",
	"slip": "Slip (no effect)"}
## How much each defender takes off your chance, depending on which card you played.
const DEFENDER_EFFECT := {
	"tackle":    {"pass": 30, "dribble": 30, "cross": 0},
	"block":     {"pass": 20, "dribble": 0, "cross": 20},
	"clearance": {"pass": 0, "dribble": 0, "cross": 20},
	"slip":      {"pass": 0, "dribble": 0, "cross": 0}}
const CLEARED := 99   ## a special result meaning "the defender wins the ball"
const BOX_HAND_SIZE := 3
const CLEARANCE_LIMIT := 40
const BOX_WORK_VALUE := 10   ## what Pass and Dribble add inside the box
const KEEPER_DECK := [20, 30, 30, 40, 40, 50, 50, 60, 70]
const SHOT_COST := 1
const BOX_ENERGY := 3
const BASIC_SHOT_ROLL_MAX := 40   ## a basic shot adds a random 0 to this...
const BASIC_SHOT_ROLL_STEP := 10  ## ...in steps of this (0, 10, 20, 30, 40)

## --- Them attacking ---
const THEIR_CHANCE_DECK := [30, 40, 40, 50, 50, 60, 60, 70]
const OUR_KEEPER_DECK := [20, 30, 30, 40, 40, 50, 50, 60, 70]
const MIN_THEIR_CHANCE := 30   ## you can never block a chance down to nothing

## --- Match clock and rewards ---
const MATCH_LENGTH := 90
const MINUTES_PER_ACTION := 3
const COINS_WIN := 100
const COINS_DRAW := 50
const COINS_LOSS := 20
const COINS_PER_GOAL := 10

var zone := 2
var energy := START_ENERGY
## true = you're attacking, false = they're attacking
var has_ball := true
## The number to beat: their Press when you attack, their Attack when they do.
var target := 0
## Bonus waiting for the next card (from Overlap, later from players).
var next_bonus := 0
## The chance in whichever box the ball is in: yours to raise, or theirs to lower.
var quality := 0
var build := 0
var goals := 0
var conceded := 0
var bonus_coins:=0
var _their_chance_pile: Array = []
var _box_hand: Array = []
var _box_defence_pile: Array = []
var _keeper_pile: Array = []
var _our_keeper_pile: Array = []
var minute := 0
var match_over := false

func start() -> void:
	zone = 2
	goals = 0
	conceded = 0
	has_ball = true
	energy = START_ENERGY
	next_bonus = 0
	quality = 0
	bonus_coins=0
	strength = LeagueState.opponent_strength()
	_flip_press()
	minute = 0
	match_over = false


# ---------- Questions the screen can ask ----------

func in_their_box() -> bool:
	return has_ball and zone == 4

func in_our_box() -> bool:
	return not has_ball and zone == 0

func defenders_left() -> int:
	return _box_hand.size()

## The defenders still to come, in the order they'll respond.
func upcoming_defenders() -> Array:
	return _box_hand.duplicate()

## Percentage chance YOUR shot of this quality beats their keeper.
func goal_odds(shot_quality: int) -> int:
	return _odds_to_beat(shot_quality, _keeper_pile, KEEPER_DECK)
	
## Average chance of scoring with the Shoot button, across every possible roll.
func basic_shot_odds() -> int:
	var total := 0
	for roll in range(0, BASIC_SHOT_ROLL_MAX + 1, BASIC_SHOT_ROLL_STEP):
		total += goal_odds(quality + roll)
	return roundi(float(total) / (BASIC_SHOT_ROLL_MAX / BASIC_SHOT_ROLL_STEP + 1))

## Percentage chance THEIR current chance beats your keeper.
func their_goal_odds() -> int:
	return _odds_to_beat(quality, _our_keeper_pile, OUR_KEEPER_DECK)

func power_of(card: ActionCard) -> int:
	var triggers := 1 + RunState.retriggers_for_card(card)
	var flat := (card.base_value + RunState.squad_bonus(card)) * triggers + next_bonus
	return roundi(flat * pow(RunState.squad_multiplier(card), triggers))

## Can this card be played in the current possession?
func is_right_phase(card: ActionCard) -> bool:
	match card.usable_when:
		"attacking":
			return has_ball
		"defending":
			return not has_ball
	return true

## Can this card do anything where the ball is right now?
func can_play_here(card: ActionCard) -> bool:
	if match_over or not is_right_phase(card):
		return false
	if card.play_zones != 0:
		return card.play_zones & (1 << zone) != 0
	if card.tag in ["retain", "overlap"]:
		return true
	if card.tag == "lump_clear":
		return zone <= 1
	if has_ball:
		if zone == 4:
			return card.tag in ["pass", "dribble", "cross", "shot"]
		return card.tag in ["pass", "dribble", "long_ball"]
	if zone == 0:
		return card.tag in ["block", "tackle"]
	return card.tag in ["tackle", "track_back"]
	
## True if the card would get you through (used for the green tint).
func would_succeed(card: ActionCard) -> bool:
	if not can_play_here(card):
		return false
	if card.tag in ["retain", "overlap", "lump_clear"]:
		return true
	if has_ball and zone == 4:
		if card.tag == "shot":
			return true
		return box_gain(card) - next_defender_effect(card) > 0
	if not has_ball and zone == 0:
		return quality > MIN_THEIR_CHANCE
	return build + power_of(card) >= target
	
## How much the NEXT defender would take off if you played this card (CLEARED = they win it).
func next_defender_effect(card: ActionCard) -> int:
	if _box_hand.is_empty():
		return 0
	var d: String = _box_hand[0]
	if d == "clearance" and card.tag == "cross" and quality <= CLEARANCE_LIMIT:
		return CLEARED
	return DEFENDER_EFFECT[d].get(card.tag, 0)

## What this card adds to your chance in the box, before the defender responds.
func box_gain(card: ActionCard) -> int:
	var amount: int = card.base_value if card.tag == "cross" else BOX_WORK_VALUE
	return amount + next_bonus + RunState.squad_bonus(card)
	

# ---------- Actions ----------

func play(card: ActionCard) -> Array:
	var events := []
	if match_over:
		events.append({"type": "not_now"})
		return events
	if card.energy_cost > energy:
		events.append({"type": "no_energy"})
		return events
	if not is_right_phase(card):
		events.append({"type": "wrong_side", "card": card.display_name})
		return events
	if not can_play_here(card):
		events.append({"type": "not_here", "card": card.display_name})
		return events
	energy -= card.energy_cost
	DeckState.play(card)   ## the card leaves your hand as soon as it's played
	if card.tag == "overlap":
		next_bonus += card.base_value
		events.append({"type": "bonus", "next_bonus": next_bonus})
	elif card.tag == "retain":
		energy += card.energy_boost
		DeckState.draw(card.draw_count)
		events.append({"type": "retain", "energy": card.energy_boost, "drew": card.draw_count})
	elif card.tag == "lump_clear":
		_lump_clear(card, events)
	elif in_their_box():
		_play_in_box(card, events)
	elif has_ball:
		_play_in_build_up(card, events)
	elif in_our_box():
		_defend_in_box(card, events)
	else:
		_defend_build_up(card, events)
	_check_out_of_energy(events)
	_tick_clock(events)
	return events

func take_shot() -> Array:
	var events := []
	if match_over:
		events.append({"type": "not_now"})
		return events
	if not in_their_box():
		events.append({"type": "not_now"})
		return events
	if energy < SHOT_COST:
		events.append({"type": "no_energy"})
		return events
	energy -= SHOT_COST
	var roll := randi_range(0, BASIC_SHOT_ROLL_MAX / BASIC_SHOT_ROLL_STEP) * BASIC_SHOT_ROLL_STEP
	quality += roll
	events.append({"type": "basic_shot", "roll": roll, "quality": quality})
	_shoot(events)
	_check_out_of_energy(events)
	_tick_clock(events)
	return events

## Defending: don't challenge, let them carry on (or shoot, if they're in your box).
func let_them_through() -> Array:
	var events := []
	if match_over:
		events.append({"type": "not_now"})
		return events
	if has_ball:
		events.append({"type": "not_now"})
		return events
	elif zone == 0:
		_their_shot(events)
	else:
		_they_advance(events)
	_check_out_of_energy(events)
	_tick_clock(events)
	return events

# ---------- You attacking: build-up ----------

func _play_in_build_up(card: ActionCard, events: Array) -> void:
	match card.tag:
		"pass", "dribble", "long_ball":
			_attempt_move(card, events)
			if card.tag == "dribble":
				DeckState.draw(1)
				events.append({"type": "drew"})
		"long_shot":
			_long_shot(card, events)
		_:
			events.append({"type": "wrong_phase", "card": card.display_name})
			
func _attempt_move(card: ActionCard, events: Array) -> void:
	var power := power_of(card)
	next_bonus = 0
	build += power
	events.append({"type": "build", "card": card.display_name, "power": power,
			"build": build, "target": target, "helpers": RunState.squad_helpers(card)})
	## Break through as many zones as the build-up allows; any overflow carries on.
	while build >= target and zone < 4:
		var overflow := build - target
		zone += 1
		events.append({"type": "advance", "zone": ZONE_NAMES[zone]})
		if zone == 4:
			_enter_box(overflow, events)
			return
		_flip_press()             ## empties the bar and reveals the new press...
		build = overflow          ## ...then the overflow goes in
		if build > 0:
			events.append({"type": "carry", "build": build, "target": target})

func _long_shot(card: ActionCard, events: Array) -> void:
	events.append({"type": "long_shot", "card": card.display_name, "chance": roundi(card.chance * 100)})
	if _roll(card):
		_score_goal(events)
	else:
		events.append({"type": "long_shot_miss"})
		zone = 4
		_start_their_possession()
		
func _flip_press() -> void:
	build = 0
	target = roundi(strength * PRESS_WEIGHT[zone])

# ---------- You attacking: their box ----------

func _enter_box(start_quality: int, events: Array) -> void:
	energy = BOX_ENERGY
	quality = start_quality
	_box_hand.clear()
	for i in BOX_HAND_SIZE:
		_box_hand.append(_draw_from(_box_defence_pile, BOX_DEFENCE_DECK))
	events.append({"type": "in_the_box", "quality": quality})

func _play_in_box(card: ActionCard, events: Array) -> void:
	match card.tag:
		"pass", "dribble", "cross":
			quality += box_gain(card)
			next_bonus = 0
			events.append({"type": "quality", "card": card.display_name, "quality": quality})
			_defender_responds(card, events)
		"shot":
			quality += card.base_value + next_bonus
			next_bonus = 0
			_shoot(events)
		_:
			events.append({"type": "wrong_phase", "card": card.display_name})

func _defender_responds(card: ActionCard, events: Array) -> void:
	if _box_hand.is_empty():
		events.append({"type": "no_defenders"})
		return
	var effect := next_defender_effect(card)
	var d: String = _box_hand.pop_front()
	if effect == CLEARED:
		events.append({"type": "headed_clear"})
		_turnover(events)
		return
	quality = max(0, quality - effect)
	events.append({"type": "defender", "card": d, "effect": effect, "quality": quality})

func _shoot(events: Array) -> void:
	var save: int = _draw_from(_keeper_pile, KEEPER_DECK)
	events.append({"type": "shot", "quality": quality, "save": save})
	if quality > save:
		_score_goal(events)
	elif quality == save:
		quality = 20
		energy += 1
		events.append({"type": "corner"})
	else:
		events.append({"type": "saved"})
		_turnover(events)

## Everything that happens when you score, in one place.
func _score_goal(events: Array) -> void:
	goals += 1
	events.append({"type": "goal", "goals": goals})
	fire_coaches("on_goal", events)
	zone = 2
	_start_their_possession()

# ---------- Them attacking ----------

## Boot it upfield from your own box or half. They end up with the ball, but far from your goal.
func _lump_clear(card: ActionCard, events: Array) -> void:
	if zone > 1:
		events.append({"type": "wrong_phase", "card": card.display_name})
		return
	var we_had_it := has_ball
	zone = min(zone + card.base_value, 4)
	events.append({"type": "lumped", "zone": ZONE_NAMES[zone]})
	if we_had_it:
		_start_their_possession()
	else:
		_flip_attack()   ## they keep it, but have to start again from here

func _defend_build_up(card: ActionCard, events: Array) -> void:
	match card.tag:
		"tackle", "track_back":
			var power := power_of(card)
			next_bonus = 0
			build += power
			events.append({"type": "hold", "card": card.display_name, "power": power,
					"build": build, "target": target, "helpers": RunState.squad_helpers(card)})
			if build >= target:
				_win_ball(events)
		_:
			events.append({"type": "wrong_phase", "card": card.display_name})
			
func _they_advance(events: Array) -> void:
	zone -= 1
	events.append({"type": "they_advance", "zone": ZONE_NAMES[zone]})
	if zone == 0:
		_set_their_chance()
		events.append({"type": "they_in_box", "quality": quality})
	else:
		_flip_attack()

func _flip_attack() -> void:
	build = 0
	target = roundi(strength * ATTACK_WEIGHT[zone])
	
func _set_their_chance() -> void:
	quality = _draw_from(_their_chance_pile, THEIR_CHANCE_DECK)

func _defend_in_box(card: ActionCard, events: Array) -> void:
	match card.tag:
		"block", "tackle":
			var power := power_of(card)
			next_bonus = 0
			quality = max(MIN_THEIR_CHANCE, quality - power)
			events.append({"type": "blocked", "card": card.display_name, "quality": quality})
		_:
			events.append({"type": "wrong_phase", "card": card.display_name})

func _their_shot(events: Array) -> void:
	var save: int = _draw_from(_our_keeper_pile, OUR_KEEPER_DECK)
	events.append({"type": "their_shot", "quality": quality, "save": save})
	if quality > save:
		conceded += 1
		events.append({"type": "conceded", "conceded": conceded})
		zone = 2
		events.append({"type": "kick_off"})
		_start_our_possession(events)
	else:
		events.append({"type": "our_save"})
		_win_ball(events)

# ---------- Changing possession ----------

## After every action: if you're attacking and can't do anything, you lose the ball.
func _check_out_of_energy(events: Array) -> void:
	if not has_ball:
		return
	if energy == 0:
		_turnover(events)
	elif zone < 4 and not _has_playable_card():
		events.append({"type": "no_options"})
		_turnover(events)

## Is there at least one card in your hand you could actually play right now?
func _has_playable_card() -> bool:
	for card in DeckState.hand:
		if card.energy_cost <= energy and can_play_here(card):
			return true
	return false

## You lose the ball where it is.
func _turnover(events: Array) -> void:
	events.append({"type": "turnover", "zone": ZONE_NAMES[zone]})
	_start_their_possession()

## You win the ball back where it is.
func _win_ball(events: Array) -> void:
	events.append({"type": "won_ball", "zone": ZONE_NAMES[zone]})
	_start_our_possession(events)

## Everything that happens when the ball changes hands lives in these two functions.
func _start_our_possession(events: Array) -> void:
	has_ball = true
	energy = START_ENERGY
	next_bonus = 0
	DeckState.draw(POSSESSION_DRAW)
	if zone == 4:
		_enter_box(0, events)   ## won it inside their box: straight into a shooting position
	else:
		_flip_press()

func _start_their_possession() -> void:
	has_ball = false
	energy = START_ENERGY
	next_bonus = 0
	DeckState.draw(POSSESSION_DRAW)
	if zone == 0:
		_set_their_chance()
	else:
		_flip_attack()

# ---------- Helpers ----------

## Roll a card's chance, with one extra attempt per retrigger. True if any attempt succeeds.
func _roll(card: ActionCard) -> bool:
	var attempts := 1 + RunState.retriggers_for_card(card)
	for i in attempts:
		if randf() < card.chance:
			return true
	return false
	
## Percentage of the cards in a pile that a value beats (uses the full deck if the pile is empty).
func _odds_to_beat(value: int, pile: Array, source: Array) -> int:
	var saves: Array = pile if not pile.is_empty() else source
	var beaten := 0
	for s in saves:
		if value > s:
			beaten += 1
	return roundi(100.0 * beaten / saves.size())

## Takes the top item from a pile, reshuffling from source when it's empty.
func _draw_from(pile: Array, source: Array):
	if pile.is_empty():
		pile.append_array(source)
		pile.shuffle()
	return pile.pop_back()

## Every action uses up time. At full time, the match is over.
func _tick_clock(events: Array) -> void:
	minute += MINUTES_PER_ACTION
	if minute >= MATCH_LENGTH:
		minute = MATCH_LENGTH
		match_over = true
		events.append({"type": "full_time"})

func coins_earned() -> int:
	var coins := goals * COINS_PER_GOAL
	if goals > conceded:
		coins += COINS_WIN
	elif goals == conceded:
		coins += COINS_DRAW
	else:
		coins += COINS_LOSS
	coins += bonus_coins
	return coins

## Fire every coach whose effect happens at this moment, plus any retriggers of it.
func fire_coaches(when: String, events: Array) -> void:
	for c in RunState.coaches_for(when):
		var times := 1 + RunState.retriggers_for_type(c.category)
		bonus_coins += c.coins * times
		events.append({"type": "coach", "name": c.display_name,
				"coins": c.coins * times, "times": times})


# ---------- Debug only ----------

func debug_goal() -> Array:
	var events := []
	goals += 1
	events.append({"type": "goal", "goals": goals})
	zone = 2
	_start_their_possession()
	_tick_clock(events)
	fire_coaches("on_goal",events)
	return events

func debug_concede() -> Array:
	var events := []
	conceded += 1
	events.append({"type": "conceded", "conceded": conceded})
	zone = 2
	_start_our_possession(events)
	_tick_clock(events)
	return events

func debug_full_time() -> Array:
	var events := []
	minute = MATCH_LENGTH - MINUTES_PER_ACTION
	_tick_clock(events)
	return events
