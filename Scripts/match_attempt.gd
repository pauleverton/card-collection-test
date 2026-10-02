extends Control

## Drag-and-drop battle screen. Two vertical columns of up to 3 card slots
## each (yours on the left, opponent's on the right, see battle.tscn).
##
## Flow, fully automatic once the match starts — no buttons anywhere:
##   1. Drag one of YOUR card slots onto one of THEIR card slots to attack.
##      (Optionally drag the consumable icon onto one of your own cards
##      first, to boost its next shot.)
##   2. Dropping commits the shot immediately: rolls animate, result flashes
##      on both cards involved.
##   3. After a short pause, the opponent's (AI-controlled) reply plays out
##      automatically the same way.
##   4. After another short pause, the round advances automatically. Slots
##      unlock and you can drag again, until the match ends.
##
## DEBUG_MODE registers clearly-named fake AWAY (opponent) cards at runtime
## so the two squads are easy to tell apart while testing — your squad
## (player_squad) stays your real cards throughout. Set DEBUG_MODE = false
## once real opponent squad generation is ready.

const DEBUG_MODE := true

@onready var match_logic: MatchLogic = $MatchLogic
@onready var round_label: Label = $TopBar/RoundLabel
@onready var score_label: Label = $TopBar/ScoreLabel
@onready var result_label: Label = $ResultLabel

@onready var full_time_overlay: Control = $FullTimeOverlay
@onready var full_time_label: Label = $FullTimeOverlay/CenterContainer/Panel/Margin/VBox/FullTimeLabel
@onready var back_to_locker_room_button: Button = $FullTimeOverlay/CenterContainer/Panel/Margin/VBox/BackButton

@onready var player_slots: Array[BattleCardSlot] = [
	$PlayerSlot1,
	$PlayerSlot2,
	$PlayerSlot3
]
@onready var opponent_slots: Array[BattleCardSlot] = [
	$OpponentSlot1,
	$OpponentSlot2,
	$OpponentSlot3
]
@onready var consumable_slot: ConsumableSlot = $ConsumableRow/ConsumableSlot

# Matchup panel. Node names are historical (AttackerColumn/DefenderColumn
# from an earlier layout) but are now used as fixed HOME (you) / AWAY
# (opponent) columns — left is always yours, right is always theirs.
@onready var player_name_label: Label = $MatchupPanel/AttackerColumn/AttackerNameLabel
@onready var player_roll_label: Label = $MatchupPanel/AttackerColumn/AttackerRollLabel
@onready var chance_label: Label = $MatchupPanel/VsColumn/ChanceLabel
@onready var opponent_name_label: Label = $MatchupPanel/DefenderColumn/DefenderNameLabel
@onready var opponent_roll_label: Label = $MatchupPanel/DefenderColumn/DefenderRollLabel

## Drag-in-progress attack arrow — a Line2D + Polygon2D that follows the
## cursor from the origin card while dragging, purely for feel.
@onready var attack_line: Line2D = $AttackLine
@onready var arrow_head: Polygon2D = $ArrowHead
var _drag_origin_slot: BattleCardSlot = null


const ROLL_ANIMATION_STEPS := 10
const ROLL_ANIMATION_STEP_DELAY := 0.15
const TARGET_REVEAL_PAUSE := 1.2
const ROUND_ADVANCE_PAUSE := 1.5

const COINS_FOR_WIN := 100
const COINS_FOR_DRAW := 40
const COINS_FOR_LOSS := 10

var player_squad: Array[String] = []
var opponent_squad: Array[String] = []
var _last_shot: Dictionary = {}
var _round_active: bool = false  # true while a shot/round sequence is playing out
var _active_boss: BossTeam = null  # set only when this match is the season's decider

# Temporary in-code test consumable — swap for a .tres resource loaded from
# res://data/consumables/ once you have a proper item/inventory system.
var _lucky_boots: ConsumableCard


