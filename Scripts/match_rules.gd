class_name MatchRules
extends RefCounted

## Zones: 0 = your box, 1 = your half, 2 = midfield, 3 = their half, 4 = their box
const ZONE_NAMES := ["Your box", "Your half", "Midfield", "Their half", "Their box"]
const START_ENERGY := 5
const POSSESSION_DRAW := 2   ## cards drawn every time the ball changes hands
## Each zone's target = opponent strength × this. Index = zone (0 your box … 4 their box).
const PRESS_WEIGHT := [0.8, 0.9, 1.0, 1.2, 1.0]
const ATTACK_WEIGHT := [1.0, 1.2, 1.0, 0.9, 0.8]

var strength := 40
## The opponent's ratings (1.0 = the league average). Set at kick-off.
var their_defence := 1.0   ## scales the press you face when attacking
var their_attack := 1.0    ## scales the hold you need when defending
var level := 1.0           ## strength ÷ BASE_STRENGTH: 1.0 in the first match of a run
var keeper_scale := 1.0    ## their keeper: level × their keeper rating (see KEEPER_STRETCH)
## Your shots do NOT scale: the Shoot button roll, the Shoot card, rebounds and corners stay
## the same all run, so better keepers need better cards and players to beat.


## --- You attacking: their box ---
## Push your luck: every card you play in the box raises the chance but risks losing
## the ball. Only Shoot (the button or the card) can score.
const BOX_ENERGY := 3   ## the least energy you have on entering the box (you keep more if you have it)
const SHOT_COST := 1
## How much of a card's power goes into the chance in the box (1.0 = full power).
const BOX_GAIN_SCALE := 0.5
## Risk (%) of losing the ball with the FIRST card you play in the box...
const BOX_RISK := {"pass": 20, "dribble": 15, "cross": 25}
## ...plus this much for every card already played in this attack (defenders get back).
const BOX_RISK_STEP := 15
## Of the times you LOSE the ball in their box, this % are fouls instead: a penalty for you.
## Dribbles get fouled most. Tags not listed never win a penalty.
const BOX_FOUL_SHARE := {"pass": 10, "dribble": 35, "cross": 15}
## PENALTIES (both teams) don't use the keeper decks or the league level: real-life odds instead.
const PEN_SAVE := 11              ## % saved by a Medium keeper
const PEN_MISS := 4               ## % wide or over (the rest go in: 85% against a Medium keeper)
const PEN_SAVE_PER_STEP := 2      ## each step of THEIR keeper's rating moves the save % by this (Very High: 15%)
## How much their defence rating moves the box risk. 1 + (rating − 1) × this:
## 2.0 → Very Low ×0.6, Medium ×1.0, Very High ×1.4. 0 = same against everyone.
const BOX_RISK_STRETCH := 2.0
const KEEPER_DECK := [20, 30, 30, 40, 40, 50, 50, 60, 70]
const BASIC_SHOT_ROLL_MAX := 40   ## every shot (button or card) adds a random 0 to this...
const BASIC_SHOT_ROLL_STEP := 10  ## ...in steps of this (0, 10, 20, 30, 40)
## When the keeper saves, this % of the time the ball falls for ONE more shot.
const REBOUND_CHANCE := 25
## The chance a rebound shot starts from.
const REBOUND_QUALITY := 30
## Their keeper gets better with the league level (strength ÷ BASE_STRENGTH) and their
## keeper rating, stretched like the box risk: 1 + (rating − 1) × this.
## 1.5 → Very Low ×0.7, Medium ×1.0, Very High ×1.3. 0 = keeper rating ignored.
const KEEPER_STRETCH := 1.5

## --- Them attacking ---
const THEIR_CHANCE_DECK := [30, 40, 40, 50, 50, 60, 60, 70]
const OUR_KEEPER_DECK := [20, 30, 30, 40, 40, 50, 50, 60, 70]
const MIN_THEIR_CHANCE := 10   ## you can never block a chance down to nothing (was 30)

## --- Your box: they attack, you react (TRIAL) ---
## Their attack is a few moves then a shot. You always see the next move. Block is safe but only
## lowers the chance; a challenge can end the attack, but if it fails you're beaten.
const THEIR_MOVE_GAINS := {"pass": 15, "dribble": 20, "cross": 25}   ## × their attack rating
const THEIR_MOVE_WORDS := {"pass": "Pass", "dribble": "Dribble", "cross": "Cross", "shot": "Shot"}
const THEIR_BUILD_MOVES := Vector2i(1, 2)   ## moves before the shot (picked at random in this range)
const TACKLE_BOX_BASE := 0       ## Tackle: success % = (this + the card's power) ÷ their strength (was 20)
const LUNGE_CHANCE := 15         ## a desperate lunge (the Lunge button): success % ÷ their strength (was 25)
## "Their strength" in your box = their attack rating × the league level, so challenges get harder as
## the run goes on (like their keeper in their box). 0 = ignore the level, 1 = full.
const TACKLE_LEVEL_STRETCH := 1.0
const LUNGE_COST := 1            ## energy for a lunge; it also throws a RANDOM non-defending card away
const TACKLE_REPEAT := 15        ## −this % for every challenge already tried in this attack
const TACKLE_FOUL_SHARE := 30    ## % of failed tackles that are fouls (a penalty) (was 25)
const LUNGE_FOUL_SHARE := 40     ## % of failed lunges that are fouls
const BEATEN_BONUS := 10         ## failed challenge: their next move happens straight away, +this
const TRACK_BACK_BOX_SCALE := 0.5  ## Track Back in your box lowers the chance by half its power

