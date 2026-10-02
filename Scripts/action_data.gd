# action_data.gd
class_name ActionData
extends Resource

@export var id: String
@export var display_name: String
@export var energy_cost: int = 1
@export_enum("pass","overlap", "dribble", "long_ball", "cross", "shot", "tackle", "press", "block", "recall") var tag: String = "pass"
@export var base_value: int = 1
@export_multiline var description: String
