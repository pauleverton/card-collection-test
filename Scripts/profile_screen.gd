extends Control
## The first screen: "Who's playing?" Three season tickets, one per profile.
## A signed-up ticket shows the manager's name, best finish, runs played and any run in progress;
## pick it to play as that manager. An empty ticket signs up a new manager (type a name).
## The last profile used is outlined in gold and has the keyboard focus, so Enter plays straight on.
## "Rename or delete…" (bottom right) puts the tickets in edit mode: each shows Rename and Delete.

const MAIN_MENU := "res://Scenes/main_menu.tscn"
const BACKGROUND := "res://Images+themes/background.jpg"
const MARKER_FONT := "res://Images+themes/Themes/permanent_marker.ttf"
const KALAM_FONT := "res://Images+themes/Themes/kalam_bold.ttf"

const GOLD := Color("f2c14e")
const CREAM := Color("f6f1e3")
const INK := Color("1d241f")                 ## dark text on the tickets
const SOFT_INK := Color("5b5f55")            ## labels on the tickets
const DARK_GREEN := Color("1b2a22")
const PAPER_LINE := Color("d6ccb2")          ## lines and the tear-off edge
const SHADE := Color(0.03, 0.07, 0.05, 0.62) ## darkens the pitch so the tickets stand out
const NAME_LENGTH := 16                      ## longest manager name

## Ticket size and spacing on the 1920×1080 screen.
const TICKET_SIZE := Vector2(495, 610)
const TICKET_GAP := 60
const TILT := [-1.5, 1.0, -0.5]              ## degrees, so the three don't look machine-placed
const LIFT := 10                             ## how far the last-used ticket sits up

var _marker: Font
var _kalam: Font
var _sign_up: ColorRect = null               ## the "new manager" box (dark layer + panel)
var _name_edit: LineEdit
var _sign_up_button: Button
var _sign_up_ticket := 0                     ## which ticket the name box is for
var _renaming := false                       ## the name box is renaming a ticket (not signing up)
var _delete_box: ColorRect = null            ## "Delete Alex's ticket?" (dark layer + panel)
var _editing := false                        ## edit mode: tickets show Rename and Delete
var _row: HBoxContainer                      ## the three tickets
var _subtitle: Label
var _edit_button: Button


func _ready() -> void:
	_marker = load(MARKER_FONT) if ResourceLoader.exists(MARKER_FONT) else null
	_kalam = load(KALAM_FONT) if ResourceLoader.exists(KALAM_FONT) else null

	var pitch := TextureRect.new()
	pitch.texture = load(BACKGROUND)
	pitch.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pitch.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(pitch)
	pitch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = SHADE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var page := VBoxContainer.new()
	page.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_theme_constant_override("separation", 8)
	add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var title := _label("Who's playing?", 80, GOLD, _marker)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(title)
	_subtitle = _label("Pick your season ticket", 36, CREAM, _kalam)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(_subtitle)

	var gap := Control.new()
	gap.custom_minimum_size.y = 48
	page.add_child(gap)

	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", TICKET_GAP)
	page.add_child(_row)
	_build_tickets()

	var back := Button.new()                      ## bottom left: back to the menu without changing anything
	back.text = "Back"
	UiStyle.secondary(back)
	back.add_theme_font_size_override("font_size", 26)
	back.position = Vector2(64, 980)
	back.pressed.connect(_back)
	add_child(back)

	_edit_button = Button.new()                   ## bottom right: edit mode on / off
	_edit_button.text = "Rename or delete…"
	UiStyle.secondary(_edit_button)
	_edit_button.add_theme_font_size_override("font_size", 26)
	_edit_button.pressed.connect(_toggle_editing)
	add_child(_edit_button)
	_edit_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_edit_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN   ## grows leftwards as its text changes
	_edit_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	for side in ["offset_left", "offset_right"]:
		_edit_button.set(side, -64)
	for side in ["offset_top", "offset_bottom"]:
		_edit_button.set(side, -40)
	_edit_button.visible = SaveState.any_profile()   ## nothing to rename or delete yet


