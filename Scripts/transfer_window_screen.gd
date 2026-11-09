extends Control
## The transfer window: once a season, before round 1 (start of a run, and after promotion).
## A cork board with the transfer list (paid: players and coaches) and the free agents
## (free: players only), plus "Scout again" (a new transfer list; the price goes up each time).
## Your squad along the bottom: click to sell for half. "Start the season" goes to the hub.
## Everything is built in code; the scene is just this root node.

const BACKGROUND := Color("241c16")
const CORK := Color("b98a5a")
const CORK_FRAME := Color("6b4a2e")
const STRIP := Color("1a1510")
const STRIP_EDGE := Color("3a2e22")
const PAPER := Color("fbf8ef")
const INK := Color("232323")
const SOFT := Color("4a4f4b")
const TAPE := Color(0.94, 0.9, 0.75, 0.92)
const GOLD := Color("f2c14e")
const BLUE := Color("7fb3ff")
const FREE_GREEN := Color("2f7a3a")
const PIN_RED := Color("d3302f")
const HEADING := Color("b8a48c")
const NOTE_YELLOW := Color("fff59a")
const NOTE_BLUE := Color("2b5bc4")
const RARITY_COLOURS := {"common": Color("5a635c"), "uncommon": Color("2b5bc4"),
		"rare": Color("c9302c"), "special": Color("c99a2e")}
const REPORT_SIZE := Vector2(250, 300)
const NOTE_SIZE := Vector2(200, 220)
## 180 wide = a full squad (7 players + 2 coaches) fits on one row.
const OWNED_SIZE := Vector2(180, 118)
const MARKER_FONT := "res://Images+themes/Themes/permanent_marker.ttf"
const HAND_FONT := "res://Images+themes/Themes/kalam_bold.ttf"

var _marker: Font
var _hand: Font
var coins_label: Label
var message_label: Label
var squad_heading: Label
var board_row: HBoxContainer
var squad_row: HBoxContainer

func _ready() -> void:
	_marker = load(MARKER_FONT) if ResourceLoader.exists(MARKER_FONT) else null
	_hand = load(HAND_FONT) if ResourceLoader.exists(HAND_FONT) else null

	var background := ColorRect.new()
	background.color = BACKGROUND
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 20)
	margin.add_child(page)

	## Header: where you are, the title, a message line, your coins.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 30)
	page.add_child(header)
	var titles := VBoxContainer.new()
	titles.add_child(_text("CLUBHOUSE  ·  PRE-SEASON  ·  %s  ·  ONCE A SEASON" %
			LeagueState.current_tournament_name().to_upper(), null, 20, HEADING))
	titles.add_child(_text("TRANSFER WINDOW", null, 52, Color.WHITE))
	header.add_child(titles)
	message_label = _text("", null, 24, GOLD)
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_label.size_flags_vertical = Control.SIZE_SHRINK_END
	header.add_child(message_label)
	var coins_box := _panel(Color("3a2e22"), GOLD, 2, 10, 12)
	coins_box.size_flags_vertical = Control.SIZE_SHRINK_END
	coins_label = _text("", null, 34, GOLD)
	coins_box.add_child(coins_label)
	header.add_child(coins_box)

	## The cork board: things to buy.
	var cork := _panel(CORK, CORK_FRAME, 14, 8, 24)
	page.add_child(cork)
	board_row = HBoxContainer.new()
	board_row.add_theme_constant_override("separation", 52)
	cork.add_child(board_row)

	## Your squad: click to sell.
	var strip := _panel(STRIP, STRIP_EDGE, 1, 12, 16)
	page.add_child(strip)
	var strip_box := VBoxContainer.new()
	strip_box.add_theme_constant_override("separation", 10)
	strip.add_child(strip_box)
	squad_heading = _text("", null, 20, HEADING)
	strip_box.add_child(squad_heading)
	squad_row = HBoxContainer.new()
	squad_row.add_theme_constant_override("separation", 10)
	strip_box.add_child(squad_row)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(spacer)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	page.add_child(buttons)
	var start := Button.new()
	start.text = "Start the season"
	start.custom_minimum_size = Vector2(300, 64)
	start.pressed.connect(_start_season)
	UiStyle.primary(start)
	buttons.add_child(start)

	_refresh()