func _ready() -> void:
	player_squad = _get_player_squad()
	_setup_debug_opponent_cards()

	_lucky_boots = ConsumableCard.new()
	_lucky_boots.id = "lucky_boots"
	_lucky_boots.display_name = "Lucky Boots"
	_lucky_boots.description = "Your next shot rolls a d30 instead of a d20."
	_lucky_boots.max_uses = 1
	var boost := DiceBoostEffect.new()
	boost.dice_sides = 30
	_lucky_boots.effect = boost

	match_logic.shot_resolved.connect(_on_shot_resolved)
	match_logic.round_started.connect(_on_round_started)
	match_logic.match_ended.connect(_on_match_ended)
	back_to_locker_room_button.pressed.connect(_on_back_to_locker_room_pressed)

	for slot in player_slots:
		slot.side = "player"
		slot.consumable_dropped.connect(_on_consumable_dropped)
		slot.drag_started.connect(_on_attack_drag_started)

	for slot in opponent_slots:
		slot.side = "opponent"
		slot.attack_dropped.connect(_on_attack_dropped)

	_clear_matchup_panel()
	result_label.text = ""
	score_label.text = ""
	round_label.text = ""

	_start_match()


## Registers clearly-named fake AWAY test cards at runtime so the opposition
## is obviously distinct from your real squad while debugging. Doesn't touch
## card_database.tres, and doesn't affect player_squad at all — that stays
## your real cards. Safe to delete this function (and DEBUG_MODE) once real
## opponent squad generation is wired up.

func _get_player_squad() -> Array[String]:
	var squad: Array[String] = []
	for id in MatchSquadState.get_ordered_selection():
		squad.append(id)
	return squad


func _setup_debug_opponent_cards() -> void:
	if not DEBUG_MODE:
		return

	var away_data := [
		{"id": "debug_away_striker", "name": "Test Striker (Away)", "position": "FWD", "attack": 70, "defense": 25},
		{"id": "debug_away_mid", "name": "Test Midfielder (Away)", "position": "MID", "attack": 50, "defense": 50},
		{"id": "debug_away_keeper", "name": "Test Keeper (Away)", "position": "GK", "attack": 15, "defense": 90},
	]

	opponent_squad.clear()
	for data in away_data:
		opponent_squad.append(_register_debug_card(data))


func _register_debug_card(data: Dictionary) -> String:
	var card := CardData.new()
	card.id = data.id
	card.display_name = data.name
	card.position = data.position
	card.attack = data.attack
	card.defense = data.defense
	CardDatabase.register_debug_card(card)
	return card.id


func _clear_matchup_panel() -> void:
	player_name_label.text = ""
	player_roll_label.text = ""
	chance_label.text = ""
	opponent_name_label.text = ""
	opponent_roll_label.text = ""


## --- Match start / slot population ---

func _start_match() -> void:
	_active_boss = null
	var match_conditions: Array[MatchCondition] = []

	if LeagueState.is_last_match_of_season() and LeagueState.current_season_boss != null:
		_active_boss = LeagueState.current_season_boss
		opponent_squad = SquadGenerator.generate_boss_squad(3, _active_boss.base_rarity)
		match_conditions = _active_boss.conditions
	elif not DEBUG_MODE:
		opponent_squad = SquadGenerator.generate_random_squad(3)
	# else: DEBUG_MODE regular match keeps the fixed debug squad already
	# set up in _setup_debug_opponent_cards() during _ready()

	_populate_column(player_slots, player_squad)
	_populate_column(opponent_slots, opponent_squad)
	_set_all_interactive(true)

	_clear_matchup_panel()
	if _active_boss != null:
		result_label.text = "SEASON DECIDER vs %s! Drag one of your players onto an opponent to attack." % _active_boss.boss_name
	else:
		result_label.text = "Drag one of your players onto an opponent to attack."
	score_label.text = "You: 0   Opponent: 0"

	_lucky_boots.reset_uses()
	consumable_slot.set_consumable(_lucky_boots)

	match_logic.start_match(player_squad, opponent_squad, match_conditions)


## Fills each slot with a card, up to however many are in the squad (3 max);
## any leftover slots (e.g. a squad of only 1 or 2) are hidden entirely.
func _populate_column(slots: Array[BattleCardSlot], squad: Array[String]) -> void:
	for i in range(slots.size()):
		if i < squad.size():
			slots[i].set_card(squad[i])
		else:
			slots[i].set_card("")


