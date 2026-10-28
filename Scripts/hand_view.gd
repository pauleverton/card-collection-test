extends Control

signal card_played(card: ActionCard)

const CARD_UI = preload("res://Scenes/action_card_view.tscn")
const CARD_SIZE := Vector2(180, 250)
const MAX_SPACING := 180.0     ## distance between cards when there's plenty of room
const FAN_MAX_ANGLE := 12.0    ## tilt of the outermost cards, in degrees
const FAN_MAX_DROP := 45.0     ## how much lower the outermost cards sit
const FULL_FAN_CARDS := 7      ## hands smaller than this curve a bit less
const HOVER_LIFT := 70.0
const HOVER_SCALE := 1.15
const MAX_HAND_WIDTH := 1000.0  ## the fan never spreads wider than this
## Cards flying between the hand and the piles.
const PILE_SCALE := 0.3        ## how small a card is while it sits on a pile
const DEAL_TIME := 0.3         ## one card flying from the draw pile into the hand
const DEAL_GAP := 0.1          ## gap between cards when several are drawn together
const DISCARD_TIME := 0.3      ## a played card flying to the discard pile

## Centre of the draw pile on screen. The match screen sets this before calling refresh().
var draw_from := Vector2.ZERO
## The tile clicked last, so send_to_discard() knows which one to fly away.
var _clicked: Control = null

func _ready() -> void:
	resized.connect(_layout)   ## re-arrange if the window size changes

## Rebuild the hand from DeckState. Newly drawn cards fly in from the draw pile.
## Returns how long that takes, so the match screen can wait for it.
func refresh() -> float:
	_clicked = null
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for card in DeckState.hand:
		var ui = CARD_UI.instantiate()
		ui.setup(card)
		ui.card_clicked.connect(_on_card_clicked.bind(ui))
		ui.mouse_entered.connect(_on_hover.bind(ui, true))
		ui.mouse_exited.connect(_on_hover.bind(ui, false))
		add_child(ui)
	_layout()
	return _deal_in(DeckState.take_new_draws())

func _on_card_clicked(card: ActionCard, ui: Control) -> void:
	_clicked = ui
	card_played.emit(card)

## New cards are always at the END of the hand, so the last `count` tiles are the new ones.
## (Two Short Passes are the same Resource, so we can't tell them apart any other way.)
func _deal_in(count: int) -> float:
	var cards := get_children()
	count = min(count, cards.size())
	var total := 0.0
	for i in count:
		var ui: Control = cards[cards.size() - count + i]
		var rest_pos := ui.position
		var rest_rot := ui.rotation_degrees
		var delay := SettingsState.t(DEAL_GAP) * i
		var time := SettingsState.t(DEAL_TIME)
		## Start small, on top of the draw pile.
		ui.position = _pos_centred_on(draw_from, PILE_SCALE, self)
		ui.rotation_degrees = 0.0
		ui.scale = Vector2.ONE * PILE_SCALE
		ui.mouse_filter = Control.MOUSE_FILTER_IGNORE    ## no hover while it's flying
		var tw := ui.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(ui, "position", rest_pos, time).set_delay(delay)
		tw.tween_property(ui, "rotation_degrees", rest_rot, time).set_delay(delay)
		tw.tween_property(ui, "scale", Vector2.ONE, time).set_delay(delay)
		tw.chain().tween_callback(ui.set_mouse_filter.bind(Control.MOUSE_FILTER_STOP))
		total = delay + time
	return total

## Fly the card that was just clicked to the discard pile, then remove it.
## Returns how long it takes.
func send_to_discard(target: Vector2) -> float:
	var ui := _clicked
	_clicked = null
	if ui == null or not is_instance_valid(ui):
		return 0.0
	## Move it out of the hand (keeping where it is on screen) so the rest can close the gap.
	var screen: Control = get_parent()
	ui.reparent(screen)
	ui.z_index = 200
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout()
	var time := SettingsState.t(DISCARD_TIME)
	var tw := ui.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(ui, "position", _pos_centred_on(target, PILE_SCALE, screen), time)
	tw.tween_property(ui, "rotation_degrees", 0.0, time)
	tw.tween_property(ui, "scale", Vector2.ONE * PILE_SCALE, time)
	tw.chain().tween_callback(ui.queue_free)
	return time
	
