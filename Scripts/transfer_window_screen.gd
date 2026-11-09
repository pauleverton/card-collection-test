extends Control
## The transfer window: once a season, before round 1 (start of a run, and after promotion).
## A cork board with the transfer list (paid: players and coaches) and the free agents
## (free: players only), plus "Scout again": the old list's pins pop out and its reports drop
## to the floor, then the new reports are pinned up one by one (the price goes up each time).
## Signing someone pulls his report off the board: it tugs on its pin, tears free (a scrap of its
## top edge stays under the pin, which bounces), lifts and swings loose, then flies into his slot
## in your squad, which flashes gold. Nothing else on the board moves.
## Your squad along the bottom: 7 player slots and 2 coach slots; click one to sell.
## "Start the season" goes to the hub. Everything is built in code; the scene is just this root node.
## Each report sits in a plain holder (not a container), so it can tilt, move and scale.

const BACKGROUND := Color("241c16")
const CORK := Color("b98a5a")
const CORK_FRAME := Color("6b4a2e")
const STRIP := Color("1a1510")
const STRIP_EDGE := Color("3a2e22")
const SLOT_FILL := Color("120e0a")       ## an empty squad slot
const SLOT_LABEL := Color("5a4a3a")
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
const MARK := Color(0, 0, 0, 0.12)       ## the faint mark a pulled-off report leaves on the cork
const SCRAP_SHADOW := Color(0, 0, 0, 0.25)
const SCRAP_WIDTH := 48.0        ## the torn scrap left under the pin
const SCRAP_DEPTH := Vector2(6, 20)   ## how far its torn edge reaches below the card's top (min, max)
const RARITY_COLOURS := {"common": Color("5a635c"), "uncommon": Color("2b5bc4"),
		"rare": Color("c9302c"), "special": Color("c99a2e")}
const REPORT_SIZE := Vector2(250, 300)
const NOTE_SIZE := Vector2(200, 220)
## 180 wide = 7 player slots + 2 coach slots fit on one row.
const OWNED_SIZE := Vector2(180, 118)
const REST_TILT := 1.5           ## reports rest at a random tilt up to this (degrees)
## Pulling a report off the board (seconds, scaled by the game speed setting).
const TUG_TIME := 0.05           ## each wiggle on the pin (4 of them)
const LIFT_TIME := 0.16          ## tearing free and lifting towards you
const FLY_TIME := 0.42           ## carried down into his squad slot
const FLY_SCALE := 0.45          ## how small the report is when it lands
const ARRIVE_FLASH := Color(1.7, 1.45, 0.7)   ## his new squad slot flashes gold
## Scout again: the old list comes down...
const PIN_POP_TIME := 0.12       ## a pin popping out
const FALL_TIME := 0.6           ## a report dropping to the floor
const FALL_GAP := 0.1            ## between one report and the next
const FALL_DISTANCE := 1000.0    ## how far it drops (px): well past the bottom of the screen
const FALL_SPIN := 30.0          ## up to this much spin as it falls (degrees)
const FALL_DRIFT := 60.0         ## up to this much sideways drift (px)
## ...then the new reports are pinned up.
const PIN_UP_TIME := 0.28        ## a report settling onto the board
const PIN_UP_GAP := 0.12         ## between one report and the next
const MARKER_FONT := "res://Images+themes/Themes/permanent_marker.ttf"
const HAND_FONT := "res://Images+themes/Themes/kalam_bold.ttf"

var _marker: Font
var _hand: Font
var coins_label: Label
var message_label: Label
var players_heading: Label
var coaches_heading: Label
var board_row: HBoxContainer
var players_row: HBoxContainer   ## 7 player slots
var coaches_row: HBoxContainer   ## 2 coach slots
var _paid_holders: Array = []    ## the transfer list's reports (in their holders)
var _paid_slots: Array = []      ## the transfer list's empty pins (signed players)
var busy := false                ## true while a report is moving on or off the board

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

	## Your squad: 7 player slots | 2 coach slots. Click one to sell.
	var strip := _panel(STRIP, STRIP_EDGE, 1, 12, 16)
	page.add_child(strip)
	var strip_row := HBoxContainer.new()
	strip_row.add_theme_constant_override("separation", 20)
	strip.add_child(strip_row)
	var players_box := VBoxContainer.new()
	players_box.add_theme_constant_override("separation", 10)
	players_heading = _text("", null, 20, HEADING)
	players_box.add_child(players_heading)
	players_row = HBoxContainer.new()
	players_row.add_theme_constant_override("separation", 10)
	players_box.add_child(players_row)
	strip_row.add_child(players_box)
	var divider := ColorRect.new()
	divider.color = STRIP_EDGE
	divider.custom_minimum_size.x = 2
	strip_row.add_child(divider)
	var coaches_box := VBoxContainer.new()
	coaches_box.add_theme_constant_override("separation", 10)
	coaches_heading = _text("", null, 20, HEADING)
	coaches_box.add_child(coaches_heading)
	coaches_row = HBoxContainer.new()
	coaches_row.add_theme_constant_override("separation", 10)
	coaches_box.add_child(coaches_row)
	strip_row.add_child(coaches_box)

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

	_build_board()
	_refresh_squad()