## --- Match clock and rewards ---
const MATCH_LENGTH := 90
const MINUTES_PER_ACTION := 3
const COINS_WIN := 100
const COINS_DRAW := 50
const COINS_LOSS := 20
const COINS_PER_GOAL := 10

var zone := 2
var energy := START_ENERGY
## true = you're attacking, false = they're attacking
var has_ball := true
## The number to beat: their Press when you attack, their Attack when they do.
var target := 0
## Bonus waiting for the next card (from Overlap, later from players).
var next_bonus := 0
## The chance in whichever box the ball is in: yours to raise, or theirs to lower.
var quality := 0
var build := 0
var goals := 0
var conceded := 0
var bonus_coins:=0
var _their_chance_pile: Array = []
var their_moves: Array = []   ## their attack in your box: [{"kind", "gain"}, …], always ends in a shot
var tackles_tried := 0        ## challenges already tried in this attack (each one is harder)
var box_cards_played := 0   ## cards played in their box this attack (raises the risk)
var rebound := false        ## true = the keeper parried it: one more shot, shots only
var penalty := false        ## true = you were fouled in their box: take_penalty() next, no cards
var their_keeper := 1.0     ## their keeper's rating (Very Low 0.8 ... Very High 1.2), for penalties
var _keeper_pile: Array = []
var _our_keeper_pile: Array = []
var minute := 0
var _was_active: Array = []
var _extra_minutes := 0   ## time used up during an action (e.g. Kitchen Sink run-through)   ## staff whose ability was on after the last action
var match_over := false

func start() -> void:
	zone = 2
	goals = 0
	conceded = 0
	has_ball = true
	energy = START_ENERGY
	next_bonus = 0
	quality = 0
	bonus_coins=0
	strength = LeagueState.opponent_strength()
	var opponent := LeagueState.next_opponent()
	their_defence = opponent.defence if opponent != null else 1.0
	their_attack = opponent.attack if opponent != null else 1.0
	level = float(strength) / LeagueState.BASE_STRENGTH
	their_keeper = opponent.keeper if opponent != null else 1.0
	keeper_scale = level * (1.0 + (their_keeper - 1.0) * KEEPER_STRETCH)
	_flip_press()
	minute = 0
	_was_active.clear()
	_extra_minutes = 0
	match_over = false
	box_cards_played = 0
	rebound = false
	penalty = false
	their_moves.clear()
	tackles_tried = 0

## True if you're attacking and nothing in the hand can be played (used for the kick-off redeal).
## When they kick off you're never stuck, because Let them through is always there, so no redeal.
func hand_is_unplayable() -> bool:
	return has_ball and not _has_playable_card()

## Kick-off isn't an action, so the "nothing playable, lose the ball" check never runs there.
## Run it once after the redeals, in case the hand still can't do anything.
func check_kick_off() -> Array:
	var events: Array = []
	_check_out_of_energy(events)
	return events

# ---------- Questions the screen can ask ----------

func in_their_box() -> bool:
	return has_ball and zone == 4

func in_our_box() -> bool:
	return not has_ball and zone == 0

## Risk (%) of losing the ball if you play a card with this tag in their box now,
## scaled by their defence rating (see BOX_RISK_STRETCH).
func box_risk(tag: String) -> int:
	if not BOX_RISK.has(tag):
		return 0
	var factor := 1.0 + (their_defence - 1.0) * BOX_RISK_STRETCH
	return clampi(roundi((BOX_RISK[tag] + BOX_RISK_STEP * box_cards_played) * factor), 0, 100)

## Of box_risk(tag): the % chance it ends in a penalty for you (a foul) rather than losing it.
func box_penalty_chance(tag: String) -> int:
	return roundi(box_risk(tag) * BOX_FOUL_SHARE.get(tag, 0) / 100.0)

## Your odds with the best Shoot card in your hand (-1 if you haven't got one).
## A Shoot card is the button's random strike PLUS the card's power, so it always beats the button.
func shot_card_odds() -> int:
	var best := -1
	for card in DeckState.hand:
		if card.tag == "shot":
			best = maxi(best, basic_shot_odds_at(quality + power_of(card)))
	return best

