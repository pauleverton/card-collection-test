class_name BossEffect
extends Resource
## A boss team's special rule for the whole match. Works like a player's Ability:
## the match rules ASK it questions, and every answer here means "no effect",
## so each boss effect script only overrides the questions it changes.
##
## New boss effect: make a .tres in Resources/boss_effects/ (using one of these scripts),
## then put its file name (without .tres) in the sheet's "Effect ID" column.

const FOLDER := "res://Resources/boss_effects/"

## Load the effect named in the sheet. "" or a missing file = no effect.
static func from_id(id: String) -> BossEffect:
	if id == "":
		return null
	var path := FOLDER + id + ".tres"
	if not ResourceLoader.exists(path):
		push_warning("BossEffect: no file %s (check the Effect ID column)" % path)
		return null
	return load(path)

# ---------- Questions the match rules ask ----------

## Can this card be played at all?
func allows_card(_m: MatchRules, _card: ActionCard) -> bool:
	return true
	
## The most energy you can have (0 = no limit).
func max_energy(_m: MatchRules) -> int:
	return 0

## Minutes each action takes (0 = normal).
func minutes_per_action(_m: MatchRules) -> int:
	return 0

## Do they take every kick-off?
func they_kick_off(_m: MatchRules) -> bool:
	return false

## Goals they start the match with.
func their_starting_goals(_m: MatchRules) -> int:
	return 0
	
## Their chance is multiplied by this when they shoot (1.0 = normal).
func their_shot_multiplier(_m: MatchRules) -> float:
	return 1.0

## Multiplies the power of your cards right now (1.0 = normal).
func power_multiplier(_m: MatchRules, _card: ActionCard) -> float:
	return 1.0

## Does this player or coach count in this match? false = switched off.
func staff_counts(_m: MatchRules, _staff: StaffCard) -> bool:
	return true
	
## How many of your players can play (0 = normal). Extras are dropped at random at kick-off.
func players_allowed(_m: MatchRules) -> int:
	return 0