## (Re)build the three tickets: on opening, and after edit mode, a rename or a delete.
func _build_tickets() -> void:
	for old in _row.get_children():
		_row.remove_child(old)
		old.queue_free()
	for p in range(1, SaveState.PROFILES + 1):
		var holder := Control.new()               ## the ticket inside can tilt and lift freely
		holder.custom_minimum_size = TICKET_SIZE + Vector2(0, LIFT)
		_row.add_child(holder)
		var ticket := _ticket(p) if SaveState.profile_exists(p) else _empty_ticket(p)
		ticket.size = TICKET_SIZE
		ticket.position.y = LIFT
		ticket.pivot_offset = TICKET_SIZE / 2
		ticket.rotation_degrees = TILT[p - 1]
		holder.add_child(ticket)
		if p == SaveState.profile and SaveState.profile_exists(p):
			ticket.position.y = 0                 ## last used: lifted, and Enter plays it
			if not _editing:
				ticket.grab_focus.call_deferred()

func _toggle_editing() -> void:
	_editing = not _editing
	_edit_button.text = "Done" if _editing else "Rename or delete…"
	_subtitle.text = "Rename or delete a manager" if _editing else "Pick your season ticket"
	_build_tickets()


## A signed-up manager's ticket.
func _ticket(p: int) -> Button:
	var info := SaveState.summary(p)
	var ticket := _ticket_button(CREAM, GOLD if p == SaveState.profile else CREAM, 7 if p == SaveState.profile else 0)
	ticket.pressed.connect(_play_as.bind(p))

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 0)
	ticket.add_child(stack)
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	## Dark band: SEASON TICKET · No. 1
	var band := PanelContainer.new()
	band.add_theme_stylebox_override("panel", _box(DARK_GREEN, DARK_GREEN, 0, 16, [18, 18, 0, 0]))
	var band_row := HBoxContainer.new()
	band_row.add_child(_label("SEASON TICKET", 20, GOLD))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	band_row.add_child(spacer)
	band_row.add_child(_label("No. %d" % p, 20, PAPER_LINE))
	band.add_child(band_row)
	stack.add_child(band)

	## Name, best finish, runs, the run in progress.
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var body_margin := MarginContainer.new()
	for side in ["left", "right"]:
		body_margin.add_theme_constant_override("margin_" + side, 32)
	body_margin.add_theme_constant_override("margin_top", 24)
	body_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_margin.add_child(body)
	stack.add_child(body_margin)

	var name_label := _label(info["name"], 66, INK, _marker)
	name_label.clip_text = true
	body.add_child(name_label)
	body.add_child(_stat_row("Best finish", info["best"]))
	body.add_child(_stat_row("Runs played", str(info["runs"])))
	if info["run"] != "":
		var run_box := PanelContainer.new()
		run_box.add_theme_stylebox_override("panel", _box(GOLD, GOLD, 0, 14, [12, 12, 12, 12]))
		var run_lines := VBoxContainer.new()
		run_lines.add_child(_label("RUN IN PROGRESS", 18, Color("3d2f08")))
		var run_text := _label(info["run"], 24, INK, _kalam)
		run_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		run_lines.add_child(run_text)
		run_box.add_child(run_lines)
		body.add_child(run_box)
	else:
		var no_run := PanelContainer.new()
		no_run.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0), PAPER_LINE, 3, 14, [12, 12, 12, 12]))
		no_run.add_child(_label("No run in progress", 28, SOFT_INK, _kalam))
		body.add_child(no_run)

	## The tear-off edge and the stub: PLAY, or in edit mode Rename and Delete.
	stack.add_child(_tear_line())
	var edit_buttons: Array = []
	if _editing:
		ticket.disabled = true                    ## the ticket itself does nothing in edit mode
		var stub_row := HBoxContainer.new()
		stub_row.alignment = BoxContainer.ALIGNMENT_CENTER
		stub_row.add_theme_constant_override("separation", 20)
		stub_row.custom_minimum_size.y = 96
		var rename := Button.new()
		rename.text = "Rename"
		UiStyle.primary(rename)
		rename.pressed.connect(_show_sign_up.bind(p, true))
		var delete := Button.new()
		delete.text = "Delete"
		UiStyle.secondary(delete)
		delete.add_theme_color_override("font_color", Color("c9302c"))
		delete.add_theme_color_override("font_hover_color", Color("c9302c"))
		delete.pressed.connect(_show_delete.bind(p))
		for button in [rename, delete]:
			button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			stub_row.add_child(button)
		stack.add_child(stub_row)
		edit_buttons = [rename, delete]
	else:
		var stub := _label("PLAY  ▸", 30, DARK_GREEN)
		stub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		stub.custom_minimum_size.y = 96
		stack.add_child(stub)
	_notches(ticket)
	_ignore_mouse(stack)
	for button in edit_buttons:
		button.mouse_filter = Control.MOUSE_FILTER_STOP   ## these two DO take clicks
	return ticket


