extends Node2D

@onready var speed_option: OptionButton = $TextureRect/SpeedOption
@onready var continue_button: Button = $TextureRect/ContinueGame

## Word lists for the team name: [prefix, middle, suffix]. Add words freely.
const NAME_PARTS := [
	["Real", "Sporting", "Inter", "Dynamo", "AFC", "Athletico", "Olympic",
			"Royal", "Racing", "Lokomotiv", "Union", "Borussia"],
	["Muddy", "Puddle", "Pub", "Car Park", "Tuesday", "Hangover", "Kettle",
			"Drizzle", "Sausage Roll", "Allotment", "Half-Time", "Bobble Hat",
			"Pie Shop", "Traffic Cone"],
	["Rovers", "Athletic", "Wanderers", "United", "Town", "City", "FC",
			"Albion", "Rangers", "Academicals", "Harriers", "Villa", "Orient"],
]

## The reroll spin: how many words flash past, and how fast (starts quick, slows down).
const SPIN_STEPS := 12
const SPIN_FAST := 0.04            ## seconds per word at the start
const SPIN_SLOW := 0.16            ## seconds per word just before it stops
const STAGGER_STEPS := 5           ## Reroll all: each slot spins this many words longer than the one before
const GOLD := Color("f2c14e")
const WORD_SIZE := 28              ## font size of the three words
const PREVIEW_SIZE := 36           ## font size of the full name

var backdrop: ColorRect = null            ## the dark layer behind the name box
var name_box: PanelContainer = null
var part_labels: Array[Label] = []        ## the word currently in each slot
var name_preview: Label
var buttons: Array[Button] = []           ## switched off while anything is spinning
var spinning := 0                         ## how many slots are spinning right now
var confirm_box: ColorRect = null         ## "This will end your saved run": dark layer + panel
const PROFILE_SCREEN := "res://Scenes/profile_screen.tscn"
const MARKER_FONT := "res://Images+themes/Themes/permanent_marker.ttf"

func _ready() -> void:
	## Fill the speed list from SettingsState, and select whatever was saved last time.
	var names: Array = SettingsState.SPEEDS.keys()
	for i in names.size():
		speed_option.add_item(names[i])
		if names[i] == SettingsState.speed_name:
			speed_option.select(i)
	speed_option.item_selected.connect(
			func(i): SettingsState.set_speed(speed_option.get_item_text(i)))
	continue_button.disabled = not SaveState.has_run()   ## greyed out until there's a run to continue
	_manager_badge()
	if OS.has_feature("editor"):                  ## only when run from Godot (F5), never in an exported game
		_wipe_button()
	continue_button.pressed.connect(_continue_run)
	if RunState.start_with_team_name:            ## coming from "Start a new run"
		RunState.start_with_team_name = false
		_show_name_box()

## Start new game: build your team name first (asking first if that would end a saved run).
func _on_start_game_pressed() -> void:
	if name_box != null or confirm_box != null:
		return
	if not SaveState.any_profile():              ## nobody signed up yet: a season ticket first
		SaveState.start_after_sign_up = true     ## ...then straight on to the team name
		get_tree().change_scene_to_file(PROFILE_SCREEN)
		return
	if SaveState.has_run():
		_show_confirm()
	else:
		_show_name_box()

## Continue: load the saved run and open the screen it was saved on.
func _continue_run() -> void:
	var screen: String = SaveState.load_run()
	if screen == "":
		continue_button.disabled = true          ## the save couldn't be read (the Output panel says why)
		return
	get_tree().change_scene_to_file(screen)

## "This will end your saved run. Start anyway?" over a dark layer. The saved run is only
## replaced when you press Kick off, so closing the name box afterwards still keeps it.
func _show_confirm() -> void:
	confirm_box = ColorRect.new()
	confirm_box.color = Color(0, 0, 0, 0.75)     ## also stops clicks reaching the menu
	$TextureRect.add_child(confirm_box)
	confirm_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := _dark_panel()
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	var question := Label.new()
	question.text = "This will end your saved run.\nStart anyway?"
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question.add_theme_font_size_override("font_size", WORD_SIZE)
	vbox.add_child(question)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	var keep := Button.new()
	keep.text = "Keep my run"
	UiStyle.secondary(keep)
	keep.pressed.connect(_close_confirm)
	var start := Button.new()
	start.text = "Start new run"
	UiStyle.primary(start)
	start.pressed.connect(_confirm_new_run)
	row.add_child(keep)
	row.add_child(start)
	vbox.add_child(row)

	panel.add_child(vbox)
	confirm_box.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH   ## stays centred
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH

func _close_confirm() -> void:
	confirm_box.queue_free()
	confirm_box = null

func _confirm_new_run() -> void:
	_close_confirm()
	_show_name_box()

