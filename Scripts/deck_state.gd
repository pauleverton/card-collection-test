# deck_state.gd (add as an autoload)
extends Node

var draw_pile: Array = []
var hand: Array = []
var discard_pile: Array = []

const MAX_HAND_SIZE := 10

func start_match(deck: Array) -> void:
	draw_pile = deck.duplicate()
	draw_pile.shuffle()
	hand.clear()
	discard_pile.clear()

func draw(count: int) -> void:
	for i in count:
		if hand.size() >= MAX_HAND_SIZE:
			return
		if draw_pile.is_empty():
			draw_pile = discard_pile.duplicate()
			discard_pile.clear()
			draw_pile.shuffle()
		if draw_pile.is_empty():
			return
		hand.append(draw_pile.pop_back())

func play(card: ActionData) -> void:
	hand.erase(card)
	discard_pile.append(card)

func discard_hand() -> void:
	discard_pile.append_array(hand)
	hand.clear()

func recall_last_discarded() -> ActionData:
	if discard_pile.is_empty():
		push_warning("recall: discard pile is empty")
		return null
	var card = discard_pile.pop_back()
	hand.append(card)
	return card
