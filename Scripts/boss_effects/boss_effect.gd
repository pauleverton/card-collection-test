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
