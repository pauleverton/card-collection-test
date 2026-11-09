extends Control
## After a win: pick one new card for your deck, or keep the deck as it is.
## The result as the headline, three big cards, and your deck by type on a clipboard.
## Everything is built in code; the scene is just this root node.

const CARD_UI := preload("res://Scenes/action_card_view.tscn")
const CARD_SCRIPT := preload("res://Scripts/action_card_view.gd")   ## for its TYPE_COLOURS
const BACKGROUND := Color("14211a")
const GOLD := Color("f2c14e")
const GREY := Color("9fb09f")
const WHITE := Color("edefe9")
const WOOD := Color("6b4a2e")
const PAPER := Color("fbf8ef")
const INK := Color("232323")
const HAND_FONT := "res://Images+themes/Themes/kalam_bold.ttf"
const CARD_FACTOR := 1.3
const TYPE_ORDER := ["attacking", "move", "utility", "defending", "skills"]

func _ready() -> void:
	var background := ColorRect.new()
	background.color = BACKGROUND
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 64)
	margin.add_theme_constant_override("margin_right", 64)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 26)
	margin.add_child(page)

	## The result as the headline.
	var r: Dictionary = RunState.last_result
	page.add_child(_centred(_label("FULL TIME", 22, GREY)))
	var headline := HBoxContainer.new()
	headline.alignment = BoxContainer.ALIGNMENT_CENTER
	headline.add_theme_constant_override("separation", 20)
	headline.add_child(_label("WON %d–%d" % [r.get("scored", 0), r.get("conceded", 0)], 64, WHITE))
	headline.add_child(_label("vs " + str(r.get("opponent", "them")), 64, GREY))
	page.add_child(headline)
	var line := _label("Good result. Pick one card to add to your deck.", 30, GOLD)
	if ResourceLoader.exists(HAND_FONT):
		line.add_theme_font_override("font", load(HAND_FONT))
	page.add_child(_centred(line))

	## Three cards, and your deck at the side.
	var middle := HBoxContainer.new()
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 70)
	page.add_child(middle)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 48)
	middle.add_child(cards)
	for card in RunState.reward_options():
		var ui = CARD_UI.instantiate()
		cards.add_child(ui)
		ui.setup(card, CARD_FACTOR)
		ui.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ui.card_clicked.connect(_on_card_chosen)
	var clipboard := _deck_clipboard()
	clipboard.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	middle.add_child(clipboard)

	var skip := Button.new()
	skip.text = "No thanks, keep the deck"
	skip.custom_minimum_size = Vector2(320, 64)
	skip.pressed.connect(_go_on)
	UiStyle.secondary(skip)
	page.add_child(_centred(skip))

## Your deck by type: a wooden clipboard with a paper sheet.
func _deck_clipboard() -> PanelContainer:
	var board := _panel(WOOD, 12, 14)
	var sheet := _panel(PAPER, 2, 18)
	board.add_child(sheet)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 240
	box.add_theme_constant_override("separation", 10)
	sheet.add_child(box)
	box.add_child(_label("YOUR DECK  ·  %d" % RunState.deck.size(), 22, INK))
	var counts := {}
	for card in RunState.deck:
		counts[card.card_type] = counts.get(card.card_type, 0) + 1
	for type in TYPE_ORDER:
		if not counts.has(type):
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var swatch := ColorRect.new()
		swatch.color = CARD_SCRIPT.TYPE_COLOURS.get(type, Color.GRAY)
		swatch.custom_minimum_size = Vector2(14, 14)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(swatch)
		var name_label := _label(type.capitalize(), 20, INK)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		row.add_child(_label(str(counts[type]), 22, INK))
		box.add_child(row)
	return board

func _on_card_chosen(card: ActionCard) -> void:
	RunState.add_card(card)
	_go_on()

func _go_on() -> void:
	get_tree().change_scene_to_file(RunState.next_break_screen())

# ---------- Helpers ----------

func _centred(control: Control) -> CenterContainer:
	var holder := CenterContainer.new()
	holder.add_child(control)
	return holder

func _panel(fill: Color, radius: int, padding: int) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _label(text: String, font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	return label
