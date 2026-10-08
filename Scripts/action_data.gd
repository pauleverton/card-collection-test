# action_data.gd
@tool
class_name ActionData
extends Resource

@export var id: String
@export var display_name: String
@export var energy_cost: int = 1
@export var tag: String = "pass"
@export var card_type: String = "attacking"
@export_enum("common","rare","special") var card_rarity:String="common"
@export var base_value: int = 1
@export var draw_count: int = 0
@export var energy_boost: int = 0
## When this card can be played at all.
@export_enum("any", "attacking", "defending") var usable_when: String = "any"
@export_multiline var description: String
@export var upgrades_to: ActionData
@export var is_upgraded: bool = false

## Turns tag and card_type into dropdowns built from CardTags, so there's only one list.
func _validate_property(property: Dictionary) -> void:
	if property.name == "tag":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(CardTags.TAGS)
	elif property.name == "card_type":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(CardTags.TYPES)
