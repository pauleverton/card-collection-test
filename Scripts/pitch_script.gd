extends HBoxContainer

const GRASS := [Color("3a6b35"), Color("4a7d3f"), Color("3a6b35"), Color("4a7d3f"), Color("3a6b35")]
const BALL_COLOUR := Color("f2c14e")
const LOST_COLOUR := Color("b33a3a")

var _zones: Array = []
var _labels: Array = []

func _ready() -> void:
	for i in 5:
		var rect := ColorRect.new()
		rect.custom_minimum_size = Vector2(0, 220)
		rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(rect)
		var label := Label.new()
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 26)
		rect.add_child(label)
		_zones.append(rect)
		_labels.append(label)

func show_state(zone: int, target: int, has_ball: bool) -> void:
	for i in 5:
		_zones[i].color = GRASS[i]
		_labels[i].text = PitchMatch.ZONE_NAMES[i]
		_labels[i].add_theme_color_override("font_color", Color.WHITE)
	if not has_ball:
		_zones[zone].color = LOST_COLOUR
		_labels[zone].text += "\n\nLOST IT"
		return
	_zones[zone].color = BALL_COLOUR
	_labels[zone].add_theme_color_override("font_color", Color.BLACK)
	if zone == 4:
		_labels[zone].text += "\n\nBALL\nIn the box!"
	else:
		_labels[zone].text += "\n\nBALL\nPress %d" % target
