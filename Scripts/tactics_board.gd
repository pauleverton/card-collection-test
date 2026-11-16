class_name TacticsBoard
extends Control
## The whiteboard on the team sheet: an aluminium frame and a full pitch in marker.
## Left margin: your starters written in (name, effect, games left). On the pitch: a red
## magnet with a name for each. Right margin: the manager's notes.
## Taking a player off rubs him out with a duster (erase_starter); putting one on writes
## him in (write_in).
## A view: it shows what it's given and says when a magnet is clicked. No decisions here.

signal magnet_clicked(player: PlayerCard)

const BOARD_SIZE := Vector2(1200, 540)
const FRAME := 12
const FRAME_COLOUR := Color("c9ced2")
const CORNER_COLOUR := Color("8e959b")
const BOARD_COLOUR := Color("f7f7f4")
const LINE := Color("1a1a1a")
const LINE_WIDTH := 3.0
## Real proportions: 105 × 68 m at about 6.5 px per metre, centred on the board.
const PITCH_SIZE := Vector2(680, 442)
const PITCH_TOP := 50
const PITCH_METRES := 105.0
const MARGIN_GAP := 24           ## space between the pitch and the writing either side
## Where the magnets stand, as fractions of the pitch (0,0 = top-left), filled in pick order.
## Only places for now: players have no positions.
const SLOT_SPOTS := [Vector2(0.30, 0.42), Vector2(0.68, 0.22), Vector2(0.68, 0.66),
		Vector2(0.42, 0.80), Vector2(0.42, 0.10)]
const MAGNET_RED := Color("d3302f")
const MAGNET_SIZE := 46
const MAGNET_WIDTH := 180
const MAGNET_HEIGHT := 90
const PIP_FULL := Color("2f7a3a")
const PIP_EMPTY := Color("9aa59b")
const SOFT_TEXT := Color("4a4f4b")
const NOTE_COLOURS := {"blue": Color("2b5bc4"), "red": Color("c9302c"), "black": Color("1a1a1a")}
const LIST_NAME_SIZE := 24
const LIST_EFFECT_SIZE := 18
const NOTE_SIZE := 21
const NOTE_MARKER_SIZE := 28
const NOTE_TILT := 1.0           ## degrees: the notes lean a little (away from the pitch)

## Rubbing out and writing in (seconds, scaled by the game speed setting).
const ERASE_TIME := 0.8          ## the whole scrub
const ERASE_PASSES := 5          ## back-and-forth strokes of the duster
const ERASE_WOBBLE := 8.0        ## how far each stroke wanders from a straight line (px)
const WRITE_TIME := 0.4
const DUSTER_SIZE := Vector2(84, 44)
const DUSTER_TOP := Color("2b5bc4")     ## plastic handle
const DUSTER_FELT := Color("6b6f73")
## The grey streaks a rub leaves behind. Alpha (the last number) = how strong they are.
const SMEAR := Color(0.45, 0.47, 0.45, 0.3)
const SMEAR_HOLD := 1.0          ## seconds the streaks stay before fading
const SMEAR_TIME := 1.5          ## seconds they take to fade

## Fonts (exact capitals matter: macOS ignores them, exports don't).
## Optional: if a file is missing, Godot's default font is used.
const MARKER_FONT := "res://Images+themes/Themes/permanent_marker.ttf"
const HAND_FONT := "res://Images+themes/Themes/kalam_bold.ttf"

var _marker: Font
var _hand: Font
var _team_pieces: Array = []     ## the starters list and magnets, rebuilt by show_team
var _note_pieces: Array = []
var _entry_of := {}              ## player → his name in the left margin
var _magnet_of := {}             ## player → his magnet on the pitch

func _init() -> void:
	custom_minimum_size = BOARD_SIZE
	_marker = _load_font(MARKER_FONT)
	_hand = _load_font(HAND_FONT)
	var hint := _text("Click a magnet to take him off", null, 16, Color(SOFT_TEXT, 0.8))
	hint.position = Vector2(BOARD_SIZE.x - FRAME - 420, FRAME + 10)
	hint.custom_minimum_size.x = 400
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(hint)

static func _load_font(path: String) -> Font:
	if ResourceLoader.exists(path):
		return load(path)
	push_warning("TacticsBoard: font not found at %s, using the default" % path)
	return null

# ---------- What the screen calls ----------

