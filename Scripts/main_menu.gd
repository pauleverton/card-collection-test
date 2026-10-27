extends Node2D

@onready var speed_option: OptionButton = $TextureRect/SpeedOption

func _ready() -> void:
	## Fill the speed list from SettingsState, and select whatever was saved last time.
	var names: Array = SettingsState.SPEEDS.keys()
	for i in names.size():
		speed_option.add_item(names[i])
		if names[i] == SettingsState.speed_name:
			speed_option.select(i)
	speed_option.item_selected.connect(
			func(i): SettingsState.set_speed(speed_option.get_item_text(i)))

func _on_start_game_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/match_screen.tscn")
