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
@onready var build_bar = $BuildBar
@onready var build_label = $BuildBar/BuildLabel
const LEAGUE_TABLE := preload("res://Scenes/league_table_view.tscn")
const COINS_VIEW := preload("res://Scenes/coins_view.tscn")

var pitch := MatchRules.new()
var busy := false
const OPENING_HAND := 5
const MAX_REDEALS := 3        ## after this many, an unplayable hand just loses the ball
const WHISTLE_PAUSE := 1.5      ## seconds on the final score before the full-time panel
var draw_view := PileView.new()
var discard_view := PileView.new()
var box_view := BoxView.new()
var scoreboard := ScoreboardView.new()
var squad_bar := VBoxContainer.new()     ## the matchday squad, down the left
var squad_tiles: Array = []              ## the SquadTileViews in squad_bar (not the headings)
var _dugout_heading: Control = null      ## players always go above this
var energy_label := Label.new()
var stage := Control.new()               ## holds the whole match screen, see _build_layout()
const BOX_SUSPENSE := 0.9      ## seconds on "Short pass... 30% risk" before the result
const BOX_RESULT_PAUSE := 0.8  ## seconds on "CLOSED DOWN!" / "+15!" before the screen moves on

## ---------- Layout ----------
## Everything sits on a 1920×1080 "stage" kept in the middle of the window, so a wider
## window just adds background at the sides. Each Rect2 is (left, top, width, height).
const STAGE_SIZE := Vector2(1920, 1080)
const BACKGROUND := Color("0e1812")
const SCOREBOARD_RECT := Rect2(0, 16, 1920, 170)     ## centred at the top
const ROUND_RECT := Rect2(32, 26, 420, 80)           ## league + round, top-left corner
const SQUAD_RECT := Rect2(32, 186, 300, 580)         ## players, then coaches, down the left
const BAR_RECT := Rect2(356, 186, 1208, 44)          ## build-up / hold bar, above the pitch
const PITCH_RECT := Rect2(356, 244, 1208, 522)       ## the pitch, under the bar
const BOX_RECT := Rect2(356, 186, 1208, 580)         ## the box view: bar + pitch together (no bar in the box)
const COMMENTARY_RECT := Rect2(1588, 186, 300, 580)  ## down the right
const HAND_RECT := Rect2(356, 770, 1208, 310)        ## centred under the pitch
const DRAW_RECT := Rect2(32, 898, 110, 150)          ## bottom-left
const ENERGY_RECT := Rect2(162, 948, 170, 60)        ## next to the draw pile
const DISCARD_RECT := Rect2(1778, 898, 110, 150)     ## bottom-right
const ACTION_RECT := Rect2(1588, 918, 170, 110)      ## Shoot or Let them through (never both at once)
const SQUAD_GAP := 8                                 ## space between the tiles and headings
const PLAYERS_COLOUR := Color("f2b233")              ## "ON THE PITCH" heading
const COACHES_COLOUR := Color("7fb2f0")              ## "DUGOUT" heading
const HEADING_NOTE := Color("8fa190")
const BUILD_COLOUR := Color("f2b233")                ## bar: your build-up
const HOLD_COLOUR := Color("5fbf77")                 ## bar: holding their attack
const NOBODY_BACK_COLOUR := Color("e0574a")          ## bar: no defence at all
var _bar_fill := StyleBoxFlat.new()                  ## the bar's coloured part, see _set_bar_colour()

## Filled in at full time by LeagueState, and read by Continue to decide where to go next.
var league_result := {}
var was_final_tournament := false

func _ready() -> void:
	RunState.start_match_day()        ## uses up appearances; must run before the squad bar is built
	DeckState.start_match(RunState.deck)
	DeckState.draw(OPENING_HAND)
	pitch.start()
	hand.card_played.connect(play_card)
	let_through_button.pressed.connect(_on_let_through)
	shoot_button.pressed.connect(_on_shoot)
	continue_button.pressed.connect(_on_continue)	
	UiStyle.primary(continue_button)       ## full-time: the one main action
	full_time_panel.visible = false
	_say("Kick-off against %s. Beat the Press to move up the pitch." % LeagueState.next_opponent_label())
	_build_squad()
	_build_layout()
	_kick_off()
	