## The board, from RunState. A signed player's slot is null: it shows as a torn scrap on a pin.
## Only rebuilt on open and after Scout again, so buying never moves anything.
func _build_board() -> void:
	for child in board_row.get_children():
		board_row.remove_child(child)       ## out now, not at the end of the frame
		child.queue_free()
	_paid_holders.clear()
	_paid_slots.clear()
	var paid: Array = []
	for s in RunState.transfer_list:
		if s == null:
			var slot := _empty_slot(PIN_RED, true)
			_paid_slots.append(slot)
			paid.append(slot)
		else:
			var holder := _hold(_report(s, false))
			_paid_holders.append(holder)
			paid.append(holder)
	board_row.add_child(_group("Transfer list", paid))
	var free: Array = []
	for s in RunState.free_agents:
		free.append(_hold(_report(s, true)) if s != null else _empty_slot(FREE_GREEN, true))
	board_row.add_child(_group("Free agents", free))
	var note_holder := VBoxContainer.new()
	note_holder.alignment = BoxContainer.ALIGNMENT_CENTER
	note_holder.add_child(_scout_note())
	board_row.add_child(note_holder)

## The squad: players fill the 7 player slots, coaches the 2 coach slots; the rest show as empty.
func _refresh_squad() -> void:
	_fill_row(players_row, RunState.players(), RunState.MAX_PLAYERS, "PLAYER", GOLD)
	_fill_row(coaches_row, RunState.coaches(), RunState.MAX_COACHES, "COACH", BLUE)
	players_heading.text = "PLAYERS  %d / %d  ·  CLICK TO SELL FOR HALF" % [
			RunState.players().size(), RunState.MAX_PLAYERS]
	coaches_heading.text = "COACHES  %d / %d" % [RunState.coaches().size(), RunState.MAX_COACHES]
	coins_label.text = "%d coins" % CoinState.coins

func _fill_row(row: HBoxContainer, staff: Array, places: int, label: String, edge: Color) -> void:
	for child in row.get_children():
		row.remove_child(child)             ## out now, so slot positions are right straight away
		child.queue_free()
	for s in staff:
		row.add_child(_owned_tile(s, edge))
	for i in places - staff.size():
		row.add_child(_empty_tile(label))

## The row and slot a member of staff sits in (null if there's no slot for him).
func _slot_of(s: StaffCard) -> Control:
	var row := coaches_row if s is CoachCard else players_row
	var list := RunState.coaches() if s is CoachCard else RunState.players()
	var index := list.find(s)
	if index < 0 or index >= row.get_child_count():
		return null
	return row.get_child(index)

# ---------- Buying and selling ----------

func _buy(s: StaffCard, free: bool, report: Button) -> void:
	if busy:
		return
	if RunState.squad_full_for(s):
		message_label.text = "No %s slot free: sell someone first" % ("coach" if s is CoachCard else "player")
		return
	var cost := 0 if free else RunState.staff_price(s)
	if not CoinState.can_afford(cost):
		message_label.text = "Not enough coins"
		return
	CoinState.deduct_coins(cost)
	RunState.add_player(s)
	## Keep his place in the list (null = signed), so the board doesn't shuffle.
	var list: Array = RunState.free_agents if free else RunState.transfer_list
	list[list.find(s)] = null
	message_label.text = "Signed: %s" % s.display_name
	coins_label.text = "%d coins" % CoinState.coins
	busy = true
	await _pull_off(report, FREE_GREEN if free else PIN_RED, _slot_of(s))
	busy = false
	_refresh_squad()
	_flash_new_tile(s)