func _set_all_interactive(value: bool) -> void:
	for slot in player_slots:
		if slot.card_id != "":
			slot.set_interactive(value)
	for slot in opponent_slots:
		if slot.card_id != "":
			slot.set_interactive(value)


func _find_slot(card_id: String) -> BattleCardSlot:
	for slot in player_slots:
		if slot.card_id == card_id:
			return slot
	for slot in opponent_slots:
		if slot.card_id == card_id:
			return slot
	return null


## Thin wrapper around _find_slot().flash_result() that won't crash if the
## card id doesn't match a live slot for some reason — flashing is a visual
## nicety, not worth taking the whole match down over.
func _flash_slot(card_id: String, scored: bool) -> void:
	var slot := _find_slot(card_id)
	if slot == null:
		push_warning("match_attempt: no slot found for card '%s', skipping flash" % card_id)
		return
	slot.flash_result(scored)


## --- Consumable ---

func _on_consumable_dropped(consumable_id: String, target_slot: BattleCardSlot) -> void:
	if _round_active or consumable_id != _lucky_boots.id:
		return
	if not _lucky_boots.use(match_logic):
		return

	target_slot.set_boosted(true)
	consumable_slot.refresh()

	var boosted_sides := match_logic.get_pending_player_dice_sides()
	result_label.text = "%s equipped %s! Next shot rolls a d%d." % [
		_display_name(target_slot.card_id), _lucky_boots.display_name, boosted_sides
	]


## --- Player's turn: drag attacker onto a target ---

func _on_attack_dropped(attacker_id: String, target_slot: BattleCardSlot) -> void:
	if _round_active:
		return
	_run_player_shot(attacker_id, target_slot.card_id)


func _run_player_shot(attacker_id: String, defender_id: String) -> void:
	_round_active = true
	_set_all_interactive(false)

	_show_matchup(attacker_id, "Attacking", defender_id, "Defending")
	result_label.text = ""

	match_logic.resolve_player_shot(attacker_id, defender_id)
	await _animate_dual_roll()

	var shot := _last_shot
	_flash_slot(attacker_id, shot.scored)
	_flash_slot(defender_id, not shot.scored)
	_clear_all_boosted()
	_reveal_last_shot()

	await get_tree().create_timer(TARGET_REVEAL_PAUSE).timeout

	await _run_opponent_shot()

	await get_tree().create_timer(ROUND_ADVANCE_PAUSE).timeout
	_advance_round()


## --- Opponent's turn (AI-controlled, runs automatically) ---

func _run_opponent_shot() -> void:
	var shooter := match_logic.get_current_opponent_shooter()
	var target := match_logic.preview_opponent_target()  # one of YOUR cards
	_show_matchup(target, "Defending", shooter, "Attacking")
	result_label.text = "%s is targeting your %s!" % [_display_name(shooter), _display_name(target)]

	await get_tree().create_timer(TARGET_REVEAL_PAUSE).timeout

	match_logic.resolve_opponent_shot()
	await _animate_dual_roll()

	var shot := _last_shot
	_flash_slot(shooter, shot.scored)
	_flash_slot(target, not shot.scored)
	_reveal_last_shot()


func _clear_all_boosted() -> void:
	for slot in player_slots:
		slot.set_boosted(false)


## --- Round advance (automatic) ---

func _advance_round() -> void:
	_clear_matchup_panel()
	match_logic.advance_round()

	if match_logic.match_over:
		return

	result_label.text = "Drag one of your players onto an opponent to attack."
	_set_all_interactive(true)
	_round_active = false


## --- Matchup panel (fixed home/away columns) ---

## player_id/player_role always populate the LEFT column, opponent_id/
## opponent_role always populate the RIGHT column — regardless of which
## side is attacking this exchange. Role text ("Attacking"/"Defending")
## is what changes, not which side the names appear on.
func _show_matchup(player_id: String, player_role: String, opponent_id: String, opponent_role: String) -> void:
	player_name_label.text = "%s\n(%s)" % [_display_name(player_id), player_role]
	player_roll_label.text = "d20: —"
	opponent_name_label.text = "%s\n(%s)" % [_display_name(opponent_id), opponent_role]
	opponent_roll_label.text = "d20: —"

	var chance: int
	if player_role == "Attacking":
		chance = match_logic.calculate_goal_chance(player_id, opponent_id)
	else:
		chance = match_logic.calculate_goal_chance(opponent_id, player_id)
	chance_label.text = "Chance to\nscore: %d%%" % chance


