extends Control

@onready var hand = $Hand
@onready var info_label = $InfoLabel
@onready var pitch_strip = $Pitch
@onready var let_through_button = $LetThroughButton
@onready var shoot_button = $ShootButton
@onready var full_time_panel = $FullTimePanel
@onready var full_time_label = $FullTimePanel/VBox/FullTimeLabel
@onready var continue_button = $FullTimePanel/VBox/ContinueButton
@onready var full_time_background = $FullTimePanel/Background
@onready var commentary_headline = $CommentaryBox/VBox/Headline
@onready var commentary_log = $CommentaryBox/VBox/Log
const PLAYER_UI = preload("res://Scenes/player_card_view.tscn")
@onready var squad_bar = $SquadBar
@onready var build_bar = $BuildBar
@onready var build_label = $BuildBar/BuildLabel

var pitch := MatchRules.new()
var busy := false
const PILE_MARGIN := 40       ## gap between the piles and the screen corners
var draw_view := PileView.new()
var discard_view := PileView.new()

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
	_say("Kick-off. Beat the Press to move up the pitch.")
	for p in RunState.squad:
		var ui = PLAYER_UI.instantiate()
		ui.setup(p)
		ui.disabled = true          ## display only during a match
		squad_bar.add_child(ui)
	_add_piles()
	refresh_all()

# ---------- Player actions ----------

func play_card(card: ActionCard) -> void:
	if busy: return
	var events := pitch.play(card)
	## If the card couldn't be played at all, leave it in the hand.
	if events[0]["type"] in ["not_now", "no_energy","not_here", "wrong_side"]:
		_say(describe(events), false)
		return
	busy = true
	hand.refresh()                ## the played card leaves the hand straight away
	hand.modulate = Color(1, 1, 1, 0.4)    ## dim the hand while this play resolves
	var delay := 0.0
	## Players react once per trigger; a coach shouts "Again!" between rounds.
	var triggers := 1 + RunState.retriggers_for_card(card)
	var again_uis := []
	for ui in squad_bar.get_children():
		if ui.player is CoachCard and ui.player.applies_to(card):
			for i in ui.player.retriggers:
				again_uis.append(ui)
	for t in triggers:
		for ui in squad_bar.get_children():
			if ui.player is PlayerCard and ui.player.affects(card):
				ui.react(ui.player.effect_label(), delay)
				delay += SettingsState.t(0.25)
		if t < triggers - 1:
			again_uis[t].react("Again!", delay)
			delay += SettingsState.t(0.35)
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout   ## let the squad reactions finish first
	_after_action(events)


func _on_shoot() -> void:
	if busy: return
	_after_action(pitch.take_shot())

func _on_let_through() -> void:
	if busy: return
	_after_action(pitch.let_them_through())

## Every action ends here, so the screen update and the full-time check happen in one place.
func _after_action(events: Array) -> void:
	for e in events:
		print(e)
	busy = true
	if events.any(func(e): return e["type"] == "advance"):
		await _replay_build(events)
	_say(describe(events))
	refresh_all()
	hand.modulate = Color(1, 1, 1, 1)      ## back to normal once it's finished
	busy = false
	if pitch.match_over:
		_show_full_time()

## Replay a build-up that broke through: fill the bar to the line, move the ball on, carry the rest.
func _replay_build(events: Array) -> void:
	build_bar.visible = true
	build_bar.modulate = Color(1.0, 0.75, 0.25)
	for e in events:
		match e["type"]:
			"build":
				await _fill_bar(min(e["build"], e["target"]), e["target"])
			"advance":
				if e.has("index"):
					await get_tree().create_timer(SettingsState.t(0.15)).timeout
					pitch_strip.show_ball_at(e["index"])
					build_bar.value = 0
					await get_tree().create_timer(SettingsState.t(0.3)).timeout
			"carry":
				await _fill_bar(e["build"], e["target"])

## Animate the bar up to a value against a target.
func _fill_bar(value: int, maximum: int) -> void:
	build_bar.max_value = maximum
	build_label.text = "Build-up %d / %d" % [value, maximum]
	var t := create_tween()
	t.tween_property(build_bar, "value", value, SettingsState.t(0.3))
	await t.finished

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
		CoinState.new_run()
		get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
	elif pitch.goals > pitch.conceded:
		get_tree().change_scene_to_file("res://Scenes/reward_screen.tscn")
	else:
		get_tree().change_scene_to_file("res://Scenes/shop_screen.tscn")

# ---------- Screen ----------
## The draw pile (bottom-left) and discard pile (bottom-right), made in code.
func _add_piles() -> void:
	draw_view.setup("Draw", Color("2f5d8a"))
	discard_view.setup("Discard", Color("5a4a3a"))
	for pile in [draw_view, discard_view]:
		add_child(pile)
		move_child(pile, hand.get_index())   ## behind the hand and the full-time panel
	draw_view.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, PILE_MARGIN)
	discard_view.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, PILE_MARGIN)