## Top left: who's playing, with "Change" back to the season tickets.
func _manager_badge() -> void:
	if not SaveState.any_profile():               ## nobody signed up yet: no manager to show
		return
	var badge := Button.new()
	badge.add_theme_stylebox_override("normal", _badge_box(Color("1b2a22")))
	badge.add_theme_stylebox_override("hover", _badge_box(Color("1b2a22").lightened(0.12)))
	badge.add_theme_stylebox_override("pressed", _badge_box(Color("1b2a22").darkened(0.2)))
	badge.add_theme_stylebox_override("focus", _badge_box(Color(0, 0, 0, 0)))
	badge.position = Vector2(105, 80)
	badge.pressed.connect(func(): get_tree().change_scene_to_file(PROFILE_SCREEN))
	$TextureRect.add_child(badge)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(row)
	var manager := CareerState.manager_name if CareerState.manager_name != "" else "Manager %d" % SaveState.profile
	var initial := Label.new()                   ## the gold circle with the first letter
	initial.text = manager.left(1).to_upper()
	initial.custom_minimum_size = Vector2(68, 68)
	initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var circle := StyleBoxFlat.new()
	circle.bg_color = GOLD
	circle.set_corner_radius_all(34)
	initial.add_theme_stylebox_override("normal", circle)
	initial.add_theme_color_override("font_color", Color("1b2a22"))
	initial.add_theme_font_size_override("font_size", 38)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -4)
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	var small := Label.new()
	small.text = "MANAGER"
	small.add_theme_font_size_override("font_size", 16)
	small.add_theme_color_override("font_color", Color("c9c2ad"))
	var big := Label.new()
	big.text = manager
	big.add_theme_font_size_override("font_size", 36)
	names.add_child(small)
	names.add_child(big)
	var change := Label.new()
	change.text = "Change"
	change.add_theme_font_size_override("font_size", 21)
	change.add_theme_color_override("font_color", GOLD)
	change.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if ResourceLoader.exists(MARKER_FONT):
		var marker: Font = load(MARKER_FONT)
		initial.add_theme_font_override("font", marker)
		big.add_theme_font_override("font", marker)
	for part in [initial, names, small, big, change]:
		part.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(initial)
	row.add_child(names)
	row.add_child(change)
	badge.custom_minimum_size = row.get_combined_minimum_size() + Vector2(44, 24)   ## + the padding below
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 18                         ## a Button doesn't pad its children, so pad by hand
	row.offset_right = -26
	row.offset_top = 12
	row.offset_bottom = -12

## Testing only (see _ready): wipes every save. Click once to arm it, again to wipe.
func _wipe_button() -> void:
	var wipe := Button.new()
	wipe.text = "Delete all saves (editor only)"
	UiStyle.secondary(wipe)
	wipe.add_theme_color_override("font_color", Color("ff8a80"))
	wipe.add_theme_color_override("font_hover_color", Color("ff8a80"))
	wipe.position = Vector2(105, 960)
	$TextureRect.add_child(wipe)
	wipe.pressed.connect(func():
		if wipe.text != "Click again to delete everything":
			wipe.text = "Click again to delete everything"
			return
		SaveState.delete_everything()
		get_tree().reload_current_scene())       ## back to how a brand-new game looks

