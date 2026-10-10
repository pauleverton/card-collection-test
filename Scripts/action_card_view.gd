extends Button

signal card_clicked(card: ActionCard)

var card: ActionCard

func _ready() -> void:
	custom_minimum_size = Vector2(180, 250)
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pressed.connect(func(): card_clicked.emit(card))

func setup(data: ActionCard) -> void:
	card = data
	text = "%s\nCost: %d\n Value: %d\n%s" % [data.display_name, data.energy_cost,data.base_value, data.description]
	
	
