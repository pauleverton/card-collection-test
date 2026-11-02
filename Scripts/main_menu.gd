extends Node2D

@onready var speed_option: OptionButton = $TextureRect/SpeedOption

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

var name_box: PanelContainer = null
var part_labels: Array[Label] = []        ## the word currently in each slot
var name_preview: Label
var buttons: Array[Button] = []           ## switched off while anything is spinning
var spinning := 0                         ## how many slots are spinning right now

func _ready() -> void:
	## Fill the speed list from SettingsState, and select whatever was saved last time.
	var names: Array = SettingsState.SPEEDS.keys()
	for i in names.size():
		speed_option.add_item(names[i])
		if names[i] == SettingsState.speed_name:
			speed_option.select(i)
	speed_option.item_selected.connect(
			func(i): SettingsState.set_speed(speed_option.get_item_text(i)))

## Start new game: build your team name first.
func _on_start_game_pressed() -> void:
	if name_box == null:
		_show_name_box()

## A dark layer over the menu, and in the middle: title, three [word + Reroll] rows,
## the full name, Reroll all, Kick off.
func _show_name_box() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.75)        ## also stops clicks reaching the menu
	$TextureRect.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	name_box = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1b2a22")             ## dark pitch green
	style.border_color = GOLD
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(32)
	name_box.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)

	var title := Label.new()
	title.text = "Name your team"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	part_labels.clear()
	buttons.clear()
	for i in NAME_PARTS.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var word := Label.new()
		word.text = NAME_PARTS[i].pick_random()
		word.custom_minimum_size = Vector2(300, 0)
		word.add_theme_font_size_override("font_size", 28)
		var reroll := Button.new()
		reroll.text = "Reroll"
		reroll.pressed.connect(_reroll.bind(i))
		row.add_child(word)
		row.add_child(reroll)
		vbox.add_child(row)
		part_labels.append(word)
		buttons.append(reroll)

	var reroll_all := Button.new()
	reroll_all.text = "Reroll all"
	reroll_all.pressed.connect(_reroll_all)
	vbox.add_child(reroll_all)
	buttons.append(reroll_all)

	name_preview = Label.new()
	name_preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_preview.add_theme_font_size_override("font_size", 36)
	name_preview.add_theme_color_override("font_color", GOLD)
	vbox.add_child(name_preview)
	

	var kick_off := Button.new()
	kick_off.text = "Kick off"
	kick_off.pressed.connect(_start_run)
	vbox.add_child(kick_off)
	buttons.append(kick_off)

	name_box.add_child(vbox)
	$TextureRect.add_child(name_box)
	name_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_update_preview()

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

## A fresh run with this team name, then into the first match.
func _start_run() -> void:
	RunState.new_run()                          ## new deck and squad (also clears the name)
	CoinState.new_run()
	RunState.team_name = _team_name()
	CareerState.start_new_run()                 ## back to the first league; new season with your name
	get_tree().change_scene_to_file("res://Scenes/match_screen.tscn")
