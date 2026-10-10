extends HBoxContainer

const GRASS := [Color("3a6b35"), Color("4a7d3f"), Color("3a6b35"), Color("4a7d3f"), Color("3a6b35")]
const BALL_COLOUR := Color("f2c14e")
const LOST_COLOUR := Color("b33a3a")
const GOAL_COLOUR := Color.WHITE

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
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func show_state(m: MatchRules) -> void:
	for i in 5:
		_labels[i].add_theme_font_size_override("font_size", 26)
		_zones[i].color = GRASS[i]
		_labels[i].text = MatchRules.ZONE_NAMES[i]
		_labels[i].add_theme_color_override("font_color", Color.WHITE)
	var z := m.zone
	if m.has_ball:
		_zones[z].color = BALL_COLOUR
		_labels[z].add_theme_color_override("font_color", Color.BLACK)
		if z == 4:
			_labels[z].add_theme_font_size_override("font_size", 17)
			var upcoming := m.upcoming_defenders()
			var next_up := "nobody! Free shot"
			if not upcoming.is_empty():
				next_up = MatchRules.DEFENDER_TEXT[upcoming[0]]
				if upcoming.size() > 1:
					next_up += " (+%d more)" % (upcoming.size() - 1)
			_labels[z].text += "\nChance %d\nNext: %s\nShoot now: %d%%\nWith Shot card: %d%%" % [
					m.quality, next_up,
					m.basic_shot_odds(),
					m.goal_odds(m.quality + 3 + m.next_bonus)]
		else:
			_labels[z].text += "\n\nYOUR BALL\nPress %d" % m.target
	else:
		_zones[z].color = LOST_COLOUR
		if z == 0:
			_labels[z].add_theme_font_size_override("font_size", 17)
			_labels[z].text += "\nTHEIR CHANCE %d\nThey score: %d%%\nBlock or Tackle to lower it" % [
					m.quality, m.their_goal_odds()]
		else:
			_labels[z].text += "\n\nTHEIR BALL\nAttack %d" % m.target