## Percentage chance YOUR shot of this quality beats their keeper.
func goal_odds(shot_quality: int) -> int:
	if _box_shot_always_scores():
		return 100
	var saves: Array = _keeper_pile if not _keeper_pile.is_empty() else KEEPER_DECK
	var beaten := 0
	for s in saves:
		if shot_quality > _keeper_save(s):
			beaten += 1
	return roundi(100.0 * beaten / saves.size())

## A keeper card scaled to this opponent (KEEPER_DECK is the first match of a run, Medium keeper).
func _keeper_save(card: int) -> int:
	return roundi(card * keeper_scale)

## The random part of every shot (Shoot button and Shoot card). Doesn't scale with the league.
func _shot_roll() -> int:
	return randi_range(0, BASIC_SHOT_ROLL_MAX / BASIC_SHOT_ROLL_STEP) * BASIC_SHOT_ROLL_STEP

## Average chance of scoring with the Shoot button from a chance of q, across every roll.
func basic_shot_odds_at(q: int) -> int:
	var total := 0
	for roll in range(0, BASIC_SHOT_ROLL_MAX + 1, BASIC_SHOT_ROLL_STEP):
		total += goal_odds(q + roll)
	return roundi(float(total) / (BASIC_SHOT_ROLL_MAX / BASIC_SHOT_ROLL_STEP + 1))

## The same from your current chance.
func basic_shot_odds() -> int:
	return basic_shot_odds_at(quality)
	
## The Shoot button's smallest and largest roll (for the screen).
func basic_shot_roll_low() -> int:
	return 0

func basic_shot_roll_high() -> int:
	return BASIC_SHOT_ROLL_MAX

## Their next move in your box ({} if they're not in your box).
func next_move() -> Dictionary:
	return their_moves[0] if in_our_box() and not their_moves.is_empty() else {}

## Their next move as a short line for the screen: "Next: Cross +25" / "Next: they shoot".
func next_move_text() -> String:
	var move := next_move()
	if move.is_empty() or move["kind"] == "shot":
		return "Next: they shoot"
	return "Next: %s +%d" % [THEIR_MOVE_WORDS[move["kind"]], move["gain"]]

## How hard their attackers are to tackle in your box: their attack rating × the league level.
func _box_strength() -> float:
	return their_attack * (1.0 + (level - 1.0) * TACKLE_LEVEL_STRETCH)

## % chance a Tackle card wins the ball in your box.
func tackle_chance(card: ActionCard) -> int:
	return clampi(roundi((TACKLE_BOX_BASE + power_of(card)) / _box_strength()) - TACKLE_REPEAT * tackles_tried, 5, 90)

## % chance a desperate lunge (the Lunge button) wins the ball in your box.
func lunge_chance() -> int:
	return clampi(roundi(LUNGE_CHANCE / _box_strength()) - TACKLE_REPEAT * tackles_tried, 5, 90)

## % chance a lunge ends in a foul (a penalty to them): the failures, times LUNGE_FOUL_SHARE.
func lunge_foul_chance() -> int:
	return roundi((100 - lunge_chance()) * LUNGE_FOUL_SHARE / 100.0)

## True if this card could be thrown away by a lunge (anything that isn't a defending card).
func is_lunge(card: ActionCard) -> bool:
	return in_our_box() and card.tag not in ["block", "tackle", "track_back", "lump_clear", "retain", "overlap"]

## Can you lunge now? (In your box, someone back, the energy, and a card to throw away.)
func can_lunge() -> bool:
	return in_our_box() and not match_over and not nobody_back() and energy >= LUNGE_COST \
			and DeckState.hand.any(func(c): return is_lunge(c))

## Your best tackle % from the cards in your hand (-1 if you haven't got a Tackle).
func best_tackle_chance() -> int:
	var best := -1
	for card in DeckState.hand:
		if card.tag == "tackle":
			best = maxi(best, tackle_chance(card))
	return best

## Percentage chance THEIR current chance beats your keeper.
func their_goal_odds() -> int:
	return _odds_to_beat(quality, _our_keeper_pile, OUR_KEEPER_DECK)

## The same for any chance (your box view shows "after their cross: 50 · 56%").
func their_goal_odds_at(q: int) -> int:
	return _odds_to_beat(q, _our_keeper_pile, OUR_KEEPER_DECK)

func power_of(card: ActionCard) -> int:
	var triggers := 1 + RunState.retriggers_for_card(card)
	var flat := (card.base_value + RunState.squad_bonus(card)) * triggers + next_bonus
	return roundi(flat * pow(RunState.squad_multiplier(card), triggers))

## Can this card be played in the current possession?
func is_right_phase(card: ActionCard) -> bool:
	match card.usable_when:
		"attacking":
			return has_ball
		"defending":
			return not has_ball
	return true