## Pull a report off the board: it tugs on its pin, tears free (the scrap and mark appear under
## the pin, which bounces), lifts towards you and swings loose, then flies into `landing`
## (his empty squad slot), shrinking onto it.
func _pull_off(report: Button, pin_colour: Color, landing: Control) -> void:
	var holder := report.get_parent()
	var row := holder.get_parent()
	var slot := _empty_slot(pin_colour, false)   ## just the pin for now: it tears in a moment
	row.add_child(slot)
	row.move_child(slot, holder.get_index())     ## in his exact place
	_paid_holders.erase(holder)
	if pin_colour == PIN_RED:
		_paid_slots.append(slot)                 ## a transfer-list slot: Scout again clears it
	_lift_out(report)
	row.remove_child(holder)
	holder.queue_free()
	## Where to land: the middle of his squad slot (the report turns about its top-middle pin,
	## so aim that point half a shrunken report above the slot's centre).
	var target := players_row.global_position
	if landing != null:
		var centre := landing.global_position + landing.size / 2.0
		target = centre - Vector2(REPORT_SIZE.x / 2.0, REPORT_SIZE.y * FLY_SCALE / 2.0)
	var t := create_tween()
	## 1. Tug: it wiggles on its pin.
	for angle in [-4.0, 4.0, -3.0, 0.0]:
		t.tween_property(report, "rotation_degrees", angle, SettingsState.t(TUG_TIME))
	## 2. It tears free: the report's own pin goes, the scrap appears under the board's pin.
	t.tween_callback(report.get_node("Pin").hide)
	t.tween_callback(_tear.bind(slot))
	t.tween_property(report, "scale", Vector2(1.08, 1.08), SettingsState.t(LIFT_TIME)) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(report, "rotation_degrees", 14.0, SettingsState.t(LIFT_TIME))
	t.parallel().tween_property(report, "position:y", report.position.y - 24, SettingsState.t(LIFT_TIME))
	## 3. Into his squad slot, shrinking and straightening, fading as it lands.
	t.tween_property(report, "global_position", target, SettingsState.t(FLY_TIME)) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(report, "rotation_degrees", 0.0, SettingsState.t(FLY_TIME))
	t.parallel().tween_property(report, "scale", Vector2(FLY_SCALE, FLY_SCALE), SettingsState.t(FLY_TIME))
	t.parallel().tween_property(report, "modulate:a", 0.0, SettingsState.t(FLY_TIME * 0.4)) \
			.set_delay(SettingsState.t(FLY_TIME * 0.6))
	await t.finished
	report.queue_free()

## The moment it tears: the faint mark and the torn scrap appear under the pin, and the pin bounces.
func _tear(slot: Control) -> void:
	_add_mark(slot)
	_add_scrap(slot)
	var pin: Control = slot.get_node("Pin")
	slot.move_child(pin, -1)                     ## the pin stays on top of the scrap
	pin.pivot_offset = pin.size / 2.0
	pin.scale = Vector2(1.6, 1.6)
	create_tween().tween_property(pin, "scale", Vector2.ONE, SettingsState.t(0.2)) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## The newly signed player's slot flashes gold as his report lands in it.
func _flash_new_tile(s: StaffCard) -> void:
	var tile := _slot_of(s)
	if tile == null:
		return
	tile.modulate = ARRIVE_FLASH
	create_tween().tween_property(tile, "modulate", Color.WHITE, SettingsState.t(0.5))

func _sell(s: StaffCard) -> void:
	if busy:
		return
	CoinState.add_coins(RunState.sell_price(s))
	RunState.remove_player(s)
	message_label.text = "Sold: %s (+%d)" % [s.display_name, RunState.sell_price(s)]
	_refresh_squad()

# ---------- Scout again ----------

func _scout() -> void:
	if busy:
		return
	var cost := RunState.scout_cost()
	if not CoinState.can_afford(cost):
		message_label.text = "Not enough coins to scout again"
		return
	CoinState.deduct_coins(cost)
	coins_label.text = "%d coins" % CoinState.coins
	RunState.scout_again()
	message_label.text = "New names on the transfer list"
	busy = true
	await _clear_transfer_list()
	_build_board()
	_refresh_squad()
	for i in _paid_holders.size():
		_pin_up(_paid_holders[i], i * PIN_UP_GAP)
	busy = false

