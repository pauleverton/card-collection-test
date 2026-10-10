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

func _ready() -> void:
	resized.connect(_layout)   ## re-arrange if the window size changes

func refresh() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for card in DeckState.hand:
		var ui = CARD_UI.instantiate()
		ui.setup(card)
		ui.card_clicked.connect(func(c): card_played.emit(c))
		ui.mouse_entered.connect(_on_hover.bind(ui, true))
		ui.mouse_exited.connect(_on_hover.bind(ui, false))
		add_child(ui)
	_layout()

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
	if n > 1:
		spacing = min(MAX_SPACING, (size.x - CARD_SIZE.x) / (n - 1))
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
