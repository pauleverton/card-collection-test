extends Button

signal player_clicked(player: PlayerCard)

var player: PlayerCard

func _ready() -> void:
	custom_minimum_size = Vector2(150, 90)
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pressed.connect(func(): player_clicked.emit(player))

func setup(data: PlayerCard) -> void:
	player = data
	text = "%s\n%s" % [data.display_name, data.description]
	modulate = Color(1.3, 1.15, 0.8)   # a gold tint, so players never look like action cards