## Write the team in the left margin and put a magnet on the pitch for each starter.
func show_team(starters: Array, places: int) -> void:
	for piece in _team_pieces:
		piece.queue_free()
	_team_pieces.clear()
	_entry_of.clear()
	_magnet_of.clear()

	var column := _column(Vector2(FRAME + 16, PITCH_TOP), 0.0)
	_team_pieces.append(column)
	column.add_child(_text("STARTING %d" % places, _marker, 24, NOTE_COLOURS["red"]))
	for i in places:
		var p: PlayerCard = starters[i] if i < starters.size() else null
		var entry := _list_entry(i + 1, p)
		column.add_child(entry)
		if p != null:
			_entry_of[p] = entry

	var pitch := _pitch_rect()
	for i in places:
		var spot: Vector2 = pitch.position + pitch.size * SLOT_SPOTS[i % SLOT_SPOTS.size()]
		var p: PlayerCard = starters[i] if i < starters.size() else null
		var magnet := _magnet(p) if p != null else _empty_magnet()
		add_child(magnet)
		magnet.position = spot - Vector2(MAGNET_WIDTH / 2.0, MAGNET_SIZE / 2.0)
		_team_pieces.append(magnet)
		if p != null:
			_magnet_of[p] = magnet

## Write the manager's notes down the right margin (from BoardNotes.pick()).
func show_notes(notes: Array) -> void:
	for piece in _note_pieces:
		piece.queue_free()
	_note_pieces.clear()
	var column := _column(Vector2(_pitch_rect().end.x + MARGIN_GAP, PITCH_TOP), -NOTE_TILT)
	_note_pieces.append(column)
	for note in notes:
		var marker: bool = note.get("style", "") == "marker"
		var label := _text(note["text"], _marker if marker else _hand,
				NOTE_MARKER_SIZE if marker else NOTE_SIZE, NOTE_COLOURS.get(note["colour"], LINE))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = _margin_width()
		column.add_child(label)

## Rub a starter out: a duster scrubs back and forth across his name, the writing fading a bit
## with each stroke and leaving grey streaks; his magnet fades off the pitch. Await it, then rebuild.
func erase_starter(p: PlayerCard) -> void:
	var entry: Control = _entry_of.get(p)
	var magnet: Control = _magnet_of.get(p)
	if entry == null:
		return
	var rect := Rect2(entry.global_position - global_position, entry.size).grow(6)
	var duster := _duster()
	duster.position = Vector2(rect.position.x - DUSTER_SIZE.x * 0.5, rect.position.y - DUSTER_SIZE.y * 0.5)
	var step := SettingsState.t(ERASE_TIME) / ERASE_PASSES
	if magnet != null:
		create_tween().tween_property(magnet, "modulate:a", 0.0, SettingsState.t(ERASE_TIME))
	var t := create_tween()
	for i in ERASE_PASSES:
		## Alternate right and left, a little lower each stroke, never quite straight.
		var y := rect.position.y + rect.size.y * (i + 0.5) / ERASE_PASSES - DUSTER_SIZE.y * 0.5
		var x := rect.end.x if i % 2 == 0 else rect.position.x
		var to := Vector2(x - DUSTER_SIZE.x * 0.5 + randf_range(-ERASE_WOBBLE, ERASE_WOBBLE) * 2,
				y + randf_range(-ERASE_WOBBLE, ERASE_WOBBLE))
		t.tween_property(duster, "position", to, step).set_trans(Tween.TRANS_SINE)
		t.parallel().tween_property(duster, "rotation_degrees", randf_range(-12, 4), step)
		t.parallel().tween_property(entry, "modulate:a", 1.0 - float(i + 1) / ERASE_PASSES, step)
		t.tween_callback(_streak.bind(rect, y + DUSTER_SIZE.y * 0.5, duster))
	## Lift the duster off.
	t.tween_property(duster, "modulate:a", 0.0, SettingsState.t(0.15))
	await t.finished
	duster.queue_free()

## Write a new starter in: his name appears left to right and his magnet pops on.
## Call straight after show_team; await it.
func write_in(p: PlayerCard) -> void:
	var entry: Control = _entry_of.get(p)
	var magnet: Control = _magnet_of.get(p)
	if entry == null:
		return
	entry.modulate.a = 0.0                     ## hidden until the cover is in place
	await get_tree().process_frame             ## let the list find its layout first
	var rect := Rect2(entry.global_position - global_position, entry.size).grow(4)
	var cover := _board_patch(rect)
	entry.modulate.a = 1.0
	var t := create_tween().set_parallel(true)
	t.tween_property(cover, "position:x", rect.end.x, SettingsState.t(WRITE_TIME))
	t.tween_property(cover, "size:x", 0.0, SettingsState.t(WRITE_TIME))
	if magnet != null:
		magnet.pivot_offset = Vector2(MAGNET_WIDTH / 2.0, MAGNET_SIZE / 2.0)
		magnet.scale = Vector2(1.3, 1.3)
		t.tween_property(magnet, "scale", Vector2.ONE, SettingsState.t(0.2)).set_trans(Tween.TRANS_BACK)
	await t.finished
	cover.queue_free()