## Rebuild the board and the squad strip from RunState.
func _refresh() -> void:
	for row in [board_row, squad_row]:
		for child in row.get_children():
			child.queue_free()

	var paid: Array = []
	for s in RunState.transfer_list:
		paid.append(_report(s, false))
	board_row.add_child(_group("Transfer list", paid, "All signed. Scout again?"))
	var free: Array = []
	for s in RunState.free_agents:
		free.append(_report(s, true))
	board_row.add_child(_group("Free agents", free, "All signed."))
	var note_holder := VBoxContainer.new()
	note_holder.alignment = BoxContainer.ALIGNMENT_CENTER
	note_holder.add_child(_scout_note())
	board_row.add_child(note_holder)

	for s in RunState.squad:
		squad_row.add_child(_owned_tile(s))
	for i in RunState.MAX_PLAYERS + RunState.MAX_COACHES - RunState.squad.size():
		squad_row.add_child(_empty_tile())
	squad_heading.text = "YOUR SQUAD  ·  PLAYERS %d / %d  ·  COACHES %d / %d  ·  CLICK TO SELL FOR HALF" % [
			RunState.players().size(), RunState.MAX_PLAYERS, RunState.coaches().size(), RunState.MAX_COACHES]
	coins_label.text = "%d coins" % CoinState.coins

# ---------- Buying and selling ----------

func _buy(s: StaffCard, free: bool) -> void:
	if RunState.squad_full_for(s):
		message_label.text = "Squad full: sell someone first"
		return
	var cost := 0 if free else RunState.staff_price(s)
	if not CoinState.can_afford(cost):
		message_label.text = "Not enough coins"
		return
	CoinState.deduct_coins(cost)
	RunState.add_player(s)
	RunState.transfer_list.erase(s)
	RunState.free_agents.erase(s)
	message_label.text = "Signed: %s" % s.display_name
	_refresh()

func _sell(s: StaffCard) -> void:
	CoinState.add_coins(RunState.sell_price(s))
	RunState.remove_player(s)
	message_label.text = "Sold: %s (+%d)" % [s.display_name, RunState.sell_price(s)]
	_refresh()

func _scout() -> void:
	var cost := RunState.scout_cost()
	if not CoinState.can_afford(cost):
		message_label.text = "Not enough coins to scout again"
		return
	CoinState.deduct_coins(cost)
	RunState.scout_again()
	message_label.text = "New names on the transfer list"
	_refresh()

func _start_season() -> void:
	RunState.transfer_window_due = false
	get_tree().change_scene_to_file(RunState.HUB_SCENE)

# ---------- The board ----------

## A strip of masking tape with a label, then the reports pinned underneath.
func _group(title: String, items: Array, empty_text: String) -> VBoxContainer:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 28)
	var tape := _panel(TAPE, TAPE, 0, 2, 4)
	tape.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tape.add_child(_text(title, _marker, 26, INK))
	group.add_child(tape)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	group.add_child(row)
	if items.is_empty():
		row.add_child(_text(empty_text, _hand, 22, INK))
	for item in items:
		row.add_child(item)
	return group

## A pinned scouting report: who, what he does, games a season, rarity, price (or FREE).
func _report(s: StaffCard, free: bool) -> Button:
	var button := _paper_button(REPORT_SIZE, PAPER)
	var box := _inner_box(button, 20)
	var kind := "FREE AGENT" if free else ("COACH" if s is CoachCard else "PLAYER")
	box.add_child(_text("SCOUTING REPORT  ·  " + kind, null, 14, FREE_GREEN if free else INK))
	box.add_child(_line(FREE_GREEN if free else INK, 2))
	box.add_child(_text(s.display_name.to_upper(), null, 30, INK))
	var desc := _text(s.description, null, 17, INK)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = REPORT_SIZE.x - 40
	box.add_child(desc)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	box.add_child(_line(Color(SOFT, 0.5), 1))
	var games := "Always plays · max %d" % RunState.MAX_COACHES
	if s is PlayerCard:
		games = "%d games a season" % s.max_appearances()
	box.add_child(_text(games, null, 15, SOFT))
	var colour: Color = RARITY_COLOURS.get(s.rarity, SOFT)
	var stamp := _panel(Color(0, 0, 0, 0), colour, 3, 6, 2)
	stamp.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	stamp.add_child(_text(s.rarity.to_upper(), null, 18, colour))
	box.add_child(stamp)
	_pin(button, FREE_GREEN if free else PIN_RED)
	_tag(button, "FREE" if free else "%d coins" % RunState.staff_price(s), free)
	_ignore_mouse(button)
	button.pressed.connect(_buy.bind(s, free))
	return button