func _update_piles() -> void:
	draw_view.set_count(DeckState.draw_pile.size())
	discard_view.set_count(DeckState.discard_pile.size())
	if DeckState.take_reshuffled():
		discard_view.pulse()
		draw_view.pulse()


func refresh_all() -> void:
	hand.refresh()
	_update_piles()	
	pitch_strip.show_state(pitch)
	info_label.text = "%s\nOpponent strength %d\n%d' \nYou %d - %d Them\nEnergy %d" % [
			LeagueState.current_tournament_name(), pitch.strength,
			pitch.minute, pitch.goals, pitch.conceded, pitch.energy]
	shoot_button.visible = pitch.in_their_box() and not pitch.match_over
	let_through_button.visible = not pitch.has_ball and not pitch.match_over
	let_through_button.text = "Let them shoot" if pitch.in_our_box() else "Let them through"
	for card_ui in hand.get_children():
		if not pitch.can_play_here(card_ui.card):
			card_ui.modulate = Color(1, 1, 1, 0.3)      ## can't be played here
		elif pitch.would_succeed(card_ui.card):
			card_ui.modulate = Color(0.6, 1.0, 0.6)     ## gets you through
		else:
			card_ui.modulate = Color(1, 1, 1, 1)        ## playable, adds to the bar
		## The build-up / hold bar: hidden inside either box, where the chance works differently.
	build_bar.visible = not pitch.match_over and not pitch.in_their_box() and not pitch.in_our_box()
	build_bar.max_value = pitch.target
	create_tween().tween_property(build_bar, "value", pitch.build, SettingsState.t(0.3))
	if pitch.has_ball:
		build_bar.modulate = Color(1.0, 0.75, 0.25)     ## amber: your build-up
		build_label.text = "Build-up %d / %d" % [pitch.build, pitch.target]
	else:
		build_bar.modulate = Color(0.5, 0.7, 1.0)       ## blue: your hold
		build_label.text = "Holding %d / %d" % [pitch.build, pitch.target]
	
func describe(events: Array) -> String:
	var lines: PackedStringArray = []
	for e in events:
		match e["type"]:
			# --- You attacking ---
			"build":
				if not e["helpers"].is_empty():
					lines.append("   (boosted by %s)" % ", ".join(e["helpers"]))
				lines.append("%s +%d: build-up %d / %d." % [e["card"], e["power"], e["build"], e["target"]])
			"carry":
				lines.append("Momentum carries on: %d towards a press of %d." % [e["build"], e["target"]])
			"advance":
				lines.append("Ball moves into %s." % e["zone"])
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
				lines.append("[color=gold][b]GOAL![/b] You've scored %d.[/color]" % e["goals"])
			"corner":
				lines.append("Tipped round the post. Corner! Chance reset to 20, +1 energy.")
			"saved":
				lines.append("Saved.")
			"turnover":
				lines.append("Lost the ball in %s. They're attacking." % e["zone"])
			# --- Them attacking ---
			"hold":
				if not e["helpers"].is_empty():
					lines.append("   (boosted by %s)" % ", ".join(e["helpers"]))
				lines.append("%s +%d: holding %d / %d." % [e["card"], e["power"], e["build"], e["target"]])
			"they_advance":
				lines.append("They move into %s." % e["zone"])
			"they_in_box":
				lines.append("They're in your box with a chance of %d!" % e["quality"])
			"blocked":
				lines.append("%s: their chance down to %d." % [e["card"], e["quality"]])
			"their_shot":
				lines.append("THEY SHOOT! Chance %d vs your keeper %d..." % [e["quality"], e["save"]])
			"conceded":
				lines.append("[color=#e04040]Goal for them. (%d conceded)[/color]" % e["conceded"])
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
				lines.append("[b]FULL TIME![/b]")
			"not_here":
				lines.append("%s can't be played here." % e["card"])
			"no_options":
				lines.append("No way forward. You're closed down and lose the ball.")
			"wrong_side":
				lines.append("%s can't be played right now." % e["card"])
			"lumped":
				lines.append("Lumped it clear! They restart from %s." % e["zone"])
			"coach":
				var again := "" if e["times"] == 1 else " (×%d)" % e["times"]
				lines.append("%s: +%d coins%s" % [e["name"], e["coins"], again])
	return "\n".join(lines)
	
## Show a message: the last line as the big headline, every line added to the log with the minute.
## log_it = false for things that didn't really happen (e.g. "can't play that card").
func _say(text: String, log_it: bool = true) -> void:
	var lines := text.split("\n")
	commentary_headline.text = lines[lines.size() - 1]
	## A quick "typed out" effect on the headline.
	commentary_headline.visible_ratio = 0.0
	create_tween().tween_property(commentary_headline, "visible_ratio", 1.0, SettingsState.t(0.3))
	if log_it:
		for line in lines:
			commentary_log.append_text("[color=#9a9a9a]%d'[/color]  %s\n" % [pitch.minute, line])

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
				_say("DEBUG: jumped to %s." % LeagueState.current_tournament_name(), false)
				refresh_all()