## An empty ticket: sign up a new manager.
func _empty_ticket(p: int) -> Button:
	var ticket := _ticket_button(Color(0, 0, 0, 0), Color(CREAM, 0.55), 4)
	ticket.pressed.connect(_show_sign_up.bind(p))
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 14)
	ticket.add_child(stack)
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var plus := _label("+", 72, GOLD)
	plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(plus)
	var heading := _label("New manager", 46, CREAM, _marker)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(heading)
	var free := _label("Ticket No. %d is free" % p, 30, Color("d6d0bf"), _kalam)
	free.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(free)
	_ignore_mouse(stack)
	return ticket


func _back() -> void:
	SaveState.start_after_sign_up = false        ## changed their mind: no team name box
	get_tree().change_scene_to_file(MAIN_MENU)

## Play as manager p: their progress is loaded, then the main menu (Continue or Start new game).
func _play_as(p: int) -> void:
	SaveState.use_profile(p)
	get_tree().change_scene_to_file(MAIN_MENU)


# ---------- The name box: a new manager, or renaming one ----------

func _show_sign_up(p: int, renaming := false) -> void:
	if _sign_up != null:
		return
	_sign_up_ticket = p
	_renaming = renaming
	_sign_up = ColorRect.new()
	_sign_up.color = Color(0, 0, 0, 0.75)        ## also stops clicks reaching the tickets
	add_child(_sign_up)
	_sign_up.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(DARK_GREEN, GOLD, 3, 40, [12, 12, 12, 12]))
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	vbox.add_child(_label("Season ticket No. %d" % p, 22, PAPER_LINE))
	vbox.add_child(_label("Manager's name", 44, GOLD, _marker))
	_name_edit = LineEdit.new()
	_name_edit.max_length = NAME_LENGTH
	_name_edit.placeholder_text = "Your name"
	_name_edit.custom_minimum_size = Vector2(560, 72)
	_name_edit.add_theme_font_size_override("font_size", 36)
	if renaming:
		_name_edit.text = SaveState.summary(p)["name"]
		_name_edit.select_all()                  ## typing replaces the old name
	_name_edit.text_changed.connect(_on_name_changed)
	_name_edit.text_submitted.connect(func(_text): _confirm_sign_up())
	vbox.add_child(_name_edit)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 24)
	var cancel := Button.new()
	cancel.text = "Cancel"
	UiStyle.secondary(cancel)
	cancel.pressed.connect(_close_sign_up)
	_sign_up_button = Button.new()
	_sign_up_button.text = "Save" if renaming else "Sign up"
	UiStyle.primary(_sign_up_button)
	_sign_up_button.disabled = _name_edit.text.strip_edges() == ""   ## until there's a name
	_sign_up_button.pressed.connect(_confirm_sign_up)
	buttons.add_child(cancel)
	buttons.add_child(_sign_up_button)
	vbox.add_child(buttons)

	panel.add_child(vbox)
	_sign_up.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH   ## stays centred
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_name_edit.grab_focus.call_deferred()

func _on_name_changed(text: String) -> void:
	_sign_up_button.disabled = text.strip_edges() == ""

func _confirm_sign_up() -> void:
	var manager := _name_edit.text.strip_edges()
	if manager == "":
		return
	if _renaming:                                ## edit mode: new name on the ticket, stay here
		SaveState.rename_profile(_sign_up_ticket, manager)
		_close_sign_up()
		_build_tickets()
		return
	SaveState.create_profile(_sign_up_ticket, manager)
	if SaveState.start_after_sign_up:            ## came from Start new game: carry on to the team name
		SaveState.start_after_sign_up = false
		RunState.start_with_team_name = true     ## the main menu opens the name box straight away
	get_tree().change_scene_to_file(MAIN_MENU)

func _close_sign_up() -> void:
	if _sign_up == null:
		return
	_sign_up.queue_free()
	_sign_up = null


# ---------- Delete a manager ----------

