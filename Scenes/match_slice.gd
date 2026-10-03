extends Control

@onready var hand = $Hand
@onready var info_label = $InfoLabel
@onready var pitch_strip = $Pitch
@onready var result_label = $ResultLabel
@onready var kick_off_button = $KickOffButton
@onready var shoot_button = $ShootButton

var pitch := PitchMatch.new()

func _ready() -> void:
	var short_pass = load("res://Resources/short_pass.tres")
	var dribble = load("res://Resources/dribble.tres")
	var through_ball = load("res://Resources/through_ball.tres")
	var overlap = load("res://Resources/overlap.tres")
	var tackle = load("res://Resources/tackle.tres")
	var cross = load("res://Resources/cross.tres")
	var shot = load("res://Resources/shot.tres")
	var deck = [short_pass, short_pass, short_pass, short_pass, dribble, dribble,
			through_ball, through_ball, overlap, overlap, tackle, tackle,
			cross, cross, shot]
	DeckState.start_match(deck)
	DeckState.draw(5)
	pitch.start()
	hand.card_played.connect(play_card)
	kick_off_button.pressed.connect(_on_kick_off)
	shoot_button.pressed.connect(_on_shoot)
	result_label.text = "Kick-off. Beat the Press to move up the pitch."
	refresh_all()

func play_card(card: ActionData) -> void:
	var events := pitch.play(card)
	for e in events:
		print(e)
	result_label.text = describe(events)
	## If the card couldn't be played at all, leave it in the hand.
	if events[0]["type"] in ["no_ball", "no_energy"]:
		return
	DeckState.play(card)
	refresh_all()

func _on_shoot() -> void:
	var events := pitch.take_shot()
	result_label.text = describe(events)
	refresh_all()

func _on_kick_off() -> void:
	pitch.start()
	DeckState.draw(2)
	result_label.text = "New possession from midfield."
	refresh_all()

func refresh_all() -> void:
	hand.refresh()
	pitch_strip.show_state(pitch)
	info_label.text = "Goals %d   |   Energy %d   |   Next bonus +%d" % [
			pitch.goals, pitch.energy, pitch.next_bonus]
	kick_off_button.visible = not pitch.has_ball
	shoot_button.visible = pitch.has_ball and pitch.zone == 4
	for card_ui in hand.get_children():
		if pitch.would_succeed(card_ui.card):
			card_ui.modulate = Color(0.6, 1.0, 0.6)
		else:
			card_ui.modulate = Color(1, 1, 1, 0.6)

func describe(events: Array) -> String:
	var lines: PackedStringArray = []
	for e in events:
		match e["type"]:
			"attempt":
				var outcome: String = "made it!" if e["success"] else "stopped."
				lines.append("%s %d vs Press %d: %s" % [e["card"], e["power"], e["target"], outcome])
			"advance":
				lines.append("Ball moves into %s." % e["zone"])
			"in_the_box":
				lines.append("Into the box with a chance of %d." % e["quality"])
			"kept_ball":
				lines.append("Couldn't get past, but dragged a defender out. Press now %d." % e["target"])
			"quality":
				lines.append("%s: chance now %d." % [e["card"], e["quality"]])
			"defender":
				lines.append("Defender plays %s. Chance now %d." % [e["card"], e["quality"]])
			"no_defenders":
				lines.append("No defenders left to stop you!")
			"shot":
				lines.append("SHOT! Chance %d vs keeper %d..." % [e["quality"], e["save"]])
			"goal":
				lines.append("GOAL! That's %d." % e["goals"])
			"corner":
				lines.append("Tipped round the post. Corner! Chance reset to 2, +1 energy.")
			"saved":
				lines.append("Saved.")
			"turnover":
				lines.append("Lost the ball in %s." % e["zone"])
			"bonus":
				lines.append("Overlap: next card +%d." % e["next_bonus"])
			"drew":
				lines.append("Drew a card.")
			"wrong_phase":
				lines.append("%s does nothing here." % e["card"])
			"no_energy":
				lines.append("Not enough energy.")
			"no_ball":
				lines.append("You can't do that right now.")
			"basic_shot":
				lines.append("Snatched shot from a tight angle (-%d)." % PitchMatch.BASIC_SHOT_PENALTY)
	return "\n".join(lines)