## The yellow "Scout again" note: a new transfer list, a little dearer each time.
func _scout_note() -> Button:
	var button := _paper_button(NOTE_SIZE, NOTE_YELLOW)
	var box := _inner_box(button, 18)
	box.add_child(_text("Scout again", _marker, 30, INK))
	var note := _text("New names on the transfer list. Free agents stay.", _hand, 20, NOTE_BLUE)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = NOTE_SIZE.x - 36
	box.add_child(note)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	box.add_child(_text("NEXT ONE: %d" % (RunState.scout_cost() + RunState.SCOUT_STEP), null, 15, SOFT))
	_pin(button, FREE_GREEN)
	_tag(button, "%d coins" % RunState.scout_cost(), false)
	_ignore_mouse(button)
	button.pressed.connect(_scout)
	return button

# ---------- The squad strip ----------

func _owned_tile(s: StaffCard) -> Button:
	var button := Button.new()
	button.custom_minimum_size = OWNED_SIZE
	button.focus_mode = Control.FOCUS_NONE
	var edge := BLUE if s is CoachCard else GOLD
	for state in ["normal", "hover", "pressed"]:
		var style := _box_style(Color("1e2a22") if state != "hover" else Color("2a3a2e"), 10)
		style.border_color = edge
		style.set_border_width_all(2)
		button.add_theme_stylebox_override(state, style)
	var box := _inner_box(button, 10)
	box.add_child(_text(s.display_name.to_upper(), null, 19, Color.WHITE))
	var desc := _text(s.description, null, 13, Color("b9c4b8"))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = OWNED_SIZE.x - 20
	desc.max_lines_visible = 2
	box.add_child(desc)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	box.add_child(_text("Sell · %d coins" % RunState.sell_price(s), null, 15, GOLD))
	_ignore_mouse(button)
	button.pressed.connect(_sell.bind(s))
	return button

func _empty_tile() -> Panel:
	var tile := Panel.new()
	tile.custom_minimum_size = OWNED_SIZE
	var style := _box_style(Color(0, 0, 0, 0), 10)
	style.border_color = STRIP_EDGE
	style.set_border_width_all(2)
	tile.add_theme_stylebox_override("panel", style)
	return tile

# ---------- Helpers ----------

## A flat paper-coloured button (hover: a thin gold edge).
func _paper_button(size: Vector2, colour: Color) -> Button:
	var button := Button.new()
	button.custom_minimum_size = size
	button.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed"]:
		var style := _box_style(colour, 2)
		style.shadow_color = Color(0, 0, 0, 0.4)
		style.shadow_size = 8
		style.shadow_offset = Vector2(0, 4)
		if state == "hover":
			style.border_color = GOLD
			style.set_border_width_all(3)
		button.add_theme_stylebox_override(state, style)
	return button

## A column inside a button, with `padding` all round.
func _inner_box(button: Button, padding: int) -> VBoxContainer:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, padding)
	button.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	return box

## A drawing pin at the top middle.
func _pin(button: Button, colour: Color) -> void:
	var pin := Panel.new()
	pin.size = Vector2(18, 18)
	pin.position = Vector2(button.custom_minimum_size.x / 2.0 - 9, -8)
	var style := _box_style(colour, 9)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 3
	pin.add_theme_stylebox_override("panel", style)
	button.add_child(pin)

## A price tag hanging off the bottom-right corner (gold, or green for FREE).
func _tag(button: Button, words: String, free: bool) -> void:
	var tag := _panel(FREE_GREEN if free else GOLD, FREE_GREEN if free else GOLD, 0, 6, 6)
	tag.add_child(_text(words, null, 20, Color.WHITE if free else Color("141a15")))
	button.add_child(tag)
	tag.position = button.custom_minimum_size - Vector2(100, 22)
	tag.rotation_degrees = 5

func _line(colour: Color, thickness: int) -> ColorRect:
	var line := ColorRect.new()
	line.color = colour
	line.custom_minimum_size.y = thickness
	return line

func _box_style(fill: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(radius)
	return style

## A rounded panel: fill, edge colour and width, corner radius, padding.
func _panel(fill: Color, edge: Color, edge_width: int, radius: int, padding: int) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := _box_style(fill, radius)
	style.border_color = edge
	style.set_border_width_all(edge_width)
	style.set_content_margin_all(padding)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _text(words: String, font: Font, font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = words
	if font != null:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	return label

## Clicks go to the button, not the pieces inside it.
func _ignore_mouse(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_mouse(child)