## Deal the opening hand. If none of it can be played, it goes back and is dealt again
## (up to MAX_REDEALS times). If it's still unplayable after that, you lose the ball as normal.
func _kick_off() -> void:
	busy = true
	await _refresh_and_wait()
	var redeals := 0
	while pitch.hand_is_unplayable() and redeals < MAX_REDEALS:
		redeals += 1
		_say("Nothing you can play. Redeal!")
		await get_tree().create_timer(hand.return_all_to(draw_view.centre())).timeout
		DeckState.redeal(OPENING_HAND)
		await _refresh_and_wait()
	busy = false
	var events := pitch.check_kick_off()
	if not events.is_empty():
		_after_action(events)

## Redraw the screen, then wait for any new cards to finish flying in.
func _refresh_and_wait() -> void:
	var deal_time := refresh_all()
	if deal_time > 0.0:
		await get_tree().create_timer(deal_time).timeout

# ---------- Player actions ----------

func play_card(card: ActionCard) -> void:
	if busy: return
	var gamble := _box_gamble_text(card)   ## worked out BEFORE the card changes the risk
	var events := pitch.play(card)
	## If the card couldn't be played at all, leave it in the hand.
	if events[0]["type"] in ["not_now", "no_energy","not_here", "wrong_side"]:
		_say(describe(events), false)
		return
	busy = true
	var fly_time: float = hand.send_to_discard(discard_view.centre())
	get_tree().create_timer(fly_time).timeout.connect(_update_piles)
	hand.modulate = Color(1, 1, 1, 0.4)    ## dim the hand while this play resolves
	var delay := 0.0
	## Players react once per trigger; a coach shouts "Again!" between rounds.
	var triggers := 1 + RunState.retriggers_for_card(card)
	var again_uis := []
	for ui in squad_tiles:
		if ui.player is CoachCard and ui.player.applies_to(card):
			for i in ui.player.retriggers:
				again_uis.append(ui)
	for t in triggers:
		for ui in squad_tiles:
			if ui.player is PlayerCard and ui.player.affects(card):
				ui.react(ui.player.effect_label(), delay)
				delay += SettingsState.t(0.25)
		if t < triggers - 1:
			again_uis[t].react("Again!", delay)
			delay += SettingsState.t(0.35)
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout   ## let the squad reactions finish first
	await _box_moment(gamble, events, card.tag)
	_after_action(events)


func _on_shoot() -> void:
	if busy: return
	var gamble := "SHOT!  Keeper dives..." if pitch.in_their_box() else ""
	var events := pitch.take_shot()
	if events[0]["type"] in ["not_now", "no_energy"]:
		gamble = ""
	busy = true
	await _box_moment(gamble, events)
	_after_action(events)

func _on_let_through() -> void:
	if busy: return
	_after_action(pitch.let_them_through())
	
## The other team in the match just played, from this round's results.
func _opponent_name() -> String:
	for r in league_result.get("results", []):
		if r["yours"]:
			return r["away"] if r["home_i"] == LeagueState.YOU else r["home"]
	return "them"

## Every action ends here, so the screen update and the full-time check happen in one place.
func _after_action(events: Array) -> void:
	for e in events:
		print(e)
	busy = true
	if events.any(func(e): return e["type"] in ["advance", "they_break"]):
		await _replay_build(events)
	_say(describe(events))
	var deal_time := refresh_all()
	hand.modulate = Color(1, 1, 1, 1)      ## back to normal once it's finished
	if deal_time > 0.0:
		await get_tree().create_timer(deal_time).timeout   ## still busy while new cards fly in
	if pitch.match_over:
		await _blow_whistle()      ## a moment on the final score first
		_show_full_time()          ## stays busy: nothing can be played after the whistle
		return
	busy = false