# ---------- Drawing the board ----------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, BOARD_SIZE), FRAME_COLOUR)
	draw_rect(Rect2(Vector2(FRAME, FRAME), BOARD_SIZE - Vector2(FRAME, FRAME) * 2), BOARD_COLOUR)
	for corner in [Vector2.ZERO, Vector2(BOARD_SIZE.x, 0), Vector2(0, BOARD_SIZE.y), BOARD_SIZE]:
		draw_rect(Rect2(corner - Vector2(13, 13), Vector2(26, 26)), CORNER_COLOUR)
	_draw_pitch(_pitch_rect())

func _pitch_rect() -> Rect2:
	return Rect2(Vector2((BOARD_SIZE.x - PITCH_SIZE.x) / 2.0, PITCH_TOP), PITCH_SIZE)

## Width of the writing space either side of the pitch.
func _margin_width() -> float:
	return (BOARD_SIZE.x - PITCH_SIZE.x) / 2.0 - FRAME - 16 - MARGIN_GAP

## A full pitch in real measurements (metres × m = pixels).
func _draw_pitch(r: Rect2) -> void:
	var m := r.size.x / PITCH_METRES
	var mid_y := r.position.y + r.size.y / 2.0
	var half_x := r.position.x + r.size.x / 2.0
	draw_rect(r, LINE, false, LINE_WIDTH)
	draw_line(Vector2(half_x, r.position.y), Vector2(half_x, r.end.y), LINE, LINE_WIDTH)
	draw_arc(Vector2(half_x, mid_y), 9.15 * m, 0, TAU, 64, LINE, LINE_WIDTH)
	draw_circle(Vector2(half_x, mid_y), 4, LINE)
	for side in [0, 1]:
		var goal_x := r.position.x if side == 0 else r.end.x
		var dir := 1.0 if side == 0 else -1.0          ## +1 = into the pitch from the left goal line
		_draw_box(goal_x, dir, 16.5 * m, 40.32 * m, mid_y)     ## penalty box
		_draw_box(goal_x, dir, 5.5 * m, 18.32 * m, mid_y)      ## six-yard box
		_draw_box(goal_x, -dir, 2.0 * m, 7.32 * m, mid_y)      ## the goal, behind the line
		var spot := Vector2(goal_x + dir * 11.0 * m, mid_y)
		draw_circle(spot, 4, LINE)
		## The D: the part of the 9.15 m circle round the spot that's outside the box.
		var reach := acos((16.5 - 11.0) / 9.15)
		var facing := 0.0 if side == 0 else PI
		draw_arc(spot, 9.15 * m, facing - reach, facing + reach, 24, LINE, LINE_WIDTH)

## A box against a goal line, `depth` into the pitch (dir +1 = to the right).
func _draw_box(goal_x: float, dir: float, depth: float, width: float, mid_y: float) -> void:
	var x0 := goal_x if dir > 0 else goal_x - depth
	draw_rect(Rect2(x0, mid_y - width / 2.0, depth, width), LINE, false, LINE_WIDTH)

# ---------- The starters list (left margin) ----------

## "1. Twinkle Toes", his effect in blue, then ●●○ games left. Empty place: "2. ________".
func _list_entry(number: int, p: PlayerCard) -> VBoxContainer:
	var entry := VBoxContainer.new()
	entry.add_theme_constant_override("separation", 0)
	entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if p == null:
		entry.add_child(_text("%d. ________" % number, _marker, LIST_NAME_SIZE, Color(LINE, 0.3)))
		return entry
	entry.add_child(_text("%d. %s" % [number, p.display_name], _marker, LIST_NAME_SIZE, LINE))
	var effect := _text(p.description, _hand, LIST_EFFECT_SIZE, NOTE_COLOURS["blue"])
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect.custom_minimum_size.x = _margin_width()
	entry.add_child(effect)
	entry.add_child(_games_row(p))
	return entry

## ●●○ 2 of 3 left
func _games_row(p: PlayerCard) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var left := LeagueState.appearances_left(p)
	for i in p.max_appearances():
		row.add_child(_pip(i < left))
	row.add_child(_text("%d of %d left" % [left, p.max_appearances()], null, 14, SOFT_TEXT))
	return row

func _pip(full: bool) -> Panel:
	var pip := Panel.new()
	pip.custom_minimum_size = Vector2(11, 11)
	pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(6)
	if full:
		style.bg_color = PIP_FULL
	else:
		style.bg_color = Color(0, 0, 0, 0)
		style.border_color = PIP_EMPTY
		style.set_border_width_all(2)
	pip.add_theme_stylebox_override("panel", style)
	return pip

# ---------- Magnets (on the pitch) ----------