## Spins both dice independently in their own (fixed) column before landing
## on the real rolls. Reads _last_shot to work out which roll belongs to
## the player's side vs the opponent's side, since BattleManager only knows
## "attacker"/"defender", not "home"/"away".
func _animate_dual_roll() -> void:
	var shot := _last_shot
	var final_player_roll: int
	var player_mod: int
	var player_sides: int
	var player_bonus: int
	var final_opponent_roll: int
	var opponent_mod: int
	var opponent_sides: int
	var opponent_bonus: int

	if shot.is_player:
		final_player_roll = shot.attacker_roll
		player_mod = shot.attacker_modifier
		player_sides = shot.attacker_dice_sides
		player_bonus = shot.attacker_bonus
		final_opponent_roll = shot.defender_roll
		opponent_mod = shot.defender_modifier
		opponent_sides = shot.defender_dice_sides
		opponent_bonus = shot.defender_bonus
	else:
		final_player_roll = shot.defender_roll
		player_mod = shot.defender_modifier
		player_sides = shot.defender_dice_sides
		player_bonus = shot.defender_bonus
		final_opponent_roll = shot.attacker_roll
		opponent_mod = shot.attacker_modifier
		opponent_sides = shot.attacker_dice_sides
		opponent_bonus = shot.attacker_bonus

	for i in range(ROLL_ANIMATION_STEPS):
		player_roll_label.text = "d%d: %d" % [player_sides, randi_range(1, player_sides)]
		opponent_roll_label.text = "d%d: %d" % [opponent_sides, randi_range(1, opponent_sides)]
		await get_tree().create_timer(ROLL_ANIMATION_STEP_DELAY).timeout

	# is_player == true means the PLAYER column is attacking this exchange —
	# used only to label which support bonus applied (Midfield while
	# attacking, GK while defending). player_mod/opponent_mod already
	# include the bonus (match_logic.gd folds it in before emitting), so
	# the base modifier shown here is back-calculated purely for display —
	# the "= total" always reflects the true, already-boosted total either way.
	var player_base_mod := player_mod - player_bonus
	var opponent_base_mod := opponent_mod - opponent_bonus

	player_roll_label.text = "d%d: %d  %s%s  = %d" % [
		player_sides, final_player_roll, _format_modifier(player_base_mod),
		_support_note(player_bonus, shot.is_player), final_player_roll + player_mod
	]
	opponent_roll_label.text = "d%d: %d  %s%s  = %d" % [
		opponent_sides, final_opponent_roll, _format_modifier(opponent_base_mod),
		_support_note(opponent_bonus, not shot.is_player), final_opponent_roll + opponent_mod
	]
	await get_tree().create_timer(1.0).timeout


## Describes a GK/midfielder support bonus as its own term in the equation,
## e.g. " +6(GK)" — appears between the base modifier and the "=", so the
## roll line reads as roll, base mod, support bonus, total: all visible,
## nothing hidden inside a single lumped number.
func _support_note(bonus: int, is_attacking_side: bool) -> String:
	if bonus <= 0:
		return ""
	var source := "MID" if is_attacking_side else "GK"
	return "  +%d(%s)" % [bonus, source]


func _format_modifier(modifier: int) -> String:
	return ("+%d" % modifier) if modifier >= 0 else str(modifier)


func _reveal_last_shot() -> void:
	var shot := _last_shot
	var who := "You" if shot.is_player else "Opponent"
	var outcome := "GOAL!" if shot.scored else "Missed"
	result_label.text = "%s: %s" % [who, outcome]
	score_label.text = "You: %d   Opponent: %d" % [match_logic.player_goals, match_logic.opponent_goals]


# --- Shared helpers ---

func _display_name(card_id: String) -> String:
	var card: CardData = CardDatabase.get_card(card_id)
	if card == null or card.display_name == "":
		return card_id
	return card.display_name


func _on_round_started(round_number: int) -> void:
	round_label.text = "Round %d / %d" % [round_number, match_logic.total_rounds]


