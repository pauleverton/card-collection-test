@tool
class_name CoachCard
extends StaffCard
## Coaches decide how often things happen: effects at moments in the match,
## and retriggers for a whole category (cards AND other coaches' effects).
## Retriggers never retrigger each other: they just add up.

## What kind of effect THIS coach's own effect is (so a retrigger coach can repeat it).
@export var category: String = "attacking"
@export_enum("none", "on_goal") var when: String = "none"
@export var coins: int = 0
## Extra triggers for everything matching boosts_type / boosts_tags.
@export var retriggers: int = 0

func affects(card: ActionCard) -> bool:
	return retriggers > 0 and applies_to(card)

func effect_label() -> String:
	if retriggers == 0:
		return ""
	return "Again!" if retriggers == 1 else "Again ×%d" % retriggers

func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)          ## keep the base dropdowns
	if property.name == "category":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(CardTags.TYPES)