func _magnet(p: PlayerCard) -> Button:
	var button := _magnet_button()
	var box: VBoxContainer = button.get_child(0)
	box.add_child(_dot(false))
	box.add_child(_patch(_text(p.display_name, _marker, 22, LINE)))
	_ignore_mouse(box)
	button.pressed.connect(func(): magnet_clicked.emit(p))
	return button

## An open place: a hollow circle with "+".
func _empty_magnet() -> Button:
	var button := _magnet_button()
	var box: VBoxContainer = button.get_child(0)
	var dot := _dot(true)
	var plus := _text("+", null, 30, Color(LINE, 0.5))
	plus.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dot.add_child(plus)
	box.add_child(dot)
	_ignore_mouse(box)
	return button

## A see-through button holding a column: the magnet on top, the name underneath.
func _magnet_button() -> Button:
	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(MAGNET_WIDTH, MAGNET_HEIGHT)
	button.size = button.custom_minimum_size
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	button.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return button

## The round magnet (or a hollow circle for an empty place).
func _dot(empty: bool) -> Panel:
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(MAGNET_SIZE, MAGNET_SIZE)
	dot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(int(MAGNET_SIZE / 2.0))
	if empty:
		style.bg_color = Color(0, 0, 0, 0)
		style.border_color = Color(LINE, 0.45)
		style.set_border_width_all(3)
	else:
		style.bg_color = MAGNET_RED
		style.shadow_color = Color(0, 0, 0, 0.35)
		style.shadow_size = 5
		style.shadow_offset = Vector2(0, 3)
	dot.add_theme_stylebox_override("panel", style)
	return dot

## A patch of clean board behind a name, as if the lines were wiped off to write on.
func _patch(content: Control) -> PanelContainer:
	var patch := PanelContainer.new()
	patch.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = BOARD_COLOUR
	style.set_corner_radius_all(6)
	style.content_margin_left = 6
	style.content_margin_right = 6
	patch.add_theme_stylebox_override("panel", style)
	patch.add_child(content)
	return patch

# ---------- Rubbing out ----------

## A plain board-coloured rectangle (the cover that reveals new writing).
func _board_patch(rect: Rect2) -> ColorRect:
	var patch := ColorRect.new()
	patch.color = BOARD_COLOUR
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	patch.position = rect.position
	patch.size = rect.size
	add_child(patch)
	return patch

## A whiteboard duster: plastic handle on top, felt underneath, tilted like it's in a hand.
func _duster() -> PanelContainer:
	var duster := PanelContainer.new()
	duster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	duster.custom_minimum_size = DUSTER_SIZE
	duster.pivot_offset = DUSTER_SIZE * 0.5
	duster.rotation_degrees = -8
	var style := StyleBoxFlat.new()
	style.bg_color = DUSTER_TOP
	style.set_corner_radius_all(8)
	style.border_color = DUSTER_FELT
	style.border_width_bottom = 12                ## the felt strip along the bottom
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 6
	style.shadow_offset = Vector2(2, 4)
	duster.add_theme_stylebox_override("panel", style)
	add_child(duster)
	return duster

## One grey streak along a stroke of the duster: uneven length, thickness and angle.
## It stays for SMEAR_HOLD, then fades over SMEAR_TIME. Drawn under the duster.
func _streak(rect: Rect2, y: float, duster: Control) -> void:
	var streak := Panel.new()
	streak.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var length := rect.size.x * randf_range(0.6, 1.0)
	var thickness := randf_range(6.0, 14.0)
	streak.size = Vector2(length, thickness)
	streak.position = Vector2(rect.position.x + randf_range(0.0, rect.size.x - length), y - thickness * 0.5)
	streak.pivot_offset = streak.size * 0.5
	streak.rotation_degrees = randf_range(-3.0, 3.0)
	var style := StyleBoxFlat.new()
	style.bg_color = SMEAR
	style.set_corner_radius_all(int(thickness / 2.0))
	streak.add_theme_stylebox_override("panel", style)
	add_child(streak)
	move_child(streak, duster.get_index())        ## under the duster
	var t := create_tween()
	t.tween_interval(SettingsState.t(SMEAR_HOLD))
	t.tween_property(streak, "modulate:a", 0.0, SettingsState.t(SMEAR_TIME))
	t.tween_callback(streak.queue_free)

# ---------- Helpers ----------

## A column of writing at `at`, as wide as a margin, leaning `tilt` degrees.
func _column(at: Vector2, tilt: float) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.position = at
	column.custom_minimum_size.x = _margin_width()
	column.rotation_degrees = tilt
	add_child(column)
	return column

func _text(text: String, font: Font, font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	if font != null:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

## Clicks go to the magnet's button, not the pieces inside it.
func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)