## Can this card do anything where the ball is right now?
func can_play_here(card: ActionCard) -> bool:
	if match_over or not is_right_phase(card):
		return false
	if not has_ball and nobody_back():
		return false     ## nobody back: it's down to the keeper
	if not _abilities_allow(card):
		return false     ## an ability has switched this card off
	if penalty:
		return false     ## a penalty: no cards, just the penalty button
	if rebound and card.tag != "shot":
		return false     ## rebound: shots only
	if card.play_zones != 0:
		return card.play_zones & (1 << zone) != 0
	if card.tag in ["retain", "overlap"]:
		return true
	if card.tag == "lump_clear":
		return zone <= 1
	if has_ball:
		if zone == 4:
			if card.tag in ["pass", "dribble", "cross"]:
				return energy - card.energy_cost >= SHOT_COST   ## always keep enough to shoot
			return card.tag == "shot"
		return card.tag in ["pass", "dribble", "long_ball"]
	if zone == 0:
		return card.tag in ["block", "tackle", "track_back"]
	return card.tag in ["tackle", "track_back"]
	
## True if the card would get you through (used for the green tint).
func would_succeed(card: ActionCard) -> bool:
	if not can_play_here(card):
		return false
	if card.tag in ["retain", "overlap", "lump_clear"]:
		return true
	if has_ball and zone == 4:
		return card.tag == "shot"   ## nothing else is ever safe in the box
	if not has_ball and zone == 0:
		return not is_lunge(card)   ## proper defending cards glow; lunges are just playable
	return build + power_of(card) >= target
	
## What this card adds to your chance in the box (its full power × BOX_GAIN_SCALE).
func box_gain(card: ActionCard) -> int:
	return roundi(power_of(card) * BOX_GAIN_SCALE)
	

# ---------- Actions ----------

func play(card: ActionCard) -> Array:
	var events := []
	if match_over:
		events.append({"type": "not_now"})
		return events
	if card.energy_cost > energy:
		events.append({"type": "no_energy"})
		return events
	if not is_right_phase(card):
		events.append({"type": "wrong_side", "card": card.display_name})
		return events
	if not can_play_here(card):
		events.append({"type": "not_here", "card": card.display_name})
		return events
	energy -= card.energy_cost
	DeckState.play(card)   ## the card leaves your hand as soon as it's played
	if card.tag == "overlap":
		next_bonus += card.base_value
		events.append({"type": "bonus", "next_bonus": next_bonus})
	elif card.tag == "retain":
		energy += card.energy_boost
		DeckState.draw(card.draw_count)
		events.append({"type": "retain", "energy": card.energy_boost, "drew": card.draw_count})
	elif card.tag == "lump_clear":
		_lump_clear(card, events)
	elif in_their_box():
		_play_in_box(card, events)
	elif has_ball:
		_play_in_build_up(card, events)
	elif in_our_box():
		_defend_in_box(card, events)
	else:
		_defend_build_up(card, events)
	_check_out_of_energy(events)
	_tick_clock(events)
	return events

## The Lunge button: a RANDOM non-defending card from your hand is thrown in (and discarded).
func lunge() -> Array:
	var events := []
	if not can_lunge():
		events.append({"type": "not_now"})
		return events
	var card: ActionCard = DeckState.hand.filter(func(c): return is_lunge(c)).pick_random()
	energy -= LUNGE_COST
	DeckState.play(card)
	events.append({"type": "lunge", "card": card})
	_box_challenge(card, lunge_chance(), LUNGE_FOUL_SHARE, true, events)
	_tick_clock(events)
	return events

func take_shot() -> Array:
	var events := []
	if match_over:
		events.append({"type": "not_now"})
		return events
	if not in_their_box():
		events.append({"type": "not_now"})
		return events
	if penalty:
		return take_penalty()   ## on a penalty, the shoot button takes the penalty
	if energy < SHOT_COST:
		events.append({"type": "no_energy"})
		return events
	energy -= SHOT_COST
	var roll := _shot_roll()
	quality += roll
	events.append({"type": "basic_shot", "roll": roll, "quality": quality})
	_shoot(events)
	_check_out_of_energy(events)
	_tick_clock(events)
	return events

## Defending: don't challenge, let them carry on (or shoot, if they're in your box).
func let_them_through() -> Array:
	var events := []
	if match_over:
		events.append({"type": "not_now"})
		return events
	if has_ball:
		events.append({"type": "not_now"})
		return events
	elif zone == 0:
		_their_move(events)
	else:
		_they_advance(events)
	_check_out_of_energy(events)
	_tick_clock(events)
	return events

# ---------- You attacking: build-up ----------

func _play_in_build_up(card: ActionCard, events: Array) -> void:
	match card.tag:
		"pass", "dribble", "long_ball":
			_attempt_move(card, events)
			if card.tag == "dribble":
				DeckState.draw(1)
				events.append({"type": "drew"})
		"long_shot":
			_long_shot(card, events)
		_:
			events.append({"type": "wrong_phase", "card": card.display_name})
			
func _attempt_move(card: ActionCard, events: Array) -> void:
	var power := power_of(card)
	next_bonus = 0
	build += power
	events.append({"type": "build", "card": card.display_name, "power": power,
			"build": build, "target": target, "helpers": RunState.squad_helpers(card)})
	_break_through(events)

