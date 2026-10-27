extends Button

signal player_clicked(player: StaffCard)

var player: StaffCard

func _ready() -> void:
	custom_minimum_size = Vector2(210, 90)
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pressed.connect(func(): player_clicked.emit(player))

func setup(data: StaffCard) -> void:
	player = data
	text = "%s\n%s" % [data.display_name, data.description]
	modulate = Color(0.8, 1.0, 1.3) if data is CoachCard else Color(1.3, 1.15, 0.8)

## Pop + wiggle, then float the bonus number. `delay` lets several players go in turn.
## Every length goes through SettingsState.t(), so the game-speed setting controls it.
func react(label_text: String, delay: float) -> void:
	var s := SettingsState
	pivot_offset = size / 2                     ## grow/rotate from the centre, not the top-left
	var t := create_tween()
	t.tween_interval(delay)                     ## wait for our turn (already scaled by the caller)
	t.tween_callback(_float_number.bind(label_text))
	t.tween_property(self, "scale", Vector2(1.2, 1.2), s.t(0.1)) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "rotation_degrees", 6.0, s.t(0.06))
	t.tween_property(self, "rotation_degrees", -6.0, s.t(0.08))
	t.tween_property(self, "rotation_degrees", 0.0, s.t(0.06))
	t.parallel().tween_property(self, "scale", Vector2.ONE, s.t(0.15))

func _float_number(label_text: String) -> void:
	var s := SettingsState
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	label.position = Vector2(size.x / 2 - 20, -20)
	add_child(label)
	var t := create_tween()
	t.tween_property(label, "position:y", label.position.y - 60, s.t(0.6))
	t.parallel().tween_property(label, "modulate:a", 0.0, s.t(0.6)).set_delay(s.t(0.2))
	t.tween_callback(label.queue_free)          ## tidy up when it's gone
