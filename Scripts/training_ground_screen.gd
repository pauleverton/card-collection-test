extends Control
## The training ground: this week's one activity (already paid for at the hub).
##   new_card  : pick 1 of 3 new cards for your deck
##   upgrade   : pick a card that has an upgrade (before → after shown first)
##   cut       : pick a card to take out for good
##   duplicate : pick a card to add a copy of
## Doing it, or leaving without, goes back to the hub. Built in code; the scene is just this root node.

const CARD_UI := preload("res://Scenes/action_card_view.tscn")
const BACKGROUND := Color("1b3524")
const STRIPE := Color(1, 1, 1, 0.025)
const PANEL := Color(0.04, 0.08, 0.055, 0.55)
const PANEL_EDGE := Color("3e6b4a")
const GOLD := Color("f2c14e")
const GREY := Color("9fb09f")
const WHITE := Color("edefe9")
const HAND_FONT := "res://Images+themes/Themes/kalam_bold.ttf"
const DECK_FACTOR := 0.8          ## deck cards in the grid
const NEW_CARD_FACTOR := 1.3      ## the three new cards
const PREVIEW_FACTOR := 0.95      ## before / after in the side panel
const PREVIEW_WIDTH := 420
const TITLES := {"new_card": "New card", "upgrade": "Upgrade a card",
		"cut": "Cut a card", "duplicate": "Duplicate a card"}
const HINTS := {"new_card": "Pick one to add to your deck.",
		"upgrade": "Pick a card to improve. Greyed cards have no upgrade yet.",
		"cut": "Pick a card to take out of your deck for good.",
		"duplicate": "Pick a card to add a second copy of."}
const ACTION_WORDS := {"upgrade": "Upgrade", "cut": "Cut", "duplicate": "Duplicate"}

var _activity := ""
var _selected := -1               ## index in RunState.deck
var _tiles: Array = []
var preview_box: VBoxContainer
var confirm: Button

func _ready() -> void:
	_activity = RunState.training_activity
	var background := ColorRect.new()
	background.color = BACKGROUND
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in 8:                                   ## mown stripes
		var stripe := ColorRect.new()
		stripe.color = STRIPE
		stripe.position = Vector2(i * 240, 0)
		stripe.size = Vector2(120, 1080)
		add_child(stripe)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 56)
	margin.add_theme_constant_override("margin_right", 56)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 22)
	margin.add_child(page)

	page.add_child(_label("TRAINING GROUND  ·  WEEK %d  ·  %d COINS PAID" % [
			LeagueState.matches_played + 1, RunState.TRAINING_COST], 20, GREY))
	page.add_child(_label(TITLES.get(_activity, "Training").to_upper(), 56, WHITE))
	var hint := _label(HINTS.get(_activity, ""), 26, GOLD)
	if ResourceLoader.exists(HAND_FONT):
		hint.add_theme_font_override("font", load(HAND_FONT))
	page.add_child(hint)

	if _activity == "new_card":
		_build_new_cards(page)
	else:
		_build_deck_pick(page)

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_END
	page.add_child(bottom)
	var leave := Button.new()
	leave.text = "Leave without using it"
	leave.custom_minimum_size = Vector2(300, 56)
	leave.pressed.connect(_back_to_hub)
	UiStyle.secondary(leave)
	bottom.add_child(leave)

# ---------- New card week ----------

func _build_new_cards(page: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 48)
	page.add_child(row)
	for card in RunState.reward_options(RunState.TRAINING_NEW_CARDS):
		var ui = CARD_UI.instantiate()
		row.add_child(ui)
		ui.setup(card, NEW_CARD_FACTOR)
		ui.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ui.card_clicked.connect(_take_new_card)

func _take_new_card(card: ActionCard) -> void:
	RunState.add_card(card)
	_back_to_hub()

# ---------- Upgrade / cut / duplicate weeks ----------

