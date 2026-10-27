## DeckState: the draw pile, hand and discard pile DURING ONE MATCH.
## Rebuilt at every kick-off from RunState.deck (the cards you own for the whole run).
extends Node
	
var draw_pile: Array = []
var hand: Array = []
var discard_pile: Array = []

const MAX_HAND_SIZE := 10

## For the screen: how many cards were drawn since the hand was last shown,
## and whether the discard pile got shuffled back into the draw pile.
## The match screen reads these with take_new_draws() / take_reshuffled(), which reset them.
var drawn_since_shown := 0
var reshuffled := false

func start_match(deck: Array) -> void:
	draw_pile = deck.duplicate()
	draw_pile.shuffle()
	hand.clear()
	discard_pile.clear()
	drawn_since_shown = 0
	reshuffled = false

func draw(count: int) -> void:
	for i in count:
		if hand.size() >= MAX_HAND_SIZE:
			return
		if draw_pile.is_empty():
			if not discard_pile.is_empty():
				reshuffled = true
			draw_pile = discard_pile.duplicate()
			discard_pile.clear()
			draw_pile.shuffle()
		if draw_pile.is_empty():
			return
		hand.append(draw_pile.pop_back())
		drawn_since_shown += 1     ## always added to the END of the hand

func play(card: ActionCard) -> void:
	hand.erase(card)
	discard_pile.append(card)

func discard_hand() -> void:
	discard_pile.append_array(hand)
	hand.clear()

func recall_last_discarded() -> ActionCard:
	if discard_pile.is_empty():
		push_warning("recall: discard pile is empty")
		return null
	var card = discard_pile.pop_back()
	hand.append(card)
	return card

## How many new cards are waiting to be animated in, and reset the count.
func take_new_draws() -> int:
	var n := drawn_since_shown
	drawn_since_shown = 0
	return n

## True once after the discard pile was shuffled back in.
func take_reshuffled() -> bool:
	var r := reshuffled
	reshuffled = false
	return r
