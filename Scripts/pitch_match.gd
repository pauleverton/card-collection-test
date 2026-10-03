class_name PitchMatch
extends RefCounted

## Zones: 0 = your box, 1 = your half, 2 = midfield, 3 = their half, 4 = their box
const ZONE_NAMES := ["Your box", "Your half", "Midfield", "Their half", "Their box"]
const PRESS_MODIFIER := [0, 0, 1, 2, 0]
const PRESS_DECK := [2, 2, 3, 3, 3, 4, 4, 4, 5]
const START_ENERGY := 5
const LONG_BALL_MARGIN := 3

## --- Box rules ---
const BOX_DEFENCE_DECK := ["block", "block", "block", "tackle", "tackle",
		"clearance", "clearance", "slip", "slip"]
const DEFENDER_TEXT := {"block": "Block -2", "tackle": "Tackle -3",
		"clearance": "Clearance (wins it if chance 4 or less)", "slip": "Slip"}
const BOX_DEFENCE_VALUE := {"block": 2, "tackle": 3, "clearance": 0, "slip": 0}
const BOX_HAND_SIZE := 3
const CLEARANCE_LIMIT := 4
const BOX_WORK_VALUE := 1   ## what Pass and Dribble add inside the box
const KEEPER_DECK := [2, 3, 3, 4, 4, 5, 5, 6, 7]
const SHOT_COST := 1
const BOX_ENERGY := 3
const BASIC_SHOT_PENALTY := 2

var zone := 2
var energy := START_ENERGY
var target := 0
var has_ball := true
## Bonus waiting for the next card (from Overlap, later from jokers).
var next_bonus := 0
var quality := 0
var goals := 0
var scored_last := false
var _press_pile: Array = []
var _box_hand: Array = []
var _box_defence_pile: Array = []
var _keeper_pile: Array = []

func start() -> void:
	zone = 2
	energy = START_ENERGY
	has_ball = true
	next_bonus = 0
	quality = 0
	scored_last = false
	_flip_press()

func defenders_left() -> int:
	return _box_hand.size()
	
## The defenders still to come, in the order they'll respond.
func upcoming_defenders() -> Array:
	return _box_hand.duplicate()

## Percentage chance a shot of this quality scores, from the saves left in the pile.
func goal_odds(shot_quality: int) -> int:
	var saves: Array = _keeper_pile if not _keeper_pile.is_empty() else KEEPER_DECK
	var beaten := 0
	for s in saves:
		if shot_quality > s:
			beaten += 1
	return roundi(100.0 * beaten / saves.size())

func power_of(card: ActionData) -> int:
	return card.base_value + next_bonus

## True if the card is worth playing right now (used for the green tint).
func would_succeed(card: ActionData) -> bool:
	if not has_ball:
		return false
	if zone == 4:
		return card.tag in ["pass", "dribble", "cross", "shot", "overlap"]
	if not card.tag in ["pass", "dribble", "long_ball"]:
		return false
	return power_of(card) >= target

func play(card: ActionData) -> Array:
	var events := []
	if not has_ball:
		events.append({"type": "no_ball"})
		return events
	if card.energy_cost > energy:
		events.append({"type": "no_energy"})
		return events
	energy -= card.energy_cost
	if card.tag == "overlap":
		next_bonus += card.base_value
		events.append({"type": "bonus", "next_bonus": next_bonus})
	elif zone == 4:
		_play_in_box(card, events)
	else:
		_play_in_build_up(card, events)
	_check_out_of_energy(events)
	return events

func take_shot() -> Array:
	var events := []
	if not has_ball or zone != 4:
		events.append({"type": "no_ball"})
		return events
	if energy < SHOT_COST:
		events.append({"type": "no_energy"})
		return events
	energy -= SHOT_COST
	quality = max(0, quality - BASIC_SHOT_PENALTY)
	events.append({"type": "basic_shot", "quality": quality})
	_shoot(events)
	_check_out_of_energy(events)
	return events

# ---------- Build-up ----------

func _play_in_build_up(card: ActionData, events: Array) -> void:
	match card.tag:
		"pass", "dribble", "long_ball":
			_attempt_move(card, events)
			if card.tag == "dribble":
				DeckState.draw(1)
				events.append({"type": "drew"})
		_:
			events.append({"type": "wrong_phase", "card": card.display_name})

func _attempt_move(card: ActionData, events: Array) -> void:
	## This line is where jokers will add their bonuses later.
	var power := power_of(card)
	next_bonus = 0
	var success := power >= target
	events.append({"type": "attempt", "card": card.display_name,
			"power": power, "target": target, "success": success})
	if success:
		var steps := 1
		if card.tag == "long_ball" and power >= target + LONG_BALL_MARGIN:
			steps = 2
		_advance(steps, power - target, events)
	elif card.tag == "dribble":
		target -= 1
		events.append({"type": "kept_ball", "target": target})
	else:
		_turnover(events)

func _advance(steps: int, excess: int, events: Array) -> void:
	zone = min(zone + steps, 4)
	events.append({"type": "advance", "zone": ZONE_NAMES[zone]})
	if zone == 4:
		_enter_box(excess, events)
	else:
		_flip_press()

func _flip_press() -> void:
	target = _draw_from(_press_pile, PRESS_DECK) + PRESS_MODIFIER[zone]

# ---------- The box ----------

func _enter_box(start_quality: int, events: Array) -> void:
	energy = BOX_ENERGY
	quality = start_quality
	_box_hand.clear()
	for i in BOX_HAND_SIZE:
		_box_hand.append(_draw_from(_box_defence_pile, BOX_DEFENCE_DECK))
	events.append({"type": "in_the_box", "quality": quality})

func _play_in_box(card: ActionData, events: Array) -> void:
	match card.tag:
		"pass", "dribble", "cross":
			var amount: int = card.base_value if card.tag == "cross" else BOX_WORK_VALUE
			quality += amount + next_bonus
			next_bonus = 0
			events.append({"type": "quality", "card": card.display_name, "quality": quality})
			_defender_responds(events)
		"shot":
			quality += card.base_value + next_bonus
			next_bonus = 0
			_shoot(events)
		_:
			events.append({"type": "wrong_phase", "card": card.display_name})

func _defender_responds(events: Array) -> void:
	if _box_hand.is_empty():
		events.append({"type": "no_defenders"})
		return
	var d: String = _box_hand.pop_front()
	if d == "clearance" and quality <= CLEARANCE_LIMIT:
		events.append({"type": "defender", "card": d, "quality": quality})
		_turnover(events)
		return
	quality = max(0, quality - BOX_DEFENCE_VALUE[d])
	events.append({"type": "defender", "card": d, "quality": quality})

func _shoot(events: Array) -> void:
	var save: int = _draw_from(_keeper_pile, KEEPER_DECK)
	events.append({"type": "shot", "quality": quality, "save": save})
	if quality > save:
		goals += 1
		scored_last = true
		has_ball = false
		events.append({"type": "goal", "goals": goals})
	elif quality == save:
		quality = 2
		energy += 1
		events.append({"type": "corner"})
	else:
		events.append({"type": "saved"})
		_turnover(events)

# ---------- Shared ----------

func _check_out_of_energy(events: Array) -> void:
	if has_ball and energy == 0:
		_turnover(events)

func _turnover(events: Array) -> void:
	has_ball = false
	events.append({"type": "turnover", "zone": ZONE_NAMES[zone]})

## Takes the top item from a pile, reshuffling from source when it's empty.
func _draw_from(pile: Array, source: Array):
	if pile.is_empty():
		pile.append_array(source)
		pile.shuffle()
	return pile.pop_back()