## Replay a build-up that broke through: fill the bar to the line, move the ball on, carry the rest.
func _replay_build(events: Array) -> void:
	if events.any(func(e): return e["type"] == "build"):
		build_bar.visible = true
		_set_bar_colour(BUILD_COLOUR)
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
			"press_changed":
				build_bar.visible = true
				_set_bar_colour(BUILD_COLOUR)
				await _fill_bar(min(e["build"], e["target"]), e["target"])
			"goal":
				_say("[color=gold][b]GOAL![/b][/color]", false)
				await get_tree().create_timer(SettingsState.t(0.8)).timeout
			"ran_through":
				## Their kick-off / ball won, then a break with nothing in the way.
				pitch_strip.show_their_ball_at(e["index"], "Nobody back!")
				build_bar.visible = true
				_set_bar_colour(NOBODY_BACK_COLOUR)   ## red: no defence at all
				build_bar.max_value = 1
				build_bar.value = 0
				build_label.text = "Holding 0 / 0, nobody back!"
				_say("Nobody back! It's a counter-attack!", false)
				await get_tree().create_timer(SettingsState.t(0.6)).timeout
			"they_break":
				pitch_strip.show_their_ball_at(e["index"], "Nobody back!")
				_show_info(e["minute"])
				_say("They break into %s..." % e["zone"], false)
				await get_tree().create_timer(SettingsState.t(0.45)).timeout

## Animate the bar up to a value against a target.
func _fill_bar(value: int, maximum: int) -> void:
	build_bar.max_value = maximum
	build_label.text = "Build-up %d / %d" % [value, maximum]
	var t := create_tween()
	t.tween_property(build_bar, "value", value, SettingsState.t(0.3))
	await t.finished

# ---------- Full time ----------

## The final whistle: score in the headline, cards fade away, short pause.
func _blow_whistle() -> void:
	_say("[color=gold][b]FULL TIME![/b]  You %d - %d %s[/color]" % [
			pitch.goals, pitch.conceded, LeagueState.next_opponent_label()], false)
	create_tween().tween_property(hand, "modulate:a", 0.0, SettingsState.t(0.6))
	await get_tree().create_timer(SettingsState.t(WHISTLE_PAUSE)).timeout

func _show_full_time() -> void:
	if full_time_panel.visible:
		return                     ## already shown: never record the result twice
	var coins := pitch.coins_earned()
	CoinState.add_coins(coins)

	## Read these BEFORE recording the result: promotion moves you to the next tournament.
	var tournament := LeagueState.current_tournament_name()
	was_final_tournament = LeagueState.is_final_tournament()
	league_result = LeagueState.record_match_result(pitch.goals, pitch.conceded)

	var result := "LOSS"
	if pitch.goals > pitch.conceded:
		result = "WIN"
	elif pitch.goals == pitch.conceded:
		result = "DRAW"

	full_time_background.visible = true
	hand.visible = false      
	squad_bar.visible=false      
	full_time_background.color = Color(0.1, 0.1, 0.1, 0.9)   # normal: dark
	var position: String = _ordinal(league_result["position"])
	var points: int = league_result["final_points"]
	var league_line := ""          ## only filled at the end of a season
	if league_result["season_ended"] and league_result["promoted"] and was_final_tournament:
		league_line = "%s champions with %d pts. YOU'VE WON EVERYTHING!" % [tournament, points]
		full_time_background.color = Color("b8902e")   # won it all: gold
		continue_button.text = "Start a new run"
	elif league_result["season_ended"] and league_result["promoted"]:
		league_line = "CHAMPIONS! Promoted from %s with %d pts!" % [tournament, points]
	elif league_result["season_ended"]:
		league_line = "Season over: finished %s with %d pts. Only 1st goes up. RUN OVER." % [position, points]
		full_time_background.color = Color("8b1e1e")   # run over: red
		continue_button.text = "Start a new run"

	var parts := PackedStringArray()
	parts.append("FULL TIME: %s" % result)
	if league_line != "":
		parts.append(league_line)
	full_time_label.text = "\n\n".join(parts)
	
	var coins_view = COINS_VIEW.instantiate()
	full_time_label.add_sibling(coins_view)            ## under FULL TIME
	coins_view.show_coins(pitch.coins_parts(), coins, CoinState.coins)

	## This round's results (yours first, your name in gold), then the table.
	full_time_label.get_parent().add_theme_constant_override("separation", 40)   ## gap between text, results, table, button
	var results_view := RichTextLabel.new()
	results_view.bbcode_enabled = true
	results_view.fit_content = true                    ## grows to fit the lines
	results_view.custom_minimum_size.x = 900           ## needs a width inside the VBox
	results_view.add_theme_font_size_override("normal_font_size", 28)
	results_view.text = _results_bbcode(league_result["results"])
	coins_view.add_sibling(results_view)               ## under the coins

	var table_view = LEAGUE_TABLE.instantiate()
	results_view.add_sibling(table_view)               ## under the results, above Continue
	table_view.refresh(league_result["standings"])
	
	table_view.refresh(league_result["standings"])
	
	full_time_panel.modulate.a = 0.0
	full_time_panel.visible = true
	create_tween().tween_property(full_time_panel, "modulate:a", 1.0, SettingsState.t(0.4))

