extends Node

## Autoload singleton. Register as "BossRoster" in Project Settings > Autoload.
##
## Loads res://data/boss_roster.tres ONCE at startup — same pattern as
## CardDatabase. Holds every possible boss team; LeagueState picks one at
## random (get_random_boss()) whenever a new season starts, so replays face
## a different boss for the decider match rather than the same fixed one
## every run.

const ROSTER_PATH := "res://data/boss_roster.tres"

var _bosses: Array[BossTeam] = []


func _ready() -> void:
	_load_roster()


func _load_roster() -> void:
	if not ResourceLoader.exists(ROSTER_PATH):
		push_error("BossRoster: could not find %s" % ROSTER_PATH)
		return

	var roster: BossRosterResource = load(ROSTER_PATH)
	if roster == null:
		push_error("BossRoster: failed to load roster resource")
		return

	_bosses = roster.bosses
	print("BossRoster: loaded %d boss teams" % _bosses.size())


## A random boss team for the upcoming season's decider match. Returns null
## if the roster is empty (shouldn't happen once boss_roster.tres has
## entries in it — add more via the Inspector any time).
func get_random_boss() -> BossTeam:
	if _bosses.is_empty():
		push_warning("BossRoster: no boss teams registered")
		return null
	return _bosses[randi() % _bosses.size()]