## Break through as many zones as the build-up allows; any overflow carries on.
func _break_through(events: Array) -> void:
	while build >= target and zone < 4:
		var overflow := build - target
		zone += 1
		events.append({"type": "advance", "zone": ZONE_NAMES[zone], "index": zone})
		if zone == 4:
			_enter_box(overflow, events)
			return
		_flip_press()             ## empties the bar and reveals the new press...
		build = overflow          ## ...then the overflow goes in
		if build > 0:
			events.append({"type": "carry", "build": build, "target": target})

func _long_shot(card: ActionCard, events: Array) -> void:
	events.append({"type": "long_shot", "card": card.display_name, "chance": roundi(card.chance * 100)})
	if _roll(card):
		_score_goal(events)
	else:
		events.append({"type": "long_shot_miss"})
		zone = 4
		_start_their_possession(events)
		
func _flip_press() -> void:
	build = 0
	target = _press_target()

## The press you face in the current zone, including their defence and any ability that changes it.
func _press_target() -> int:
	return roundi(strength * their_defence * PRESS_WEIGHT[zone] * _press_multiplier())

## Recalculate the press (attacking) or hold (defending) mid-zone, keeping the bar's progress.
## If the new target is already reached, you break through / win the ball straight away.
func _recheck_press(events: Array) -> void:
	if zone == 4 and has_ball:
		return
	if zone == 0 and not has_ball:
		return
	if has_ball:
		var new_target := _press_target()
		if new_target == target:
			return
		target = new_target
		events.append({"type": "press_changed", "build": build, "target": target})
		_break_through(events)
	else:
		var new_target := _hold_target()
		if new_target == target:
			return
		target = new_target
		events.append({"type": "hold_changed", "build": build, "target": target})
		if build >= target:
			_win_ball(events)

# ---------- You attacking: their box ----------

func _enter_box(start_quality: int, events: Array) -> void:
	energy = maxi(energy, BOX_ENERGY)   ## never lose energy entering the box; at least BOX_ENERGY
	quality = start_quality
	box_cards_played = 0
	rebound = false
	penalty = false
	events.append({"type": "in_the_box", "quality": quality})

func _play_in_box(card: ActionCard, events: Array) -> void:
	match card.tag:
		"pass", "dribble", "cross":
			var risk := box_risk(card.tag)
			var gain := box_gain(card)    ## worked out before next_bonus is used up
			next_bonus = 0
			box_cards_played += 1
			if randi_range(1, 100) <= risk:
				if randi_range(1, 100) <= BOX_FOUL_SHARE.get(card.tag, 0):
					## Brought down: a penalty, taken with the penalty button (take_penalty).
					penalty = true
					events.append({"type": "box_fouled", "card": card.display_name})
					return
				events.append({"type": "box_lost", "card": card.display_name, "risk": risk})
				_turnover(events)
				return
			quality += gain
			events.append({"type": "quality", "card": card.display_name, "gain": gain, "quality": quality})
		"shot":
			var roll := _shot_roll()          ## the same random strike as the button...
			quality += power_of(card) + roll  ## ...plus the card's power on top
			next_bonus = 0
			events.append({"type": "basic_shot", "roll": roll, "quality": quality})
			_shoot(events)
		_:
			events.append({"type": "wrong_phase", "card": card.display_name})

func _shoot(events: Array) -> void:
	rebound = false
	penalty = false
	if _box_shot_always_scores():
		events.append({"type": "sure_goal"})
		_score_goal(events)
		return
	var save: int = _keeper_save(_draw_from(_keeper_pile, KEEPER_DECK))
	events.append({"type": "shot", "quality": quality, "save": save})
	if quality > save:
		_score_goal(events)
	elif randi_range(1, 100) <= _rebound_chance():
		rebound = true
		quality = REBOUND_QUALITY
		energy = maxi(energy, SHOT_COST)   ## always enough energy for the rebound shot
		events.append({"type": "rebound", "quality": quality})
	else:
		events.append({"type": "saved"})
		_turnover(events)
		
## Everything that happens when you score, in one place.
func _score_goal(events: Array) -> void:
	goals += 1
	events.append({"type": "goal", "goals": goals})
	fire_coaches("on_goal", events)
	zone = 2
	_start_their_possession(events)

# ---------- Them attacking ----------

## Boot it upfield from your own box or half. They end up with the ball, but far from your goal.
func _lump_clear(card: ActionCard, events: Array) -> void:
	if zone > 1:
		events.append({"type": "wrong_phase", "card": card.display_name})
		return
	var we_had_it := has_ball
	zone = min(zone + card.base_value, 4)
	events.append({"type": "lumped", "zone": ZONE_NAMES[zone]})
	if we_had_it:
		_start_their_possession(events)
	else:
		_flip_attack()   ## they keep it, but have to start again from here