## The rest of this round's scores, one per line.
## "League Results:" then every score this round, yours first, your team in gold.
func _results_bbcode(results: Array) -> String:
	var lines: PackedStringArray = ["[color=#a6a6a6]League Results:[/color]"]
	var ordered := results.filter(func(r): return r["yours"]) \
			+ results.filter(func(r): return not r["yours"])
	for r in ordered:
		lines.append("%s %d - %d %s" % [
				_team_bbcode(r["home"], r["home_i"]), r["home_goals"],
				r["away_goals"], _team_bbcode(r["away"], r["away_i"])])
	return "[center]%s[/center]" % "\n".join(lines)

## Your team's name in gold (same as the table); anyone else as normal.
func _team_bbcode(team_name: String, index: int) -> String:
	if index == LeagueState.YOU:
		return "[color=#f2c14e]%s[/color]" % team_name
	return team_name

func _ordinal(n: int) -> String:
	match n:
		1: return "1st"
		2: return "2nd"
		3: return "3rd"
	return "%dth" % n

func _on_continue() -> void:
	RunState.matches_played += 1
	var season_ended: bool = league_result["season_ended"]
	var run_over: bool = season_ended and (not league_result["promoted"] or was_final_tournament)
	if run_over:
		RunState.new_run()
		CareerState.start_new_run()
		CoinState.new_run()
		RunState.start_with_team_name = true     ## menu opens the name box straight away
		get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
		return
	RunState.last_result = {"scored": pitch.goals, "conceded": pitch.conceded, "opponent": _opponent_name()}
	RunState.roll_training()                 ## a new week: this week's training activity
	if season_ended:
		RunState.start_preseason()           ## promoted: the transfer window opens before the new season
	if pitch.goals > pitch.conceded:
		get_tree().change_scene_to_file("res://Scenes/reward_screen.tscn")
	else:
		get_tree().change_scene_to_file(RunState.next_break_screen())

