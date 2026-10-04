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
@onready var full_time_background = $FullTimePanel/Background

var pitch := PitchMatch.new()
## Filled in at full time by LeagueState, and read by Continue to decide where to go next.
var league_result := {}
var was_final_tournament := false

func _ready() -> void:
	DeckState.start_match(RunState.deck)
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

	## Read these BEFORE recording the result: promotion moves you to the next tournament.
	var tournament := LeagueState.current_tournament_name()
	var target := LeagueState.promotion_target()
	was_final_tournament = LeagueState.is_final_tournament()
	league_result = LeagueState.record_match_result(pitch.goals, pitch.conceded)

	## Can't reach the target any more, even by winning every remaining match: end it now.
	if not league_result["season_ended"] and LeagueState.is_target_out_of_reach():
		league_result = {"season_ended": true, "promoted": false, "final_points": LeagueState.season_points}
		CareerState.end_run()

	var result := "LOSS"
	if pitch.goals > pitch.conceded:
		result = "WIN"
	elif pitch.goals == pitch.conceded:
		result = "DRAW"

	full_time_background.color = Color(0.1, 0.1, 0.1, 0.9)   # normal: dark
	var league_line := ""
	if not league_result["season_ended"]:
		league_line = "%s: %d pts, %d matches left (need %d)" % [
				tournament, LeagueState.season_points, LeagueState.matches_remaining(), target]
	elif league_result["promoted"] and was_final_tournament:
		league_line = "%s won with %d pts. YOU'VE WON EVERYTHING!" % [tournament, league_result["final_points"]]
		full_time_background.color = Color("b8902e")   # won it all: gold
		continue_button.text = "Start a new run"
	elif league_result["promoted"]:
		league_line = "Season over: %d pts. PROMOTED from %s!" % [league_result["final_points"], tournament]
	else:
		league_line = "Season over: %d pts, needed %d. RUN OVER." % [league_result["final_points"], target]
		full_time_background.color = Color("8b1e1e")   # run over: red
		continue_button.text = "Start a new run"

	full_time_label.text = "FULL TIME\n\nYou %d - %d Them   (%s)\n\n%s\n\n+%d coins   (total %d)" % [
			pitch.goals, pitch.conceded, result, league_line, coins, CoinState.coins]
	full_time_panel.visible = true

func _on_continue() -> void:
	RunState.matches_played += 1
	var season_ended: bool = league_result["season_ended"]
	var run_over: bool = season_ended and (not league_result["promoted"] or was_final_tournament)
	if run_over:
		RunState.new_run()
		CareerState.start_new_run()
		get_tree().reload_current_scene()
	elif pitch.goals > pitch.conceded:
		get_tree().change_scene_to_file("res://Scenes/reward_screen.tscn")
	else:
		get_tree().reload_current_scene()

# ---------- Screen ----------

func refresh_all() -> void:
	hand.refresh()
	pitch_strip.show_state(pitch)
	info_label.text = "%s  Match %d/%d  %d pts (need %d)   |   %d'   |   You %d - %d Them   |   Energy %d" % [
			LeagueState.current_tournament_name(), LeagueState.matches_played + 1,
			LeagueState.matches_per_season(), LeagueState.season_points, LeagueState.promotion_target(),			pitch.minute, pitch.goals, pitch.conceded, pitch.energy]
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

# ---------- Debug ----------

## Debug keys, only in the editor:
## G = you score, C = they score, F = skip to full time, T = jump to the final tournament.
func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or pitch.match_over:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_G:
				_after_action(pitch.debug_goal())
			KEY_C:
				_after_action(pitch.debug_concede())
			KEY_F:
				_after_action(pitch.debug_full_time())
			KEY_T:
				LeagueState.current_tournament_index = LeagueState.TOURNAMENTS.size() - 1
				LeagueState.reset_for_new_tournament()
				result_label.text = "DEBUG: jumped to %s." % LeagueState.current_tournament_name()
				refresh_all()
