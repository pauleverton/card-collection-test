extends Control

@onready var hand = $Hand
@onready var info_label = $InfoLabel
@onready var pitch_strip = $Pitch
@onready var result_label = $ResultLabel
@onready var let_through_button = $LetThroughButton
@onready var shoot_button = $ShootButton
@onready var full_time_panel = $FullTimePanel
@onready var full_time_label = $FullTimePanel/VBox/FullTimeLabel
@onready var continue_button = $FullTimePanel/VBox/ContinueButton

var pitch := PitchMatch.new()

func _ready() -> void:
	var short_pass = load("res://Resources/short_pass.tres")
	var dribble = load("res://Resources/dribble.tres")
	var through_ball = load("res://Resources/through_ball.tres")
	var overlap = load("res://Resources/overlap.tres")
	var cross = load("res://Resources/cross.tres")
	var shot = load("res://Resources/shot.tres")
	var tackle = load("res://Resources/tackle.tres")
	var track_back = load("res://Resources/track_back.tres")
	var block = load("res://Resources/block.tres")
	var retain = load("res://Resources/retain_possession.tres")
	var lump = load("res://Resources/lump_clear.tres")
	var deck = [short_pass, short_pass, short_pass, dribble, dribble, through_ball,
			overlap, overlap, cross, cross, shot,
			tackle, tackle,lump, track_back, track_back, block, retain]
	DeckState.start_match(deck)
	DeckState.draw(5)
	pitch.start()
	hand.card_played.connect(play_card)
	let_through_button.pressed.connect(_on_let_through)
	shoot_button.pressed.connect(_on_shoot)
	continue_button.pressed.connect(_on_continue)
	full_time_panel.visible = false
	result_label.text = "Kick-off. Beat the Press to move up the pitch."
	refresh_all()

# ---------- Player actions ----------

func play_card(card: ActionData) -> void:
	var events := pitch.play(card)
	## If the card couldn't be played at all, leave it in the hand.
	if events[0]["type"] in ["not_now", "no_energy", "wrong_side"]:
		result_label.text = describe(events)
		return
	_after_action(events)

func _on_shoot() -> void:
	_after_action(pitch.take_shot())

func _on_let_through() -> void:
	_after_action(pitch.let_them_through())

## Every action ends here, so the screen update and the full-time check happen in one place.
func _after_action(events: Array) -> void:
	for e in events:
		print(e)
	result_label.text = describe(events)
	refresh_all()
	if pitch.match_over:
		_show_full_time()

# ---------- Full time ----------

func _show_full_time() -> void:
	var coins := pitch.coins_earned()
	CoinState.add_coins(coins)
	var result := "LOSS"
	if pitch.goals > pitch.conceded:
		result = "WIN"
	elif pitch.goals == pitch.conceded:
		result = "DRAW"
	full_time_label.text = "FULL TIME\n\nYou %d - %d Them\n%s\n\n+%d coins   (total %d)" % [
			pitch.goals, pitch.conceded, result, coins, CoinState.coins]
	full_time_panel.visible = true

func _on_continue() -> void:
	## For now: play another match. Next step: this goes to the reward screen.
	get_tree().reload_current_scene()

# ---------- Screen ----------

func refresh_all() -> void:
	hand.refresh()
	pitch_strip.show_state(pitch)
	info_label.text = "%d'   |   You %d - %d Them   |   Energy %d   |   Next bonus +%d" % [
			pitch.minute, pitch.goals, pitch.conceded, pitch.energy, pitch.next_bonus]
	shoot_button.visible = pitch.in_their_box() and not pitch.match_over
	let_through_button.visible = not pitch.has_ball and not pitch.match_over
	let_through_button.text = "Let them shoot" if pitch.in_our_box() else "Let them through"
	for card_ui in hand.get_children():
		if pitch.would_succeed(card_ui.card):
			card_ui.modulate = Color(0.6, 1.0, 0.6)
		else:
			card_ui.modulate = Color(1, 1, 1, 0.6)

func describe(events: Array) -> String:
	var lines: PackedStringArray = []
	for e in events:
		match e["type"]:
			# --- You attacking ---
			"attempt":
				var outcome: String = "made it!" if e["success"] else "stopped."
				lines.append("%s %d vs Press %d: %s" % [e["card"], e["power"], e["target"], outcome])
			"advance":
				lines.append("Ball moves into %s." % e["zone"])
			"kept_ball":
				lines.append("Couldn't get past, but dragged a defender out. Press now %d." % e["target"])
			"in_the_box":
				lines.append("Into the box with a chance of %d." % e["quality"])
			"quality":
				lines.append("%s: chance now %d." % [e["card"], e["quality"]])
			"defender":
				if e["effect"] == 0:
					lines.append("Beat the %s! Chance stays %d." % [e["card"], e["quality"]])
				else:
					lines.append("%s takes %d off. Chance now %d." % [e["card"].capitalize(), e["effect"], e["quality"]])
			"headed_clear":
				lines.append("Headed clear!")
			"no_defenders":
				lines.append("No defenders left to stop you!")
			"basic_shot":
				lines.append("You hit it... strike quality +%d." % e["roll"])
			"shot":
				lines.append("SHOT! Chance %d vs keeper %d..." % [e["quality"], e["save"]])
			"goal":
				lines.append("GOAL! You've scored %d. They kick off." % e["goals"])
			"corner":
				lines.append("Tipped round the post. Corner! Chance reset to 2, +1 energy.")
			"saved":
				lines.append("Saved.")
			"turnover":
				lines.append("Lost the ball in %s. They're attacking." % e["zone"])
			# --- Them attacking ---
			"challenge":
				var result: String = "won it!" if e["success"] else "beaten."
				lines.append("%s %d vs Attack %d: %s" % [e["card"], e["power"], e["target"], result])
			"delayed":
				lines.append("Couldn't win it, but slowed them down. Attack now %d." % e["target"])
			"they_advance":
				lines.append("They move into %s." % e["zone"])
			"they_in_box":
				lines.append("They're in your box with a chance of %d!" % e["quality"])
			"blocked":
				lines.append("%s: their chance down to %d." % [e["card"], e["quality"]])
			"their_shot":
				lines.append("THEY SHOOT! Chance %d vs your keeper %d..." % [e["quality"], e["save"]])
			"conceded":
				lines.append("Goal for them. (%d conceded)" % e["conceded"])
			"our_save":
				lines.append("Your keeper saves it!")
			"won_ball":
				lines.append("Won the ball in %s!" % e["zone"])
			"kick_off":
				lines.append("Your kick-off.")
			# --- General ---
			"retain":
				lines.append("Kept the ball: +%d energy, drew %d." % [e["energy"], e["drew"]])
			"bonus":
				lines.append("Overlap: next card +%d." % e["next_bonus"])
			"drew":
				lines.append("Drew a card.")
			"wrong_phase":
				lines.append("%s does nothing here." % e["card"])
			"no_energy":
				lines.append("Not enough energy.")
			"not_now":
				lines.append("You can't do that right now.")
			"full_time":
				lines.append("FULL TIME!")
			"no_options":
				lines.append("No way forward. You're closed down and lose the ball.")
			"wrong_side":
				lines.append("%s can't be played right now." % e["card"])
			"lumped":
				lines.append("Lumped it clear! They restart from %s." % e["zone"])
	return "\n".join(lines)