# ---------- Screen ----------
## Build the screen: make the stage, then move every piece onto it at its Rect2 (see Layout).
## Pieces added later are drawn on top, so the hand goes last (cards hover over everything).
func _build_layout() -> void:
	$ColorRect.color = BACKGROUND
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.anchor_left = 0.5
	stage.anchor_right = 0.5
	stage.anchor_top = 0.5
	stage.anchor_bottom = 0.5
	stage.offset_left = -STAGE_SIZE.x / 2
	stage.offset_right = STAGE_SIZE.x / 2
	stage.offset_top = -STAGE_SIZE.y / 2
	stage.offset_bottom = STAGE_SIZE.y / 2
	add_child(stage)
	move_child(stage, full_time_panel.get_index())   ## behind the full-time panel

	## Top: scoreboard in the middle, league and round in the corner.
	var opponent := LeagueState.next_opponent()
	scoreboard.setup(LeagueState.your_name(),
			opponent.team_name if opponent else "Them",
			opponent != null and opponent.is_favourite)
	_place(scoreboard, SCOREBOARD_RECT)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	info_label.add_theme_font_size_override("font_size", 22)
	_place(info_label, ROUND_RECT)

	## Middle: squad | bar + pitch (or the box view) | commentary.
	_place(squad_bar, SQUAD_RECT)
	_place(build_bar, BAR_RECT)
	_place(pitch_strip, PITCH_RECT)
	_place(box_view, BOX_RECT)
	_style_build_bar()
	box_view.visible = false
	commentary_headline.add_theme_font_size_override("normal_font_size", 22)
	commentary_headline.fit_content = false          ## fixed height: a narrow column made it huge
	commentary_headline.custom_minimum_size.y = 110
	commentary_log.size_flags_vertical = Control.SIZE_EXPAND_FILL   ## the log fills the column
	$CommentaryBox.clip_contents = true
	_place($CommentaryBox, COMMENTARY_RECT)

	## Bottom: draw pile + energy | hand | action button + discard pile.
	draw_view.setup("Draw", Color("2f5d8a"))
	discard_view.setup("Discard", Color("5a4a3a"))
	_place(draw_view, DRAW_RECT)
	_place(discard_view, DISCARD_RECT)
	energy_label.add_theme_font_size_override("font_size", 34)
	energy_label.add_theme_color_override("font_color", Color("f2b233"))
	_place(energy_label, ENERGY_RECT)
	shoot_button.text = "SHOOT\n1 energy"
	UiStyle.primary(shoot_button)
	UiStyle.secondary(let_through_button)
	for button in [shoot_button, let_through_button]:
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   ## long labels wrap instead of widening
	_place(shoot_button, ACTION_RECT)
	_place(let_through_button, ACTION_RECT)
	hand.custom_minimum_size = Vector2.ZERO
	_place(hand, HAND_RECT)

## The build-up / hold bar: dark track, rounded coloured fill, the numbers written inside it.
func _style_build_bar() -> void:
	build_bar.show_percentage = false
	var track := StyleBoxFlat.new()
	track.bg_color = Color("0a120d")
	track.border_color = Color("2b4232")
	track.set_border_width_all(1)
	track.set_corner_radius_all(8)
	build_bar.add_theme_stylebox_override("background", track)
	_bar_fill.set_corner_radius_all(8)
	build_bar.add_theme_stylebox_override("fill", _bar_fill)
	build_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	build_label.offset_left = 16
	build_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	build_label.add_theme_font_size_override("font_size", 20)
	build_label.add_theme_color_override("font_color", Color.WHITE)
	build_label.add_theme_constant_override("outline_size", 6)
	build_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))

func _set_bar_colour(colour: Color) -> void:
	_bar_fill.bg_color = colour

## The matchday squad down the left: players under ON THE PITCH, coaches under DUGOUT.
func _build_squad() -> void:
	squad_bar.add_theme_constant_override("separation", SQUAD_GAP)
	var players := RunState.match_players()
	squad_bar.add_child(_squad_heading("ON THE PITCH",
			"%d / %d" % [players.size(), RunState.MATCHDAY_PLAYERS], PLAYERS_COLOUR))
	for p in players:
		_add_squad_tile(p)
	if not RunState.coaches().is_empty():
		_dugout_heading = _squad_heading("DUGOUT", "coaches always play", COACHES_COLOUR)
		squad_bar.add_child(_dugout_heading)
		for c in RunState.coaches():
			_add_squad_tile(c)

func _add_squad_tile(staff: StaffCard) -> void:
	var tile := SquadTileView.new()
	tile.setup(staff)
	squad_bar.add_child(tile)
	if staff is PlayerCard and _dugout_heading != null:
		squad_bar.move_child(tile, _dugout_heading.get_index())   ## players stay above the dugout
	squad_tiles.append(tile)