func _defend_build_up(card: ActionCard, events: Array) -> void:
	match card.tag:
		"tackle", "track_back":
			var power := power_of(card)
			next_bonus = 0
			build += power
			events.append({"type": "hold", "card": card.display_name, "power": power,
					"build": build, "target": target, "helpers": RunState.squad_helpers(card)})
			if build >= target:
				_win_ball(events)
		_:
			events.append({"type": "wrong_phase", "card": card.display_name})
			
func _they_advance(events: Array) -> void:
	zone -= 1
	events.append({"type": "they_advance", "zone": ZONE_NAMES[zone]})
	if zone == 0:
		_set_their_chance()
		events.append({"type": "they_in_box", "quality": quality})
	else:
		_flip_attack()

func _flip_attack() -> void:
	build = 0
	target = _hold_target()

## The hold you need in the current zone to win the ball, including their attack and abilities.
func _hold_target() -> int:
	return roundi(strength * their_attack * ATTACK_WEIGHT[zone] * _hold_multiplier())
	
func _set_their_chance() -> void:
	quality = _draw_from(_their_chance_pile, THEIR_CHANCE_DECK)
	_plan_attack()

## Their attack in your box: 1-2 moves, then a shot. Nobody back: straight to the shot.
func _plan_attack() -> void:
	their_moves.clear()
	tackles_tried = 0
	if not nobody_back():
		for i in randi_range(THEIR_BUILD_MOVES.x, THEIR_BUILD_MOVES.y):
			var kind: String = THEIR_MOVE_GAINS.keys().pick_random()
			their_moves.append({"kind": kind, "gain": roundi(THEIR_MOVE_GAINS[kind] * their_attack)})
	their_moves.append({"kind": "shot", "gain": 0})

func _defend_in_box(card: ActionCard, events: Array) -> void:
	match card.tag:
		"block", "track_back":
			var power := power_of(card)
			if card.tag == "track_back":
				power = roundi(power * TRACK_BACK_BOX_SCALE)
			next_bonus = 0
			quality = max(MIN_THEIR_CHANCE, quality - power)
			events.append({"type": "blocked", "card": card.display_name, "quality": quality})
		"tackle":
			_box_challenge(card, tackle_chance(card), TACKLE_FOUL_SHARE, false, events)
		_:
			_box_challenge(card, lunge_chance(), LUNGE_FOUL_SHARE, true, events)

## A tackle or a lunge in your box: win the ball, or be beaten (sometimes a foul: penalty).
func _box_challenge(card: ActionCard, chance: int, foul_share: int, lunge: bool, events: Array) -> void:
	next_bonus = 0
	tackles_tried += 1
	events.append({"type": "challenge", "card": card.display_name, "chance": chance, "lunge": lunge})
	if randi_range(1, 100) <= chance:
		events.append({"type": "challenge_won"})
		_win_ball(events)
		return
	if randi_range(1, 100) <= foul_share:
		events.append({"type": "foul"})
		_their_penalty(events)
		return
	quality += BEATEN_BONUS
	events.append({"type": "beaten", "bonus": BEATEN_BONUS})
	_their_move(events)

## They make their next move in your box: a pass / dribble / cross raises the chance, or they shoot.
func _their_move(events: Array) -> void:
	if their_moves.is_empty():
		_plan_attack()   ## safety net: never stuck without a plan
	var move: Dictionary = their_moves.pop_front()
	if move["kind"] == "shot":
		_their_shot(events)
		return
	quality += move["gain"]
	events.append({"type": "their_move", "kind": move["kind"], "gain": move["gain"], "quality": quality})

func _their_shot(events: Array) -> void:
	var save: int = _draw_from(_our_keeper_pile, OUR_KEEPER_DECK)
	events.append({"type": "their_shot", "quality": quality, "save": save})
	if quality > save:
		_concede(events)
	else:
		events.append({"type": "our_save"})
		_win_ball(events)

## They've scored: kick-off to you.
func _concede(events: Array) -> void:
	conceded += 1
	events.append({"type": "conceded", "conceded": conceded})
	zone = 2
	events.append({"type": "kick_off"})
	_start_our_possession(events)

# ---------- Penalties ----------

## Your penalty's odds in %: {"score", "save", "miss"}. Their keeper's rating moves the save %.
func your_penalty_odds() -> Dictionary:
	var steps := roundi((their_keeper - 1.0) / OpponentTeam.RATING_SPREAD)
	return _penalty_odds(PEN_SAVE + steps * PEN_SAVE_PER_STEP)

## Their penalty's odds against your keeper. Abilities can set the save % and/or add to it.
func their_penalty_odds() -> Dictionary:
	return _penalty_odds(_penalty_save_base() + _penalty_save_bonus())

func _penalty_odds(save: int) -> Dictionary:
	save = clampi(save, 0, 100 - PEN_MISS)
	return {"score": 100 - save - PEN_MISS, "save": save, "miss": PEN_MISS}