## The badge's dark panel with a gold edge, in one state's colour.
func _badge_box(fill: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = GOLD
	box.set_border_width_all(3)
	box.set_corner_radius_all(14)
	return box

## The dark green panel with a gold edge (the name box and the confirm box).
func _dark_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1b2a22")             ## dark pitch green
	style.border_color = GOLD
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(32)
	panel.add_theme_stylebox_override("panel", style)
	return panel

## A dark layer over the menu, and in the middle: [title + X], three [word ... Reroll]
## rows, Reroll all, the full name, Kick off. Fixed width: sized for the longest
## possible name, so rerolling never changes the box. Every row spans the full width,
## so the words line up on the left and every button lines up on the right.
func _show_name_box() -> void:
	backdrop = ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.75)        ## also stops clicks reaching the menu
	$TextureRect.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	name_box = _dark_panel()

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)

	buttons.clear()
	## Top row: [spacer] title [X]. The spacer is the same width as the X,
	## so the title sits in the true middle of the box.
	var top_row := HBoxContainer.new()
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(44, 44)
	var title := Label.new()
	title.text = "Name your team"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 28)
	var close := Button.new()
	close.text = "X"
	UiStyle.secondary(close)
	close.custom_minimum_size = Vector2(44, 44)
	close.pressed.connect(_close_name_box)
	top_row.add_child(spacer)
	top_row.add_child(title)
	top_row.add_child(close)
	vbox.add_child(top_row)
	buttons.append(close)
	## Three rows: the word on the left, its Reroll button on the right edge.
	part_labels.clear()
	for i in NAME_PARTS.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var word := Label.new()
		word.text = NAME_PARTS[i].pick_random()
		word.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT    ## words start on one straight line
		word.size_flags_horizontal = Control.SIZE_EXPAND_FILL    ## takes the spare width, pushing Reroll right
		word.add_theme_font_size_override("font_size", WORD_SIZE)
		var reroll := Button.new()
		reroll.text = "Reroll"
		UiStyle.secondary(reroll)
		reroll.pressed.connect(_reroll.bind(i))
		row.add_child(word)
		row.add_child(reroll)
		vbox.add_child(row)
		part_labels.append(word)
		buttons.append(reroll)

	var reroll_all := Button.new()
	reroll_all.text = "Reroll all"
	UiStyle.secondary(reroll_all)
	reroll_all.pressed.connect(_reroll_all)
	vbox.add_child(reroll_all)
	buttons.append(reroll_all)

	name_preview = Label.new()
	name_preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_preview.add_theme_font_size_override("font_size", PREVIEW_SIZE)
	name_preview.add_theme_color_override("font_color", GOLD)
	vbox.add_child(name_preview)

	var kick_off := Button.new()
	kick_off.text = "Kick off"
	UiStyle.primary(kick_off)
	kick_off.pressed.connect(_start_run)
	vbox.add_child(kick_off)
	buttons.append(kick_off)

	name_box.add_child(vbox)
	$TextureRect.add_child(name_box)
	_fix_widths(vbox)                            ## needs to be on screen to measure the font
	name_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	name_box.grow_horizontal = Control.GROW_DIRECTION_BOTH   ## stays centred
	name_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_update_preview()

## The box gets the width of the longest name the word lists can make
## (the widest word from each list), so rerolling never changes it.
func _fix_widths(vbox: VBoxContainer) -> void:
	var font: Font = name_preview.get_theme_font("font")
	var longest_words := PackedStringArray()
	for list in NAME_PARTS:
		var widest := 0.0
		var widest_word := ""
		for w in list:
			var width := font.get_string_size(w, HORIZONTAL_ALIGNMENT_LEFT, -1, PREVIEW_SIZE).x
			if width > widest:
				widest = width
				widest_word = w
		longest_words.append(widest_word)
	var longest_name := font.get_string_size(" ".join(longest_words),
			HORIZONTAL_ALIGNMENT_LEFT, -1, PREVIEW_SIZE).x
	vbox.custom_minimum_size.x = longest_name + 20

## X: close the name box and the dark layer, back to the plain menu.
func _close_name_box() -> void:
	backdrop.queue_free()
	name_box.queue_free()
	backdrop = null
	name_box = null                 ## so Start new game opens a fresh box next time

## Spin one slot: words flash past, slowing down, then it lands on a new word
## (never the one it started on) and flashes gold.
func _reroll(part: int, extra_steps: int = 0) -> void:
	var label := part_labels[part]
	var start_word := label.text
	_start_spin()
	var steps := SPIN_STEPS + extra_steps
	for s in steps:
		label.text = NAME_PARTS[part].pick_random()
		_update_preview()
		var wait: float = lerp(SPIN_FAST, SPIN_SLOW, float(s) / steps)
		await get_tree().create_timer(wait).timeout
	var options: Array = NAME_PARTS[part].filter(func(w): return w != start_word)
	label.text = options.pick_random()
	_update_preview()
	label.modulate = GOLD                        ## flash gold, fade back to white
	create_tween().tween_property(label, "modulate", Color.WHITE, 0.5)
	_end_spin()

## Spin all three; each stops a little after the one before it.
func _reroll_all() -> void:
	for part in part_labels.size():
		_reroll(part, part * STAGGER_STEPS)      ## not awaited: they spin together

func _start_spin() -> void:
	spinning += 1
	for b in buttons:
		b.disabled = true

func _end_spin() -> void:
	spinning -= 1
	if spinning == 0:
		for b in buttons:
			b.disabled = false

## The three words joined with spaces.
func _team_name() -> String:
	var words: PackedStringArray = []
	for label in part_labels:
		words.append(label.text)
	return " ".join(words)

func _update_preview() -> void:
	name_preview.text = _team_name()

## A fresh run with this team name, then to the hub.
func _start_run() -> void:
	SaveState.delete_run()                      ## the old run (if any) ends here; the new one saves itself
	RunState.new_run()                          ## new deck and squad (also clears the name)
	CoinState.new_run()
	RunState.team_name = _team_name()
	CareerState.start_new_run()                 ## back to the first league; new season with your name
	get_tree().change_scene_to_file(RunState.next_break_screen())   ## a new run: the transfer window