## A heading row: title on the left, a small note on the right.
func _squad_heading(title: String, note: String, colour: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	var title_label := Label.new()
	title_label.text = title
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", colour)
	row.add_child(title_label)
	var note_label := Label.new()
	note_label.text = note
	note_label.add_theme_font_size_override("font_size", 15)
	note_label.add_theme_color_override("font_color", HEADING_NOTE)
	row.add_child(note_label)
	return row

## Put a piece on the stage at a fixed place and size.
func _place(node: Control, rect: Rect2) -> void:
	if node.get_parent() == null:
		stage.add_child(node)
	elif node.get_parent() != stage:
		node.reparent(stage, false)
	node.set_anchors_preset(Control.PRESET_TOP_LEFT)
	node.position = rect.position
	node.size = rect.size

func _update_piles() -> void:
	draw_view.set_count(DeckState.draw_pile.size())
	discard_view.set_count(DeckState.discard_pile.size())
	if DeckState.take_reshuffled():
		discard_view.pulse()
		draw_view.pulse()

## The gamble line for a card played in their box ("" = no gamble, show nothing extra).
func _box_gamble_text(card: ActionCard) -> String:
	if not pitch.in_their_box() or not pitch.can_play_here(card) or card.energy_cost > pitch.energy:
		return ""
	if card.tag == "shot":
		return "SHOT!  Keeper dives..."
	var risk := pitch.box_risk(card.tag)
	if risk <= 0:
		return ""
	return "%s...  %d%% chance they close you down" % [card.display_name, risk]

## Hold on the gamble, then flash the result, before the screen moves on.
## tag = the card played (pass / dribble / cross), so the box drawing can show the right move.
func _box_moment(gamble: String, events: Array, tag: String = "") -> void:
	if gamble == "":
		return
	box_view.suspense(gamble)
	await get_tree().create_timer(SettingsState.t(BOX_SUSPENSE)).timeout
	var result := _box_result(events)
	if result.is_empty():
		return
	box_view.flash(result["text"], result["colour"], result["kind"], tag)
	await get_tree().create_timer(SettingsState.t(BOX_RESULT_PAUSE)).timeout

## What happened in the box, as one big word, plus its kind (for the box drawing).
func _box_result(events: Array) -> Dictionary:
	for e in events:
		match e["type"]:
			"goal":
				return {"text": "GOAL!", "colour": Color("f2b233"), "kind": "goal"}
			"box_lost":
				return {"text": "CLOSED DOWN!", "colour": Color("e0574a"), "kind": "lost"}
			"rebound":
				return {"text": "SAVED... REBOUND!", "colour": Color("f2b233"), "kind": "rebound"}
			"saved":
				return {"text": "SAVED", "colour": Color("e0574a"), "kind": "saved"}
			"corner":
				return {"text": "CORNER!", "colour": Color("6fb7f0"), "kind": ""}
			"quality":
				return {"text": "+%d!  Chance %d" % [e["gain"], e["quality"]], "colour": Color("7be07b"), "kind": "gain"}
	return {}


func refresh_all() -> float:
	hand.draw_from = draw_view.centre()
	var deal_time: float = hand.refresh()
	_update_piles()
	pitch_strip.show_state(pitch)
	box_view.show_state(pitch)
	pitch_strip.visible = not box_view.visible   ## the box view takes the strip's place
	for tile in squad_tiles:
		tile.show_state(pitch)                   ## ability chips: ON / FROM 75' / WHEN LOSING
	_show_info(pitch.minute)
	shoot_button.visible = pitch.in_their_box() and not pitch.match_over
	let_through_button.visible = not pitch.has_ball and not pitch.match_over
	let_through_button.text = "Let them shoot" if pitch.in_our_box() else "Let them through"
	for card_ui in hand.get_children():
		if not pitch.can_play_here(card_ui.card):
			card_ui.set_play_state("blocked")      ## can't be played here
		elif pitch.would_succeed(card_ui.card):
			card_ui.set_play_state("through")      ## gets you through
		else:
			card_ui.set_play_state("normal")       ## playable, adds to the bar
	## The build-up / hold bar: hidden inside either box, where the chance works differently.
	build_bar.visible = not pitch.match_over and not pitch.in_their_box() and not pitch.in_our_box()
	build_bar.max_value = pitch.target
	create_tween().tween_property(build_bar, "value", pitch.build, SettingsState.t(0.3))
	if pitch.has_ball:
		_set_bar_colour(BUILD_COLOUR)
		build_label.text = "Build-up %d / %d" % [pitch.build, pitch.target]
	else:
		_set_bar_colour(HOLD_COLOUR)
		build_label.text = "Holding %d / %d" % [pitch.build, pitch.target]
		if pitch.nobody_back():
			_set_bar_colour(NOBODY_BACK_COLOUR)
			build_label.text = "Holding 0 / 0, nobody back!"
	return deal_time
	
## Scoreboard, round and energy. Takes the minute so a replay can show the clock ticking.
func _show_info(minute: int) -> void:
	scoreboard.show_score(pitch.goals, pitch.conceded, minute)
	info_label.text = "%s\nRound %d of %d · %s in the table" % [
			LeagueState.current_tournament_name().to_upper(),
			LeagueState.matches_played + 1, LeagueState.matches_per_season(),
			_ordinal(LeagueState.position_of(LeagueState.YOU))]
	energy_label.text = "Energy %d" % pitch.energy
		
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
			"press_changed":
				lines.append("Their press is now %d (you've built %d)." % [e["target"], e["build"]])
			"hold_changed":
				lines.append("Their attack needs holding to %d now (you've held %d)." % [e["target"], e["build"]])
			"advance":
				lines.append("Ball moves into %s." % e["zone"])
			"in_the_box":
				lines.append("Into the box with a chance of %d." % e["quality"])
			"quality":
				lines.append("%s: +%d, chance now %d." % [e["card"], e["gain"], e["quality"]])
			"box_lost":
				lines.append("%s... closed down! (%d%% risk) They've got it." % [e["card"], e["risk"]])
			"rebound":
				lines.append("Saved, but it's loose! REBOUND: one more shot from %d." % e["quality"])
			"basic_shot":
				lines.append("You hit it... strike quality +%d." % e["roll"])
			"shot":
				lines.append("SHOT! Chance %d vs keeper %d..." % [e["quality"], e["save"]])
			"goal":
				lines.append("[color=gold][b]GOAL![/b] You've scored %d.[/color]" % e["goals"])
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
			"they_break":
				lines.append("They break into %s." % e["zone"])
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
			"ability":
				lines.append("[color=gold]%s[/color]" % e["text"])
			"sure_goal":
				lines.append("It was always going in!")
			"ran_through":
				lines.append("Nobody back! They're straight through to your box.")
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
				LeagueState.debug_skip_to_last_round()
				_say("DEBUG: skipped to the last round of %s (you won the rest)." %
						LeagueState.current_tournament_name(), false)
				refresh_all()
			KEY_L:
				pitch.minute = 57
				_say("DEBUG: jumped to 57", false)
				refresh_all()
			KEY_P:
				_debug_add_players()

## Debug: add Super Sub and Kitchen Sink to the squad (and the squad bar) for testing.
const DEBUG_PLAYERS := [
	"res://Resources/players/super_sub.tres",
	"res://Resources/players/kitchen_sink.tres",
	"res://Resources/players/park_the_bus.tres"]

func _debug_add_players() -> void:
	for path in DEBUG_PLAYERS:
		if RunState.squad.any(func(s): return s.resource_path == path):
			continue      ## already in the squad
		var p: PlayerCard = load(path)
		RunState.picked.append(p)   ## debug ignores the matchday limit, like MAX_PLAYERS
		_add_squad_tile(p)
	_say("DEBUG: added 3 players.", false)
	refresh_all()