## One penalty: "goal", "saved", "wide" or "over".
func _roll_penalty(odds: Dictionary) -> String:
	var roll := randi_range(1, 100)
	if roll <= odds["miss"]:
		return "wide" if randf() < 0.5 else "over"
	if roll <= odds["miss"] + odds["save"]:
		return "saved"
	return "goal"

## The penalty button: your penalty in their box. No energy, no cards.
## Scored: kick-off to them. Saved, wide or over: their ball.
func take_penalty() -> Array:
	var events := []
	if match_over or not penalty:
		events.append({"type": "not_now"})
		return events
	penalty = false
	var odds := your_penalty_odds()
	var result := _roll_penalty(odds)
	events.append({"type": "penalty_kick", "ours": true, "result": result, "score": odds["score"]})
	if result == "goal":
		_score_goal(events)
	else:
		_turnover(events)
	_tick_clock(events)
	return events

## Their penalty in your box (after a foul). Scored: kick-off to you. Otherwise: your ball.
func _their_penalty(events: Array) -> void:
	var odds := their_penalty_odds()
	var result := _roll_penalty(odds)
	events.append({"type": "penalty_kick", "ours": false, "result": result, "score": odds["score"]})
	if result == "goal":
		_concede(events)
	else:
		_win_ball(events)

# ---------- Changing possession ----------

## After every action: if you're attacking and can't do anything, you lose the ball.
func _check_out_of_energy(events: Array) -> void:
	if not has_ball:
		return
	if energy == 0:
		_turnover(events)
	elif zone < 4 and not _has_playable_card():
		events.append({"type": "no_options"})
		_turnover(events)

## Is there at least one card in your hand you could actually play right now?
func _has_playable_card() -> bool:
	for card in DeckState.hand:
		if card.energy_cost <= energy and can_play_here(card):
			return true
	return false

## You lose the ball where it is.
func _turnover(events: Array) -> void:
	events.append({"type": "turnover", "zone": ZONE_NAMES[zone]})
	_start_their_possession(events)

## You win the ball back where it is.
func _win_ball(events: Array) -> void:
	events.append({"type": "won_ball", "zone": ZONE_NAMES[zone]})
	_start_our_possession(events)

## Everything that happens when the ball changes hands lives in these two functions.
func _start_our_possession(events: Array) -> void:
	has_ball = true
	energy = START_ENERGY
	next_bonus = 0
	DeckState.draw(POSSESSION_DRAW)
	if zone == 4:
		_enter_box(0, events)   ## won it inside their box: straight into a shooting position
	else:
		_flip_press()
	## Nothing in your hand can be played (after a goal, a save, a lunge...): you lose it
	## straight away, the same rule as the opening kick-off. Without this the game just waits.
	_check_out_of_energy(events)

func _start_their_possession(events: Array = []) -> void:
	has_ball = false
	energy = START_ENERGY
	next_bonus = 0
	DeckState.draw(POSSESSION_DRAW)
	var broke_through := false
	if nobody_back() and zone > 0:
		events.append({"type": "ran_through", "index": zone})
		## Nobody back: they break through zone by zone. Each zone still takes an action's
		## worth of time, and stops if the clock runs out before they get there.
		while zone > 0 and minute + MINUTES_PER_ACTION + _extra_minutes < MATCH_LENGTH:
			zone -= 1
			_extra_minutes += MINUTES_PER_ACTION
			events.append({"type": "they_break", "zone": ZONE_NAMES[zone], "index": zone,
					"minute": min(minute + MINUTES_PER_ACTION + _extra_minutes, MATCH_LENGTH)})
		broke_through = zone == 0
	if zone == 0:
		_set_their_chance()
		if broke_through:
			events.append({"type": "they_in_box", "quality": quality})
	else:
		_flip_attack()

# ---------- Helpers ----------

## Roll a card's chance, with one extra attempt per retrigger. True if any attempt succeeds.
func _roll(card: ActionCard) -> bool:
	var attempts := 1 + RunState.retriggers_for_card(card)
	for i in attempts:
		if randf() < card.chance:
			return true
	return false
	
## Percentage of the cards in a pile that a value beats (uses the full deck if the pile is empty).
func _odds_to_beat(value: int, pile: Array, source: Array) -> int:
	var saves: Array = pile if not pile.is_empty() else source
	var beaten := 0
	for s in saves:
		if value > s:
			beaten += 1
	return roundi(100.0 * beaten / saves.size())

## Takes the top item from a pile, reshuffling from source when it's empty.
func _draw_from(pile: Array, source: Array):
	if pile.is_empty():
		pile.append_array(source)
		pile.shuffle()
	return pile.pop_back()

## Every action uses up time. At full time, the match is over.
func _tick_clock(events: Array) -> void:
	minute += MINUTES_PER_ACTION + _extra_minutes
	_extra_minutes = 0
	_announce_abilities(events)
	if minute >= MATCH_LENGTH:
		minute = MATCH_LENGTH
		match_over = true
		events.append({"type": "full_time"})
		return
	_recheck_press(events)   ## an ability may have just changed the press you're facing