## The old transfer list comes down, left to right: each pin pops out, then its report (or the
## torn scrap an earlier signing left) drops to the floor, spinning and drifting a little.
func _clear_transfer_list() -> void:
	if _paid_holders.is_empty() and _paid_slots.is_empty():
		return
	var falling: Array = []
	var t := create_tween().set_parallel(true)
	var i := 0
	## Reports: lift each out of its holder so it can fall past the board.
	for holder in _paid_holders:
		var report: Control = holder.get_child(0)
		_lift_out(report)
		falling.append(report)
		var fall := _pop_pin(t, report.get_node("Pin"), i)
		_drop(t, report, fall)
		i += 1
	## Empty slots: the pin pops, the scrap (and its shadow) drops, the faint mark fades.
	for slot in _paid_slots:
		var fall := _pop_pin(t, slot.get_node("Pin"), i)
		for piece in slot.get_children():
			if piece is Polygon2D:
				piece.reparent(self)               ## keeps its place on screen, so it can fall past the board
				falling.append(piece)
				_drop(t, piece, fall)
			elif piece is ColorRect:
				t.tween_property(piece, "modulate:a", 0.0, SettingsState.t(FALL_TIME * 0.5)).set_delay(fall)
		i += 1
	await t.finished
	for piece in falling:
		piece.queue_free()

## A pin pops out (grows a little, then fades). Returns when, in the tween, the paper should fall.
func _pop_pin(t: Tween, pin: Control, order: int) -> float:
	var delay := SettingsState.t(order * FALL_GAP)
	pin.pivot_offset = pin.size / 2.0
	t.tween_property(pin, "scale", Vector2(1.5, 1.5), SettingsState.t(PIN_POP_TIME * 0.5)).set_delay(delay)
	t.tween_property(pin, "modulate:a", 0.0, SettingsState.t(PIN_POP_TIME * 0.5)) \
			.set_delay(delay + SettingsState.t(PIN_POP_TIME * 0.5))
	return delay + SettingsState.t(PIN_POP_TIME)

## Something drops to the floor: speeds up like gravity, spins and drifts a little.
func _drop(t: Tween, thing: CanvasItem, delay: float) -> void:
	t.tween_property(thing, "position:y", thing.position.y + FALL_DISTANCE, SettingsState.t(FALL_TIME)) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(delay)
	t.tween_property(thing, "position:x", thing.position.x + randf_range(-FALL_DRIFT, FALL_DRIFT),
			SettingsState.t(FALL_TIME)).set_delay(delay)
	t.tween_property(thing, "rotation_degrees", randf_range(-FALL_SPIN, FALL_SPIN),
			SettingsState.t(FALL_TIME)).set_delay(delay)

## A new report is pinned up: it drops onto the board from slightly above, settles,
## then its pin pushes in with a little bounce.
func _pin_up(holder: Control, delay: float) -> void:
	var report: Control = holder.get_child(0)
	var pin: Control = report.get_node("Pin")
	var rest_tilt := report.rotation_degrees
	report.modulate.a = 0.0
	report.position = Vector2(0, -40)
	report.scale = Vector2(1.1, 1.1)
	report.rotation_degrees = rest_tilt + randf_range(-6.0, 6.0)
	pin.pivot_offset = pin.size / 2.0
	pin.scale = Vector2.ZERO
	var t := create_tween()
	t.tween_interval(SettingsState.t(delay))
	t.tween_property(report, "modulate:a", 1.0, SettingsState.t(PIN_UP_TIME * 0.5))
	t.parallel().tween_property(report, "position", Vector2.ZERO, SettingsState.t(PIN_UP_TIME)) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(report, "scale", Vector2.ONE, SettingsState.t(PIN_UP_TIME))
	t.parallel().tween_property(report, "rotation_degrees", rest_tilt, SettingsState.t(PIN_UP_TIME))
	t.tween_property(pin, "scale", Vector2(1.5, 1.5), SettingsState.t(0.06))
	t.tween_property(pin, "scale", Vector2.ONE, SettingsState.t(0.14)) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Take a report out of its holder and put it on top of the whole screen, in the same spot,
## so it can move anywhere (fly to the squad, fall to the floor) without being clipped or laid out.
func _lift_out(report: Control) -> void:
	var start := report.global_position
	report.get_parent().remove_child(report)
	add_child(report)
	report.global_position = start

