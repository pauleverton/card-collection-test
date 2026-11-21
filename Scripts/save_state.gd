extends Node
## Autoload singleton. Register as "SaveState" in Project Settings > Autoload, BELOW the other states.
## Three profiles, each in its own folder (user://profile_1, _2, _3):
##   progress.cfg  what the profile has achieved; kept for ever.
##   run.cfg       the run in progress, if any (one at a time). Deleted when the run ends.
## Every state saves and loads itself (save_to / load_from); this file only says where and when.
## Cards and staff are written down as their file paths ("res://Resources/..."), so a saved run
## always uses the card's current numbers.

const PROFILES := 3
## Bump this when the save layout changes so much that older saves can't be read.
const SAVE_VERSION := 1

var profile := 1      ## 1-3: whose season ticket is in use (picked on the profile screen)
## Remembers which profile was used last, so its ticket is ready when the game opens.
const LAST_PROFILE_FILE := "user://profiles.cfg"
## Set when Start new game is pressed with nobody signed up: after signing up, carry on to the team name.
var start_after_sign_up := false

func _ready() -> void:
	profile = _last_profile()
	load_progress()

## Switch to profile p: its progress becomes the game's, and it's remembered for next time.
func use_profile(p: int) -> void:
	profile = p
	load_progress()
	var cfg := ConfigFile.new()
	cfg.set_value("profiles", "last", p)
	cfg.save(LAST_PROFILE_FILE)

func _last_profile() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(LAST_PROFILE_FILE) != OK:
		return 1
	return clampi(cfg.get_value("profiles", "last", 1), 1, PROFILES)

## Has anyone signed up to ticket p? (anything saved counts)
func profile_exists(p: int) -> bool:
	return FileAccess.file_exists(progress_file(p)) or has_run(p)

## Wipe every profile's run and progress, and which profile was used last (your speed setting
## stays). Only the editor-only button on the main menu uses this, for testing.
func delete_everything() -> void:
	for p in range(1, PROFILES + 1):
		for path in [run_file(p), progress_file(p)]:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
	if FileAccess.file_exists(LAST_PROFILE_FILE):
		DirAccess.remove_absolute(LAST_PROFILE_FILE)
	profile = 1
	load_progress()

## Has anyone signed up at all? (No: the game opens on the season tickets.)
func any_profile() -> bool:
	for p in range(1, PROFILES + 1):
		if profile_exists(p):
			return true
	return false

## A new manager signs up to ticket p, with fresh progress.
func create_profile(p: int, manager: String) -> void:
	use_profile(p)
	CareerState.manager_name = manager
	save_progress()

## What ticket p shows, read straight from its files (without switching to it):
## {name, best (league name), runs, run ("" or "Paul's XI\nLeague Two · week 3")}.
func summary(p: int) -> Dictionary:
	var progress := _read(progress_file(p))
	if progress == null:
		progress = ConfigFile.new()
	var leagues: Array = LeagueState.TOURNAMENTS
	var best: int = clampi(progress.get_value("progress", "best_tournament", 0), 0, leagues.size() - 1)
	var manager: String = progress.get_value("progress", "manager", "")
	var info := {
		"name": manager if manager != "" else "Manager %d" % p,
		"best": leagues[best]["name"],
		"runs": progress.get_value("progress", "runs", 0),
		"run": ""}
	var run := _read(run_file(p))
	if run != null:
		var league: int = clampi(run.get_value("league", "tournament", 0), 0, leagues.size() - 1)
		var rounds: int = maxi(run.get_value("league", "fixtures", []).size(), 1)
		var week: int = mini(run.get_value("league", "matches_played", 0) + 1, rounds)
		var team: String = run.get_value("run", "team_name", "")
		var where := "%s · week %d" % [leagues[league]["name"], week]
		info["run"] = where if team == "" else team + "\n" + where     ## two lines: the team, then where they are
	return info

func folder(p: int = profile) -> String:
	return "user://profile_%d" % p

func run_file(p: int = profile) -> String:
	return folder(p) + "/run.cfg"

func progress_file(p: int = profile) -> String:
	return folder(p) + "/progress.cfg"

## Does this profile have a run in progress?
func has_run(p: int = profile) -> bool:
	return FileAccess.file_exists(run_file(p))

## Write the whole run down. `screen` = the scene Continue should open.
func save_run(screen: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("save", "version", SAVE_VERSION)
	cfg.set_value("save", "screen", screen)
	RunState.save_to(cfg)
	LeagueState.save_to(cfg)
	CoinState.save_to(cfg)
	_write(cfg, run_file())

## Read the run back. Returns the scene to open, or "" if there's no run or it can't be read.
func load_run() -> String:
	var cfg := _read(run_file())
	if cfg == null:
		return ""
	RunState.load_from(cfg)
	LeagueState.load_from(cfg)
	CoinState.load_from(cfg)
	return cfg.get_value("save", "screen", "")

func delete_run() -> void:
	if has_run():
		DirAccess.remove_absolute(run_file())

func save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("save", "version", SAVE_VERSION)
	CareerState.save_to(cfg)
	_write(cfg, progress_file())

## A profile with no progress file yet starts from nothing.
func load_progress() -> void:
	var cfg := _read(progress_file())
	if cfg == null:
		cfg = ConfigFile.new()
	CareerState.load_from(cfg)

## Cards / staff → their file paths, for writing down. An empty slot (null, e.g. a player
## already signed from the transfer list) is written as "" so the list keeps its shape.
func paths(items: Array) -> Array:
	return items.map(func(item): return "" if item == null else item.resource_path)

## File paths → cards / staff ("" back to an empty slot). A file that no longer exists is left
## out (with a warning), so renaming or deleting a card can't break a saved run.
func load_paths(list: Array) -> Array:
	var items := []
	for path in list:
		if path == "":
			items.append(null)
		elif ResourceLoader.exists(path):
			items.append(load(path))
		else:
			push_warning("SaveState: %s no longer exists, left out of the saved run" % path)
	return items

func _write(cfg: ConfigFile, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(folder())
	var error := cfg.save(path)
	if error != OK:
		push_error("SaveState: couldn't save %s (error %d)" % [path, error])

## The file, or null if it doesn't exist, can't be read, or comes from a newer version.
func _read(path: String) -> ConfigFile:
	if not FileAccess.file_exists(path):
		return null
	var cfg := ConfigFile.new()
	var error := cfg.load(path)
	if error != OK:
		push_error("SaveState: couldn't read %s (error %d)" % [path, error])
		return null
	if cfg.get_value("save", "version", 0) > SAVE_VERSION:
		push_error("SaveState: %s was saved by a newer version of the game" % path)
		return null
	return cfg