## Fly every card in the hand back to the draw pile (the kick-off redeal).
## The tiles are cleared away by the next refresh(). Returns how long it takes.
func return_all_to(target: Vector2) -> float:
	var time := SettingsState.t(DISCARD_TIME)
	for child in get_children():
		var ui := child as Control
		ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tw := ui.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(ui, "position", _pos_centred_on(target, PILE_SCALE, self), time)
		tw.tween_property(ui, "rotation_degrees", 0.0, time)
		tw.tween_property(ui, "scale", Vector2.ONE * PILE_SCALE, time)
	return time

## Where a tile must sit (inside `parent`) so that, shrunk to `s`, its middle is on `point`.
## Needed because the tiles pivot at the bottom-centre, like a held card.
func _pos_centred_on(point: Vector2, s: float, parent: Control) -> Vector2:
	var pivot := Vector2(CARD_SIZE.x / 2.0, CARD_SIZE.y)
	return point - parent.global_position - pivot + Vector2(0, CARD_SIZE.y * s / 2.0)

## Place every card: spread out if there's room, overlapping if not, in a gentle fan.
func _layout() -> void:
	var cards := get_children()
	var n := cards.size()
	if n == 0:
		return
	var usable_width: float = min(size.x, MAX_HAND_WIDTH)
	var spacing := MAX_SPACING
	if n > 1:
		spacing = min(MAX_SPACING, (usable_width - CARD_SIZE.x) / (n - 1))
	var total_width := spacing * (n - 1) + CARD_SIZE.x
	var start_x := (size.x - total_width) / 2.0
	var middle := (n - 1) / 2.0
	## Small hands curve less, so 2 or 3 cards don't look oddly splayed.
	var spread: float = min(n, FULL_FAN_CARDS) / float(FULL_FAN_CARDS)
	for i in n:
		var ui: Control = cards[i]
		var t := 0.0                       ## -1 = far left, 0 = centre, +1 = far right
		if n > 1:
			t = (i - middle) / middle
		ui.size = CARD_SIZE
		ui.pivot_offset = Vector2(CARD_SIZE.x / 2.0, CARD_SIZE.y)   ## pivot at the bottom, like a held card
		ui.position = Vector2(start_x + i * spacing, t * t * FAN_MAX_DROP * spread)
		ui.rotation_degrees = t * FAN_MAX_ANGLE * spread
		ui.scale = Vector2.ONE
		ui.z_index = i
		ui.set_meta("rest_y", ui.position.y)
		ui.set_meta("rest_rotation", ui.rotation_degrees)
		ui.set_meta("rest_z", i)

## Hovering lifts, straightens and enlarges a card, and brings it to the front.
func _on_hover(ui: Control, hovering: bool) -> void:
	if ui.get_parent() != self:
		return      ## it's flying to the discard pile, or being removed: leave it alone
	var tween := create_tween().set_parallel(true)
	if hovering:
		ui.z_index = 100
		tween.tween_property(ui, "position:y", ui.get_meta("rest_y") - HOVER_LIFT, 0.1)
		tween.tween_property(ui, "rotation_degrees", 0.0, 0.1)
		tween.tween_property(ui, "scale", Vector2.ONE * HOVER_SCALE, 0.1)
	else:
		ui.z_index = ui.get_meta("rest_z")
		tween.tween_property(ui, "position:y", ui.get_meta("rest_y"), 0.1)
		tween.tween_property(ui, "rotation_degrees", ui.get_meta("rest_rotation"), 0.1)
		tween.tween_property(ui, "scale", Vector2.ONE, 0.1)
