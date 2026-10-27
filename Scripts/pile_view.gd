class_name PileView
extends PanelContainer
## A small face-down pile with a count on it (the draw pile or the discard pile). Display only.

const PILE_SIZE := Vector2(110, 150)

var count_label := Label.new()
var title_label := Label.new()

func setup(title: String, colour: Color) -> void:
	custom_minimum_size = PILE_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.set_corner_radius_all(10)
	style.set_border_width_all(3)
	style.border_color = Color(1, 1, 1, 0.6)
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(box)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size", 40)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.text = title
	box.add_child(count_label)
	box.add_child(title_label)

func set_count(n: int) -> void:
	count_label.text = str(n)

## The middle of the pile on screen: where cards fly from and to.
func centre() -> Vector2:
	return global_position + size / 2.0

## A quick bump, used when the discard pile is shuffled back into the draw pile.
func pulse() -> void:
	pivot_offset = size / 2.0
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE * 1.2, SettingsState.t(0.12))
	tw.tween_property(self, "scale", Vector2.ONE, SettingsState.t(0.12))
