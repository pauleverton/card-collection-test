extends PanelContainer
## Balatro-style coin breakdown: a big total that counts up, then one row per
## source of coins (count, what it's for, amount), fading in one at a time.
## Call show_coins(parts, earned, total) once, after adding it to the screen.

const PANEL_COLOUR := Color("1b2a22")      ## dark pitch green
const BORDER_COLOUR := Color(0.45, 0.55, 0.48)
const GOLD := Color("f2c14e")
const COUNT_COLOUR := Color("6fa8dc")      ## blue numbers, like Balatro's
const GREY := Color(0.65, 0.65, 0.65)
const ROW_TIME := 0.35                     ## seconds per row fading in

var header: Label
var final_total := 0                       ## coins you have after this match, shown in the header
var _earned := 0.0                         ## this match's coins (the count-up's end point)

func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOUR
	style.border_color = BORDER_COLOUR
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(24)
	add_theme_stylebox_override("panel", style)
	custom_minimum_size.x = 700

## parts = pitch.coins_parts(), earned = this match's coins, total = coins you now have.
func show_coins(parts: Array, earned: int, total: int) -> void:
	final_total = total
	_earned = earned
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	header = _label("+0 coins", 40, GOLD)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	var dots := _label("· · · · · · · · · · · · · · · · · · · · · · ·", 20, GREY)
	dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(dots)

	var rows := []
	for part in parts:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var count := _label(part["count"], 32, COUNT_COLOUR)
		count.custom_minimum_size.x = 50
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var what := _label(part["label"], 26, Color.WHITE)
		what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var amount := _label("+%d" % part["amount"], 28, GOLD)
		row.add_child(count)
		row.add_child(what)
		row.add_child(amount)
		row.modulate.a = 0.0                   ## hidden until its turn
		vbox.add_child(row)
		rows.append(row)

	## Rows fade in one after another while the header counts up to the total.
	var step := SettingsState.t(ROW_TIME)
	var fade := create_tween()
	for row in rows:
		fade.tween_property(row, "modulate:a", 1.0, step)
	create_tween().tween_method(_show_header, 0.0, float(earned), step * rows.size())

## "+X coins  (Y total)": both numbers count up together as the rows appear.
func _show_header(value: float) -> void:
	var earned_so_far := roundi(value)
	var total_so_far := final_total - (roundi(_earned) - earned_so_far)
	header.text = "+%d coins  (%d total)" % [earned_so_far, total_so_far]

func _label(text: String, font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	return label
