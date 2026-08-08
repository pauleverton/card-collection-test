extends PanelContainer
class_name ConsumableSlot

## Drag source for a single-use consumable card (e.g. Lucky Boots). Drag it
## onto one of your own player slots (BattleCardSlot with side == "player")
## to apply its effect before dragging that player to attack.
##
## NOTE: the underlying effect (see DiceBoostEffect) currently boosts
## whichever player card attacks NEXT, not specifically the card you
## dropped it on — battle.gd clears the "boosted" highlight from every
## player slot the moment any shot is taken, so the visual always matches
## which card the boost actually applied to.

@onready var name_label: Label = $Margin/VBox/NameLabel
@onready var uses_label: Label = $Margin/VBox/UsesLabel

var consumable: ConsumableCard


func set_consumable(card: ConsumableCard) -> void:
	consumable = card
	refresh()


func refresh() -> void:
	if consumable == null:
		visible = false
		return
	visible = consumable.can_use()
	name_label.text = consumable.display_name
	uses_label.text = "%d/%d" % [consumable.uses_remaining, consumable.max_uses]


func _get_drag_data(_at_position: Vector2) -> Variant:
	if consumable == null or not consumable.can_use():
		return null

	var preview := Label.new()
	preview.text = consumable.display_name
	set_drag_preview(preview)

	return {"type": "consumable", "consumable_id": consumable.id}
