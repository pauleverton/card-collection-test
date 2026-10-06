# action_data.gd
class_name ActionData
extends Resource

@export var id: String
@export var display_name: String
@export var energy_cost: int = 1
@export_enum("pass","overlap", "dribble","lump_clear", "long_ball", "cross", "shot", "tackle", "press", "block","track_back","retain") var tag: String = "pass"
@export_enum("common","rare","special") var card_rarity:String="common"
@export_enum("attacking","defending","move","utility") var card_type:String="attacking"
@export var base_value: int = 1
@export var draw_count: int = 0
@export var energy_boost: int = 0
## When this card can be played at all.
@export_enum("any", "attacking", "defending") var usable_when: String = "any"
@export_multiline var description: String
@export var upgrades_to: ActionData
@export var is_upgraded: bool = false