## "Delete Alex's ticket? Their run and progress will be lost for good."
func _show_delete(p: int) -> void:
	if _delete_box != null:
		return
	_delete_box = ColorRect.new()
	_delete_box.color = Color(0, 0, 0, 0.75)
	add_child(_delete_box)
	_delete_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(DARK_GREEN, GOLD, 3, 40, [12, 12, 12, 12]))
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	vbox.add_child(_label("Delete %s's ticket?" % SaveState.summary(p)["name"], 44, GOLD, _marker))
	vbox.add_child(_label("Their run and progress will be lost for good.", 26, CREAM))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 24)
	var keep := Button.new()
	keep.text = "Keep"
	UiStyle.primary(keep)
	keep.pressed.connect(_close_delete)
	var delete := Button.new()
	delete.text = "Delete"
	UiStyle.secondary(delete)
	delete.add_theme_color_override("font_color", Color("ff8a80"))
	delete.add_theme_color_override("font_hover_color", Color("ff8a80"))
	delete.pressed.connect(_delete.bind(p))
	buttons.add_child(keep)
	buttons.add_child(delete)
	vbox.add_child(buttons)
	panel.add_child(vbox)
	_delete_box.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	keep.grab_focus.call_deferred()              ## Enter keeps: deleting takes a deliberate click

func _delete(p: int) -> void:
	SaveState.delete_profile(p)
	_close_delete()
	if not SaveState.any_profile():              ## nobody left: out of edit mode, nothing to edit
		_editing = false
		_edit_button.visible = false
		_subtitle.text = "Pick your season ticket"
	_build_tickets()

func _close_delete() -> void:
	if _delete_box == null:
		return
	_delete_box.queue_free()
	_delete_box = null


# ---------- Building blocks ----------

## The ticket itself: a button, so it can be clicked or picked with the keyboard.
func _ticket_button(fill: Color, edge: Color, edge_width: int) -> Button:
	var ticket := Button.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := _box(fill, edge, edge_width, 0, [18, 18, 18, 18])
		if state == "hover" and fill.a > 0:
			box.bg_color = fill.lightened(0.04)
		if state == "focus":
			box.draw_center = false               ## the keyboard outline sits over the ticket
			box.border_color = Color.WHITE
			box.set_border_width_all(3)
			box.expand_margin_left = 6
			box.expand_margin_right = 6
			box.expand_margin_top = 6
			box.expand_margin_bottom = 6
		box.shadow_color = Color(0, 0, 0, 0.5) if fill.a > 0 and state != "focus" else Color(0, 0, 0, 0)
		box.shadow_size = 18
		box.shadow_offset = Vector2(0, 14)
		ticket.add_theme_stylebox_override(state, box)
	return ticket

## "Best finish ........ League One", with a line under it.
func _stat_row(what: String, value: String) -> VBoxContainer:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 8)
	var row := HBoxContainer.new()
	row.add_child(_label(what, 24, SOFT_INK))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var value_label := _label(value, 24, INK)
	value_label.add_theme_constant_override("outline_size", 1)   ## a touch bolder
	value_label.add_theme_color_override("font_outline_color", INK)
	row.add_child(value_label)
	block.add_child(row)
	var line := ColorRect.new()
	line.color = PAPER_LINE
	line.custom_minimum_size.y = 2
	block.add_child(line)
	return block

## A dashed line across the ticket where the stub tears off.
func _tear_line() -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	var dashes := HBoxContainer.new()
	dashes.add_theme_constant_override("separation", 10)
	for i in 22:
		var dash := ColorRect.new()
		dash.color = PAPER_LINE
		dash.custom_minimum_size = Vector2(10, 4)
		dashes.add_child(dash)
	margin.add_child(dashes)
	return margin

## The two half-circle bites at the ends of the tear-off line.
func _notches(ticket: Control) -> void:
	for x in [-21.0, TICKET_SIZE.x - 21.0]:
		var bite := Panel.new()
		bite.add_theme_stylebox_override("panel", _box(Color("1e2b22"), Color("1e2b22"), 0, 0, [21, 21, 21, 21]))
		bite.size = Vector2(42, 42)
		bite.position = Vector2(x, TICKET_SIZE.y - 96 - 21)
		bite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ticket.add_child(bite)

func _box(fill: Color, edge: Color, edge_width: int, padding: int, corners: Array) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(edge_width)
	box.corner_radius_top_left = corners[0]
	box.corner_radius_top_right = corners[1]
	box.corner_radius_bottom_right = corners[2]
	box.corner_radius_bottom_left = corners[3]
	box.set_content_margin_all(padding)
	return box

func _label(text: String, font_size: int, colour: Color, font: Font = null) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	if font != null:
		label.add_theme_font_override("font", font)
	return label

## Clicks go through to the ticket underneath.
func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)
