extends CanvasLayer
## Autoload singleton. Register as "PauseMenu" in Project Settings > Autoload, BELOW SaveState.
## The pause menu, on every screen during a run: press Esc or click the cog (top right).
## Resume · Match speed · Main menu · Quit game. The game pauses underneath, match included.
## Everything is already saved (each screen saves on arrival and after every signing or pick),
## so leaving loses nothing; in a match, Continue replays it from kick-off with the same luck.

## The screens with a cog and Esc (the main menu and the season tickets have their own buttons).
const RUN_SCREENS := ["hub_screen", "transfer_window_screen", "training_ground_screen",
		"team_sheet_screen", "reward_screen", "match_screen"]
const MAIN_MENU := "res://Scenes/main_menu.tscn"
const MARKER_FONT := "res://Images+themes/Themes/permanent_marker.ttf"
const GOLD := Color("f2c14e")
const DARK_GREEN := Color("1b2a22")
const COG_PLACE := Vector2(1852, 12)        ## top right, above every screen's own corner text
const COG_SIZE := 52

var _cog: Button
var _menu: ColorRect = null                 ## the dark layer holding the panel (null = closed)


func _ready() -> void:
	layer = 50                               ## drawn above every screen
	process_mode = Node.PROCESS_MODE_ALWAYS  ## keeps working while the game is paused
	_cog = Button.new()
	_cog.position = COG_PLACE
	_cog.custom_minimum_size = Vector2(COG_SIZE, COG_SIZE)
	_cog.tooltip_text = "Menu (Esc)"
	_cog.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed"]:
		var fill := DARK_GREEN.lightened(0.12) if state == "hover" else DARK_GREEN
		_cog.add_theme_stylebox_override(state, _box(fill, 10, 0))
	_cog.pressed.connect(open)
	var drawing := Cog.new()
	drawing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cog.add_child(drawing)
	drawing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_cog)

## The cog shows only on run screens, and not while the menu is open.
func _process(_delta: float) -> void:
	_cog.visible = _on_run_screen() and _menu == null

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):     ## Esc (a controller button later)
		return
	if _menu != null:
		close()
		get_viewport().set_input_as_handled()
	elif _on_run_screen():
		open()
		get_viewport().set_input_as_handled()

func _on_run_screen() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path.get_file().get_basename() in RUN_SCREENS

func _in_match() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path.get_file().get_basename() == "match_screen"


func open() -> void:
	if _menu != null:
		return
	get_tree().paused = true
	_menu = ColorRect.new()
	_menu.color = Color(0, 0, 0, 0.7)        ## also stops clicks reaching the screen
	add_child(_menu)
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(DARK_GREEN, 12, 40))
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", GOLD)
	if ResourceLoader.exists(MARKER_FONT):
		title.add_theme_font_override("font", load(MARKER_FONT))
	vbox.add_child(title)

	var resume := _button("Resume", true, close)
	vbox.add_child(resume)
	vbox.add_child(_speed_row())
	vbox.add_child(_button("Main menu", false, _to_main_menu))
	vbox.add_child(_button("Quit game", false, func(): get_tree().quit()))
	if _in_match():
		var note := Label.new()
		note.text = "Leaving restarts this match from kick-off\nwhen you continue."
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.add_theme_font_size_override("font_size", 18)
		note.add_theme_color_override("font_color", Color("c9c2ad"))
		vbox.add_child(note)

	panel.add_child(vbox)
	_menu.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH   ## stays centred
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	resume.grab_focus.call_deferred()        ## Enter resumes

func close() -> void:
	if _menu == null:
		return
	_menu.queue_free()
	_menu = null
	get_tree().paused = false

func _to_main_menu() -> void:
	close()
	get_tree().change_scene_to_file(MAIN_MENU)

## "Match speed [Instant v]", the same list as the main menu's.
func _speed_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var label := Label.new()
	label.text = "Match speed"
	label.add_theme_font_size_override("font_size", 24)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var speeds := OptionButton.new()
	speeds.add_theme_font_size_override("font_size", 24)
	var names: Array = SettingsState.SPEEDS.keys()
	for i in names.size():
		speeds.add_item(names[i])
		if names[i] == SettingsState.speed_name:
			speeds.select(i)
	speeds.item_selected.connect(func(i): SettingsState.set_speed(speeds.get_item_text(i)))
	row.add_child(speeds)
	return row

func _button(text: String, main: bool, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	if main:
		UiStyle.primary(button)
	else:
		UiStyle.secondary(button)
	button.custom_minimum_size.x = 380
	button.pressed.connect(action)
	return button

## The dark green panel with a gold edge, like the main menu's name box.
func _box(fill: Color, corner: int, padding: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = GOLD
	box.set_border_width_all(3)
	box.set_corner_radius_all(corner)
	box.set_content_margin_all(padding)
	return box


## The cog drawn on the button: eight teeth round a ring.
class Cog extends Control:
	const TEETH := 8
	func _draw() -> void:
		var centre := size / 2
		var outer := size.x * 0.38
		var inner := size.x * 0.28
		var points := PackedVector2Array()
		for i in TEETH * 4:                  ## each tooth: up, across the flat top, down, across the gap
			var tooth := floori(i / 4.0)
			var angle: float = TAU * (tooth + [0.0, 0.1, 0.42, 0.52][i % 4]) / TEETH
			var radius: float = outer if i % 4 in [1, 2] else inner
			points.append(centre + Vector2.from_angle(angle) * radius)
		draw_colored_polygon(points, GOLD)
		draw_circle(centre, size.x * 0.13, DARK_GREEN)   ## the hole in the middle
