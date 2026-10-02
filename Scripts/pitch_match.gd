class_name PitchMatch
extends RefCounted

## Zones: 0 = your box, 1 = your half, 2 = midfield, 3 = their half, 4 = their box
const ZONE_NAMES := ["Your box", "Your half", "Midfield", "Their half", "Their box"]
const PRESS_MODIFIER := [0, 0, 1, 2, 0]
const PRESS_DECK := [2, 2, 3, 3, 3, 4, 4, 4, 5]
const START_ENERGY := 5
const LONG_BALL_MARGIN := 3

var zone := 2
var energy := START_ENERGY
var target := 0
var has_ball := true
## Bonus waiting for the next move card (from Overlap, later from jokers).
var next_bonus := 0
var _press_pile: Array = []

func start() -> void:
	zone = 2
	energy = START_ENERGY
	has_ball = true
	next_bonus = 0
	_flip_press()

func play(card: ActionData) -> Array:
	var events := []
	if not has_ball:
		events.append({"type": "no_ball"})
		return events
	if card.energy_cost > energy:
		events.append({"type": "no_energy"})
		return events
	energy -= card.energy_cost
	match card.tag:
		"pass", "dribble", "long_ball":
			if zone == 4:
				events.append({"type": "wrong_phase", "card": card.display_name})
			else:
				_attempt_move(card, events)
				if card.tag == "dribble":
					DeckState.draw(1)
					events.append({"type": "drew"})
		"overlap":
			next_bonus += card.base_value
			events.append({"type": "bonus", "next_bonus": next_bonus})
		_:
			events.append({"type": "wrong_phase", "card": card.display_name})
	if has_ball and energy == 0 and zone < 4:
		_turnover(events)
	return events

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
		_advance(steps, events)
	elif card.tag == "dribble":
		target -= 1
		events.append({"type": "kept_ball", "target": target})
	else:
		_turnover(events)

func _advance(steps: int, events: Array) -> void:
	zone = min(zone + steps, 4)
	events.append({"type": "advance", "zone": ZONE_NAMES[zone]})
	if zone == 4:
		events.append({"type": "in_the_box"})
	else:
		_flip_press()

func _turnover(events: Array) -> void:
	has_ball = false
	events.append({"type": "turnover", "zone": ZONE_NAMES[zone]})

func _flip_press() -> void:
	if _press_pile.is_empty():
		_press_pile = PRESS_DECK.duplicate()
		_press_pile.shuffle()
	target = _press_pile.pop_back() + PRESS_MODIFIER[zone]

func power_of(card: ActionData) -> int:
	return card.base_value + next_bonus

func would_succeed(card: ActionData) -> bool:
	if not has_ball or zone == 4:
		return false
	if not card.tag in ["pass", "dribble", "long_ball"]:
		return false
	return power_of(card) >= target
