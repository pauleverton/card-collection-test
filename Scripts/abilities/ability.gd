class_name Ability
extends Resource
## A special ability a player (or coach) brings to a match.
## The match rules ASK abilities questions at set moments ("does this shot score?",
## "how big is their press?"). Every answer here means "no effect", so each ability
## script only overrides the questions it changes.
##
## New ability: make a script that extends Ability, override one or more questions,
##   then pick it in a player's Ability slot in the Inspector.
## New KIND of question: add a function here with a "no effect" answer,
##   then ask it from match_rules.gd at the right moment.

## When it switches on. 0 = from kick-off.
@export var active_from_minute: int = 0
## Only while you're drawing or losing. Switches off again when you go ahead.
## Only while the score is like this. "any" = whatever the score.
@export_enum("any", "winning", "drawing", "losing", "not_winning", "not_losing") var when_score: String = "any"
## Commentary when it switches on / off. {name} = the player's name. Blank = no line.
@export var on_text: String = ""
@export var off_text: String = ""

## Is it switched on right now?
## Is it switched on right now?
func is_active(m: MatchRules) -> bool:
	if m.minute < active_from_minute:
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

# ---------- Questions the match rules ask (only while the ability is active) ----------

## Does a shot inside their box score without the keeper getting a chance?
func box_shot_always_scores(_m: MatchRules) -> bool:
	return false

## Multiplies their press targets while you attack (0.5 = half as hard to get through).
func press_multiplier(_m: MatchRules) -> float:
	return 1.0

## True = nobody defends: when you lose the ball they go straight to your box,
## and you can't play any card until they've had their shot.
func no_defence(_m: MatchRules) -> bool:
	return false

## Multiplies the hold you need to win the ball back (0.5 = defending is twice as easy).
func hold_multiplier(_m: MatchRules) -> float:
	return 1.0

## Can this card be played at all right now? Lets an ability switch whole groups of cards off.
func allows_card(_m: MatchRules, _card: ActionCard) -> bool:
	return true

## Extra % chance of a rebound after the keeper saves (0 = no effect).
func rebound_bonus(_m: MatchRules) -> int:
	return 0