func _on_shot_resolved(
	attacker_id: String, defender_id: String,
	attacker_roll: int, attacker_modifier: int, attacker_dice_sides: int, attacker_bonus: int,
	defender_roll: int, defender_modifier: int, defender_dice_sides: int, defender_bonus: int,
	scored: bool, is_player_shot: bool
) -> void:
	_last_shot = {
		"attacker": attacker_id,
		"defender": defender_id,
		"attacker_roll": attacker_roll,
		"attacker_modifier": attacker_modifier,
		"attacker_dice_sides": attacker_dice_sides,
		"attacker_bonus": attacker_bonus,
		"defender_roll": defender_roll,
		"defender_modifier": defender_modifier,
		"defender_dice_sides": defender_dice_sides,
		"defender_bonus": defender_bonus,
		"scored": scored,
		"is_player": is_player_shot
	}


func _on_match_ended(player_goals: int, opponent_goals: int, player_won: bool) -> void:
	var verdict: String
	var coins_awarded: int

	if player_goals == opponent_goals:
		verdict = "It's a draw."
		coins_awarded = COINS_FOR_DRAW
	elif player_won:
		verdict = "You win!"
		coins_awarded = COINS_FOR_WIN
	else:
		verdict = "You lose."
		coins_awarded = COINS_FOR_LOSS

	CoinState.add_coins(coins_awarded)

	var league_note := _apply_league_result(player_goals, opponent_goals)
	var result_line := "%s (%d-%d)\n+%d coins" % [verdict, player_goals, opponent_goals, coins_awarded]

	result_label.text += "\n\nMATCH OVER — %s\n%s" % [result_line, league_note]
	full_time_label.text = "FULL TIME\n\n%s\n\n%s" % [result_line, league_note]
	full_time_overlay.visible = true

	_set_all_interactive(false)
	_round_active = true  # locks out any stray drags now the match is over


func _on_back_to_locker_room_pressed() -> void:
	get_tree().change_scene_to_file("res://lockerroom.tscn")


## Feeds this match's result into LeagueState and returns a short line for
## the result label describing what happened league-wise — either "here's
## where the table stands" (most matches), or the season-end outcome
## (promoted / missed promotion / crowned champion) on the season's last match.
func _apply_league_result(player_goals: int, opponent_goals: int) -> String:
	var tournament_name_before := LeagueState.current_tournament_name()
	var target := LeagueState.promotion_target()
	var was_final_tournament := LeagueState.is_final_tournament()

	var result := LeagueState.record_match_result(player_goals, opponent_goals)

	if not result.season_ended:
		var points: int = result.final_points
		var remaining := LeagueState.matches_remaining()
		return "%s: %d point%s so far (%d match%s left, need %d to go up)." % [
			tournament_name_before, points, ("" if points == 1 else "s"),
			remaining, ("" if remaining == 1 else "es"), target
		]

	var final_points: int = result.final_points
	if not result.promoted:
		return "Missed promotion from %s — needed %d points, finished on %d. Run over." % [
			tournament_name_before, target, final_points
		]
	if was_final_tournament:
		return "CHAMPION! %d points in %s — you've won every tournament. Run complete!" % [
			final_points, tournament_name_before
		]
	return "Promoted! %d points in %s (needed %d) — you're up to %s." % [
		final_points, tournament_name_before, target, LeagueState.current_tournament_name()
	]

## --- Attack-drag arrow (cursor-following line + arrowhead) ---

func _on_attack_drag_started(from_slot: BattleCardSlot) -> void:
	_drag_origin_slot = from_slot
	attack_line.visible = true
	arrow_head.visible = true

func _process(_delta: float) -> void:
	if _drag_origin_slot == null:
		return
	if not get_viewport().gui_is_dragging():
		# drag ended, however it ended - hide and clear
		_drag_origin_slot = null
		attack_line.visible = false
		arrow_head.visible = false
		return

	var start: Vector2 = attack_line.to_local(_drag_origin_slot.global_position + _drag_origin_slot.size / 2)
	var end: Vector2 = attack_line.to_local(get_global_mouse_position())
	attack_line.points = [start, end]
	arrow_head.position = end
	arrow_head.rotation = (end - start).angle()
