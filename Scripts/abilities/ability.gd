class_name Ability
extends Resource
## An effect on a match: a player's or management's special ability, or a boss team's rule.
## The match rules ASK every active effect questions ("can this card be played?", "how much
## energy?"). Every answer here means "no effect", so each effect only overrides what it changes.
## Answers from several effects combine: multipliers multiply, bonuses add, bans add up.
##
## Simple effects: make an EffectRules (effect_rules.gd) and fill in its settings.
## Odd ones: a script that extends Ability and overrides the questions it needs.
## New KIND of question: add a function here with a "no effect" answer,
##   then ask it from match_rules.gd at the right moment.

const ALL_ZONES := 31

## When it switches on. 0 = from kick-off.
@export var active_from_minute: int = 0
## Only while the score is like this. "any" = whatever the score.
@export_enum("any", "winning", "drawing", "losing", "not_winning", "not_losing") var when_score: String = "any"
## Only while the ball is in these zones. All ticked = everywhere.
@export_flags("Your box", "Your half", "Midfield", "Their half", "Their box") var active_zones: int = ALL_ZONES
## Commentary when it switches on / off. {name} = the player's name. Blank = no line.
@export var on_text: String = ""
@export var off_text: String = ""

## Is it switched on right now?
func is_active(m: MatchRules) -> bool:
	if m.minute < active_from_minute:
		return false
	if active_zones & (1 << m.zone) == 0:
		return false
	return _score_ok(m)

## Does the score match when_score?
func _score_ok(m: MatchRules) -> bool:
	var diff := m.goals - m.conceded
	match when_score:
		"winning":
			return diff > 0
		"drawing":
			return diff == 0
		"losing":
			return diff < 0
		"not_winning":
			return diff <= 0
		"not_losing":
			return diff >= 0
	return true

## "MIDFIELD", "YOUR BOX / YOUR HALF"... for a zone-limited effect ("" = everywhere).
func zones_text() -> String:
	if active_zones == ALL_ZONES:
		return ""
	var names: PackedStringArray = []
	for i in MatchRules.ZONE_NAMES.size():
		if active_zones & (1 << i):
			names.append(MatchRules.ZONE_NAMES[i].to_upper())
	return " / ".join(names)

# ---------- Cards ----------

## Can this card be played at all right now?
func allows_card(_m: MatchRules, _card: ActionCard) -> bool:
	return true

## Multiplies the power of your cards right now (1.0 = normal).
func power_multiplier(_m: MatchRules, _card: ActionCard) -> float:
	return 1.0

# ---------- Energy and the clock ----------

## Extra energy at the start of each possession (0 = none).
func energy_bonus(_m: MatchRules) -> int:
	return 0

## The most energy you can have (0 = no limit).
func max_energy(_m: MatchRules) -> int:
	return 0

## Minutes each action takes (0 = normal).
func minutes_per_action(_m: MatchRules) -> int:
	return 0

## Multiplies the minutes each action takes (2.0 = time flies, 0.5 = time drags).
func minutes_multiplier(_m: MatchRules) -> float:
	return 1.0

# ---------- Attacking and defending ----------

## Multiplies their press targets while you attack (0.5 = half as hard to get through).
func press_multiplier(_m: MatchRules) -> float:
	return 1.0

## Multiplies the hold you need to win the ball back (0.5 = defending is twice as easy).
func hold_multiplier(_m: MatchRules) -> float:
	return 1.0

## True = nobody defends: when you lose the ball they go straight to your box,
## and you can't play any card until they've had their shot.
func no_defence(_m: MatchRules) -> bool:
	return false

## Does a shot inside their box score without the keeper getting a chance?
func box_shot_always_scores(_m: MatchRules) -> bool:
	return false

## Extra % chance of a rebound after the keeper saves (0 = no effect).
func rebound_bonus(_m: MatchRules) -> int:
	return 0

## Their chance is multiplied by this when they shoot (1.0 = normal).
func their_shot_multiplier(_m: MatchRules) -> float:
	return 1.0

# ---------- Penalties ----------

## YOUR keeper saves this % of THEIR penalties instead of the normal 11% (-1 = no effect).
## If several abilities set one, the highest counts.
func penalty_save_percent(_m: MatchRules) -> int:
	return -1

## Extra % chance YOUR keeper saves THEIR penalties, added on top (0 = no effect).
func penalty_save_bonus(_m: MatchRules) -> int:
	return 0

# ---------- Before and after the match (bosses) ----------

## Do they take every kick-off?
func they_kick_off(_m: MatchRules) -> bool:
	return false

## Goals they start the match with.
func their_starting_goals(_m: MatchRules) -> int:
	return 0

## Does this player or coach count in this match? false = switched off.
func staff_counts(_m: MatchRules, _staff: StaffCard) -> bool:
	return true

## How many of your players can play (0 = normal). Extras are dropped at random at kick-off.
func players_allowed(_m: MatchRules) -> int:
	return 0

## How many goals you must win by for it to count as a win (1 = normal). Less = a loss.
func win_margin(_m: MatchRules) -> int:
	return 1