## Where this match's coins come from, one row each (zero amounts left out):
## {"count": "3" or "", "label": "Goals (10 each)", "amount": 30}.
## coins_earned() adds these up, so the rows and the total always match.
func coins_parts() -> Array:
	var parts := []
	if goals > conceded:
		parts.append({"count": "", "label": "Win", "amount": COINS_WIN})
	elif goals == conceded:
		parts.append({"count": "", "label": "Draw", "amount": COINS_DRAW})
	else:
		parts.append({"count": "", "label": "Loss", "amount": COINS_LOSS})
	if goals > 0:
		parts.append({"count": str(goals), "label": "Goals (%d each)" % COINS_PER_GOAL,
				"amount": goals * COINS_PER_GOAL})
	if bonus_coins > 0:
		parts.append({"count": "", "label": "Coach bonus", "amount": bonus_coins})
	return parts

func coins_earned() -> int:
	var total := 0
	for part in coins_parts():
		total += part["amount"]
	return total
	
## Fire every coach whose effect happens at this moment, plus any retriggers of it.
func fire_coaches(when: String, events: Array) -> void:
	for c in RunState.coaches_for(when):
		var times := 1 + RunState.retriggers_for_type(c.category)
		bonus_coins += c.coins * times
		events.append({"type": "coach", "name": c.display_name,
				"coins": c.coins * times, "times": times})

# ---------- Abilities ----------

## The abilities switched on right now. Checked live, so a goal can switch one off mid-action.
func _active_abilities() -> Array:
	var list: Array = []
	for s in RunState.match_squad():
		if s.ability != null and s.ability.is_active(self):
			list.append(s.ability)
	return list

func _box_shot_always_scores() -> bool:
	return _active_abilities().any(func(a): return a.box_shot_always_scores(self))

func nobody_back() -> bool:
	return _active_abilities().any(func(a): return a.no_defence(self))

func _press_multiplier() -> float:
	var total := 1.0
	for a in _active_abilities():
		total *= a.press_multiplier(self)
	return total

func _hold_multiplier() -> float:
	var total := 1.0
	for a in _active_abilities():
		total *= a.hold_multiplier(self)
	return total
	
## Chance (%) of a rebound after a save, including abilities (Rebound King).
func _rebound_chance() -> int:
	var total := REBOUND_CHANCE
	for a in _active_abilities():
		total += a.rebound_bonus(self)
	return clampi(total, 0, 100)

## YOUR keeper's save % on their penalties before bonuses: PEN_SAVE, unless an ability sets
## its own (a penalty-saving keeper). The highest one counts.
func _penalty_save_base() -> int:
	var base := PEN_SAVE
	for a in _active_abilities():
		base = maxi(base, a.penalty_save_percent(self))
	return base

## Your staff whose abilities are helping your keeper with their penalties right now
## (so the screen can make their tiles react to a save).
func penalty_helpers() -> Array:
	var list: Array = []
	for s in RunState.match_squad():
		if s.ability == null or not s.ability.is_active(self):
			continue
		if s.ability.penalty_save_percent(self) > PEN_SAVE or s.ability.penalty_save_bonus(self) > 0:
			list.append(s)
	return list

## Extra % saves for YOUR keeper on their penalties, from abilities, added on top.
func _penalty_save_bonus() -> int:
	var total := 0
	for a in _active_abilities():
		total += a.penalty_save_bonus(self)
	return total

func _abilities_allow(card: ActionCard) -> bool:
	return _active_abilities().all(func(a): return a.allows_card(self, card))

## After every action: commentary for any ability that has just switched on or off.
func _announce_abilities(events: Array) -> void:
	for s in RunState.match_squad():
		if s.ability == null:
			continue
		var on: bool = s.ability.is_active(self)
		var was_on := _was_active.has(s)
		if on and not was_on:
			_was_active.append(s)
			if s.ability.on_text != "":
				events.append({"type": "ability", "text": s.ability.on_text.replace("{name}", s.display_name)})
		elif was_on and not on:
			_was_active.erase(s)
			if s.ability.off_text != "":
				events.append({"type": "ability", "text": s.ability.off_text.replace("{name}", s.display_name)})

# ---------- Debug only ----------

func debug_goal() -> Array:
	var events := []
	goals += 1
	events.append({"type": "goal", "goals": goals})
	zone = 2
	_start_their_possession(events)
	_tick_clock(events)
	fire_coaches("on_goal",events)
	return events

func debug_concede() -> Array:
	var events := []
	conceded += 1
	events.append({"type": "conceded", "conceded": conceded})
	zone = 2
	_start_our_possession(events)
	_tick_clock(events)
	return events

func debug_full_time() -> Array:
	var events := []
	minute = MATCH_LENGTH - MINUTES_PER_ACTION
	_tick_clock(events)
	return events
