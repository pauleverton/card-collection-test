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

## During a replay: move the yellow "your ball" highlight to zone z.
func show_ball_at(z: int) -> void:
	for i in 5:
		_zones[i].color = GRASS[i]
		_labels[i].text = MatchRules.ZONE_NAMES[i]
		_labels[i].add_theme_color_override("font_color", Color.WHITE)
	_zones[z].color = BALL_COLOUR
	_labels[z].add_theme_color_override("font_color", Color.BLACK)
	_labels[z].text += "\n\nYOUR BALL"
	
## During a replay: move the red "their ball" highlight to zone z (e.g. a counter-attack).
func show_their_ball_at(z: int, note: String = "") -> void:
	for i in 5:
		_zones[i].color = GRASS[i]
		_labels[i].text = MatchRules.ZONE_NAMES[i]
		_labels[i].add_theme_font_size_override("font_size", 26)
		_labels[i].add_theme_color_override("font_color", Color.WHITE)
	_zones[z].color = LOST_COLOUR
	_labels[z].text += "\n\nTHEIR BALL"
	if note != "":
		_labels[z].text += "\n" + note

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
			if m.rebound:
				_labels[z].text += "\nREBOUND!\nChance %d\nShoot now: %d%%\nShots only" % [
						m.quality, m.basic_shot_odds()]
			else:
				_labels[z].text += "\nChance %d\nShoot now: %d%%" % [m.quality, m.basic_shot_odds()]
				var card_odds := m.shot_card_odds()
				if card_odds >= 0:
					_labels[z].text += "\nShot card: %d%%" % card_odds
				_labels[z].text += "\nLose it: Pass %d%% Drib %d%% Cross %d%%" % [
						m.box_risk("pass"), m.box_risk("dribble"), m.box_risk("cross")]
		else:
			_labels[z].text += "\n\nYOUR BALL\nBuild %d / %d" % [m.build, m.target]
	else:
		_zones[z].color = LOST_COLOUR
		if z == 0:
			_labels[z].add_theme_font_size_override("font_size", 17)
			var how_to_stop := "Nobody back: keeper only!" if m.nobody_back() else "Block or Tackle to lower it"
			_labels[z].text += "\nTHEIR CHANCE %d\nThey score: %d%%\n%s" % [
					m.quality, m.their_goal_odds(), how_to_stop]
		elif m.nobody_back():
			_labels[z].text += "\n\nTHEIR BALL\nNobody back!"
		else:
			_labels[z].text += "\n\nTHEIR BALL\nHeld %d / %d" % [m.build, m.target]
