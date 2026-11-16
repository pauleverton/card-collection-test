extends Node
## Autoload: player settings that last between sessions (game speed for now).
## Saved to user://settings.cfg so the choice is remembered next time the game starts.

## Speed presets, in the order the menu shows them. 1.0 = original pace, 0.0 = no animation.
const SPEEDS := {"Slow": 1.0, "Normal": 0.85, "Fast": 0.5, "Instant": 0.0}
const DEFAULT_SPEED := "Normal"
const SAVE_PATH := "user://settings.cfg"

var speed_name: String = DEFAULT_SPEED
## How long animations take, as a multiplier. Every animation in the match runs through t().
var anim_time: float = SPEEDS[DEFAULT_SPEED]

func _ready() -> void:
	load_settings()

## Scale an animation length by the current speed. Use it everywhere instead of a bare number.
func t(seconds: float) -> float:
	return seconds * anim_time

## Called by the menu: change the speed and remember it.
func set_speed(preset: String) -> void:
	if not SPEEDS.has(preset):
		return
	speed_name = preset
	anim_time = SPEEDS[preset]
	save_settings()

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "speed", speed_name)
	cfg.save(SAVE_PATH)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return                        ## first launch: no file yet, keep the default
	var saved: String = cfg.get_value("game", "speed", DEFAULT_SPEED)
	if SPEEDS.has(saved):
		speed_name = saved
		anim_time = SPEEDS[saved]
