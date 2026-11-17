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

var profile := 1      ## 1-3. Picking a profile comes later; until then it's always profile 1.

func _ready() -> void:
	load_progress()

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

## Cards / staff → their file paths, for writing down.
func paths(items: Array) -> Array:
	return items.map(func(item): return item.resource_path)

## File paths → cards / staff. A file that no longer exists is left out (with a warning),
## so renaming or deleting a card can't break a saved run.
func load_paths(list: Array) -> Array:
	var items := []
	for path in list:
		if ResourceLoader.exists(path):
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
