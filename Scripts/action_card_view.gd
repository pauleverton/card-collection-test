extends Button
## One action card drawn as a card: a colour band by type (energy cost + name), the value,
## the description, and type + rarity along the bottom. If the card has `art`, it's shown
## above the value. Deliberately plain: proper artwork will take over the look later.
## The match hand uses it at its normal size (180×250); setup's `factor` makes it bigger
## or smaller elsewhere (reward screen 1.3, deck grids ~0.8).
## Play state (set by the match screen) is shown on the card itself, never by tinting it:
## greyed = can't play here, green outline = gets you through.

signal card_clicked(card: ActionCard)

const BASE_SIZE := Vector2(180, 250)     ## the hand's card size (hand_view CARD_SIZE)
const PAPER := Color("f7f4ec")
const INK := Color("141a15")
const SOFT_INK := Color("3a453c")
const EDGE := Color("ddd7c8")
const GOLD := Color("f2c14e")
const THROUGH := Color("3fbf55")         ## outline: this card gets you through
const THROUGH_WIDTH := 7         ## outline thickness at factor 1.0
const THROUGH_GLOW := 18         ## how far the green glow spreads (px)
const BLOCKED := Color(0.5, 0.5, 0.5)    ## greyed out (solid, so the pitch doesn't show through)
const TYPE_COLOURS := {"attacking": Color("c9302c"), "move": Color("2b5bc4"),
		"utility": Color("d9822b"), "defending": Color("2f7a3a"), "skills": Color("1f8a8a")}
const RARITY_COLOURS := {"common": Color("9aa59b"), "uncommon": Color("3e8fd0"),
		"rare": Color("c9302c"), "special": Color("c99a2e")}
const ART_SHARE := 0.35          ## share of the card's height the artwork gets, when it has some
## Font sizes at factor 1.0.
const NAME_SIZE := 20
const VALUE_SIZE := 44
const VALUE_SIZE_WITH_ART := 30
const DESC_SIZE := 13
const FOOTER_SIZE := 12
const COIN_SIZE := 28

var card: ActionCard
var _factor := 1.0

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	pressed.connect(func(): card_clicked.emit(card))

## `factor` scales the whole card (1.0 = hand size, 1.3 = a big reward card).
func setup(data: ActionCard, factor: float = 1.0) -> void:
	card = data
	_factor = factor
	text = ""
	custom_minimum_size = BASE_SIZE * factor
	_apply_outline(Color(0, 0, 0, 0), 0)
	var colour: Color = TYPE_COLOURS.get(data.card_type, Color.GRAY)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_child(_band(data, colour))
	box.add_child(_middle(data))
	box.add_child(_footer(data, colour))
	_ignore_mouse(box)

## A gold outline: picked (e.g. on the training ground).
func highlight(on: bool) -> void:
	_apply_outline(GOLD if on else Color(0, 0, 0, 0), 4 if on else 0)

## Match hand: "blocked" = can't play here (greyed), "through" = gets you through
## (green outline), anything else = normal.
func set_play_state(state: String) -> void:
	match state:
		"blocked":
			modulate = BLOCKED
			_apply_outline(Color(0, 0, 0, 0), 0)
		"through":
			modulate = Color.WHITE
			_apply_outline(THROUGH, int(THROUGH_WIDTH * _factor))
		_:
			modulate = Color.WHITE
			_apply_outline(Color(0, 0, 0, 0), 0)

## The card's background in every state, with an optional outline. A THROUGH outline also
## glows. Hover adds a thin gold edge unless the card already has an outline of its own.
func _apply_outline(outline: Color, width: int) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = PAPER
		style.set_corner_radius_all(int(10 * _factor))
		style.shadow_color = Color(0, 0, 0, 0.4)
		style.shadow_size = int(6 * _factor)
		style.shadow_offset = Vector2(0, 3 * _factor)
		if width > 0:
			style.border_color = outline
			style.set_border_width_all(width)
			if outline == THROUGH:
				style.shadow_color = Color(THROUGH, 0.75)    ## the glow
				style.shadow_size = int(THROUGH_GLOW * _factor)
				style.shadow_offset = Vector2.ZERO
		elif state == "hover":
			style.border_color = GOLD
			style.set_border_width_all(2)
		add_theme_stylebox_override(state, style)

## The value as shown: a chance card shows its % (Long Shot: 10%), everything else its value.
static func value_text(data: ActionCard) -> String:
	if data.base_value == 0 and data.chance > 0:
		return "%d%%" % roundi(data.chance * 100)
	return str(data.base_value)

# ---------- Pieces ----------

## Coloured band across the top: energy cost in a white circle, then the name.
func _band(data: ActionCard, colour: Color) -> PanelContainer:
	var band := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	var r := int(10 * _factor)
	style.corner_radius_top_left = r
	style.corner_radius_top_right = r
	style.set_content_margin_all(8 * _factor)
	band.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(6 * _factor))
	band.add_child(row)
	var coin := PanelContainer.new()
	var coin_size := COIN_SIZE * _factor
	coin.custom_minimum_size = Vector2(coin_size, coin_size)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var coin_style := StyleBoxFlat.new()
	coin_style.bg_color = Color.WHITE
	coin_style.set_corner_radius_all(int(coin_size / 2.0))
	coin.add_theme_stylebox_override("panel", coin_style)
	var cost := _label(str(data.energy_cost), NAME_SIZE, colour)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	coin.add_child(cost)
	row.add_child(coin)
	var name_label := _label(data.display_name.to_upper(), NAME_SIZE, Color.WHITE)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(name_label)
	return band

## The middle: artwork (if any), the big value, the description.
func _middle(data: ActionCard) -> VBoxContainer:
	var middle := VBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.add_theme_constant_override("separation", int(2 * _factor))
	if data.art != null:
		var art := TextureRect.new()
		art.texture = data.art
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.custom_minimum_size.y = BASE_SIZE.y * ART_SHARE * _factor
		middle.add_child(art)
	var value := _label(value_text(data), VALUE_SIZE if data.art == null else VALUE_SIZE_WITH_ART, INK)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	middle.add_child(value)
	var desc := _label(data.description, DESC_SIZE, SOFT_INK)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = (BASE_SIZE.x - 20) * _factor
	middle.add_child(desc)
	return middle

## Along the bottom: type on the left, a rarity dot + word on the right, above a thin line.
func _footer(data: ActionCard, colour: Color) -> PanelContainer:
	var footer := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = EDGE
	style.border_width_top = 1
	style.set_content_margin_all(6 * _factor)
	footer.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	footer.add_child(row)
	var type_label := _label(data.card_type.to_upper(), FOOTER_SIZE, colour)
	type_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(type_label)
	var dot := Panel.new()
	var dot_size := 8 * _factor
	dot.custom_minimum_size = Vector2(dot_size, dot_size)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var dot_style := StyleBoxFlat.new()
	dot_style.bg_color = RARITY_COLOURS.get(data.card_rarity, EDGE)
	dot_style.set_corner_radius_all(int(dot_size / 2.0))
	dot.add_theme_stylebox_override("panel", dot_style)
	row.add_child(dot)
	row.add_child(_label(" " + data.card_rarity.to_upper(), FOOTER_SIZE, SOFT_INK))
	return footer

# ---------- Helpers ----------

func _label(words: String, font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = words
	label.add_theme_font_size_override("font_size", int(font_size * _factor))
	label.add_theme_color_override("font_color", colour)
	return label

## Clicks and hovers go to the card (the button), not the pieces inside it.
func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)