func _build_deck_pick(page: VBoxContainer) -> void:
	var main := HBoxContainer.new()
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 40)
	page.add_child(main)

	## Your deck, scrolling if it gets big.
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(scroll)
	var grid := HFlowContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(grid)
	for i in RunState.deck.size():
		var card: ActionCard = RunState.deck[i]
		var ui = CARD_UI.instantiate()
		grid.add_child(ui)
		ui.setup(card, DECK_FACTOR)
		if _activity == "upgrade" and not card.can_upgrade():
			ui.disabled = true
			ui.set_play_state("blocked")
		ui.card_clicked.connect(func(_c): _select(i))
		_tiles.append(ui)

	## The side panel: what you've picked (before → after for an upgrade) and the button.
	var side := PanelContainer.new()
	side.custom_minimum_size.x = PREVIEW_WIDTH
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.border_color = PANEL_EDGE
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(24)
	side.add_theme_stylebox_override("panel", style)
	main.add_child(side)
	var side_box := VBoxContainer.new()
	side_box.add_theme_constant_override("separation", 18)
	side.add_child(side_box)
	side_box.add_child(_label("BEFORE → AFTER" if _activity == "upgrade" else "YOUR PICK", 20, GREY))
	preview_box = VBoxContainer.new()
	preview_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_box.alignment = BoxContainer.ALIGNMENT_CENTER
	preview_box.add_theme_constant_override("separation", 14)
	side_box.add_child(preview_box)
	preview_box.add_child(_label("Pick a card on the left.", 20, GREY))
	confirm = Button.new()
	confirm.text = ACTION_WORDS.get(_activity, "Do it")
	confirm.custom_minimum_size = Vector2(0, 64)
	confirm.disabled = true
	confirm.pressed.connect(_confirm)
	UiStyle.primary(confirm)
	side_box.add_child(confirm)

func _select(index: int) -> void:
	_selected = index
	for i in _tiles.size():
		if not _tiles[i].disabled:
			_tiles[i].highlight(i == index)
	for child in preview_box.get_children():
		child.queue_free()
	var card: ActionCard = RunState.deck[index]
	if _activity == "upgrade":
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 10)
		row.add_child(_preview(card))
		row.add_child(_label("→", 44, GOLD))
		row.add_child(_preview(card.upgrades_to))
		preview_box.add_child(row)
		var diff := _label(_upgrade_diff(card, card.upgrades_to), 18, WHITE)
		diff.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		diff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		preview_box.add_child(diff)
	else:
		var holder := CenterContainer.new()
		holder.add_child(_preview(card))
		preview_box.add_child(holder)
	confirm.text = "%s %s" % [ACTION_WORDS.get(_activity, "Do it"), card.display_name]
	confirm.disabled = false

func _confirm() -> void:
	if _selected < 0:
		return
	match _activity:
		"upgrade":
			RunState.upgrade_card(_selected)
		"cut":
			RunState.remove_card(RunState.deck[_selected])
		"duplicate":
			RunState.duplicate_card(_selected)
	_back_to_hub()

## A card for the side panel (not clickable).
func _preview(card: ActionCard) -> Control:
	var ui = CARD_UI.instantiate()
	ui.setup(card, PREVIEW_FACTOR)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return ui

## What an upgrade changes, in words: "Energy 1 → 0", "Value 20 → 30" …
func _upgrade_diff(before: ActionCard, after: ActionCard) -> String:
	var lines: PackedStringArray = []
	if before.energy_cost != after.energy_cost:
		lines.append("Energy %d → %d" % [before.energy_cost, after.energy_cost])
	if before.base_value != after.base_value:
		lines.append("Value %d → %d" % [before.base_value, after.base_value])
	if not is_equal_approx(before.chance, after.chance):
		lines.append("Chance %d%% → %d%%" % [roundi(before.chance * 100), roundi(after.chance * 100)])
	if before.draw_count != after.draw_count:
		lines.append("Draws %d → %d" % [before.draw_count, after.draw_count])
	if before.energy_boost != after.energy_boost:
		lines.append("Energy boost %d → %d" % [before.energy_boost, after.energy_boost])
	if lines.is_empty():
		return after.description
	return "\n".join(lines)

# ---------- Helpers ----------

func _back_to_hub() -> void:
	get_tree().change_scene_to_file(RunState.HUB_SCENE)

func _label(text: String, font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	return label