func _start_season() -> void:
	RunState.transfer_window_due = false
	get_tree().change_scene_to_file(RunState.HUB_SCENE)

# ---------- The board ----------

## A strip of masking tape with a label, then the reports (or empty pins) underneath.
func _group(title: String, items: Array) -> VBoxContainer:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 28)
	var tape := _panel(TAPE, TAPE, 0, 2, 4)
	tape.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tape.add_child(_text(title, _marker, 26, INK))
	group.add_child(tape)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	group.add_child(row)
	for item in items:
		row.add_child(item)
	return group

## A plain holder for a report: it keeps the report's place in the row, while the report
## inside can tilt, move and scale (containers would reset those). Rests at a slight tilt.
func _hold(report: Button) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = REPORT_SIZE
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(report)
	report.pivot_offset = Vector2(REPORT_SIZE.x / 2.0, 0)   ## turns about its pin
	report.rotation_degrees = randf_range(-REST_TILT, REST_TILT)
	return holder

## Where a signed player's report was: his pin, and (once torn) a faint mark and a torn scrap.
func _empty_slot(pin_colour: Color, torn: bool) -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = REPORT_SIZE
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if torn:
		_add_mark(slot)
		_add_scrap(slot)
	_pin(slot, pin_colour)
	return slot

## The faint mark a report leaves on the cork (always behind everything else in the slot).
func _add_mark(slot: Control) -> void:
	var mark := ColorRect.new()
	mark.color = MARK
	mark.size = REPORT_SIZE
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(mark)
	slot.move_child(mark, 0)

## A small torn scrap of the report's top edge, left under the pin: straight along the card's
## top, ragged along the bottom, never the same twice.
func _add_scrap(slot: Control) -> void:
	var half := SCRAP_WIDTH / 2.0
	var points := PackedVector2Array([Vector2(-half, 0), Vector2(half, 0)])
	var x := half
	while x > -half:                             ## walk back along a ragged bottom edge
		points.append(Vector2(x, randf_range(SCRAP_DEPTH.x, SCRAP_DEPTH.y)))
		x -= randf_range(4.0, 8.0)
	points.append(Vector2(-half, randf_range(SCRAP_DEPTH.x, SCRAP_DEPTH.y)))
	var centre := Vector2(REPORT_SIZE.x / 2.0, 0)   ## the card's top edge, under the pin
	var shadow := Polygon2D.new()
	shadow.polygon = points
	shadow.color = SCRAP_SHADOW
	shadow.position = centre + Vector2(1, 3)
	slot.add_child(shadow)
	var scrap := Polygon2D.new()
	scrap.polygon = points
	scrap.color = PAPER
	scrap.position = centre
	slot.add_child(scrap)

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
	button.pressed.connect(func(): _buy(s, free, button))
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

## A filled slot: his name, what he does, the sell price, with a solid gold (player) or blue (coach) edge.
func _owned_tile(s: StaffCard, edge: Color) -> Button:
	var button := Button.new()
	button.custom_minimum_size = OWNED_SIZE
	button.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed"]:
		var style := _box_style(Color("1e2a22") if state != "hover" else Color("2a3a2e"), 10)
		style.border_color = edge
		style.set_border_width_all(3)
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

## An empty slot: a dark inset box with a faint "PLAYER" or "COACH".
func _empty_tile(label: String) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.custom_minimum_size = OWNED_SIZE
	var style := _box_style(SLOT_FILL, 10)
	style.border_color = STRIP_EDGE
	style.set_border_width_all(2)
	tile.add_theme_stylebox_override("panel", style)
	var word := _text(label, null, 18, SLOT_LABEL)
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tile.add_child(word)
	return tile

# ---------- Helpers ----------

## A flat paper-coloured button (hover: a thin gold edge).
func _paper_button(size: Vector2, colour: Color) -> Button:
	var button := Button.new()
	button.custom_minimum_size = size
	button.size = size
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

## A drawing pin at the top middle (named "Pin" so a report coming off can leave it behind).
func _pin(parent: Control, colour: Color) -> void:
	var pin := Panel.new()
	pin.name = "Pin"
	pin.size = Vector2(18, 18)
	pin.position = Vector2(parent.custom_minimum_size.x / 2.0 - 9, -8)
	pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _box_style(colour, 9)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 3
	pin.add_theme_stylebox_override("panel", style)
	parent.add_child(pin)

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
