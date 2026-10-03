extends Button

signal card_clicked(card: ActionData)

var card: ActionData

func _ready() -> void:
	custom_minimum_size = Vector2(120, 170)
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pressed.connect(func(): card_clicked.emit(card))

func setup(data: ActionData) -> void:
	card = data
	text = "%s\nCost: %d\n Value: %d\n%s" % [data.display_name, data.energy_cost,data.base_value, data.description]
	
	
