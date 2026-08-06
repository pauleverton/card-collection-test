extends Node

@onready var player_slots: Array[HBoxContainer] = [
	$Background/Player1,
	$Background/Player2,
	$Background/Player3,
	$Background/Player4,
	$Background/Player5,
	$Background/Player6,
	$Background/Player7
]

func _ready() -> void:
	refresh_squad_display()

func refresh_squad_display() -> void:
	for i in range(player_slots.size()):
		var slot := player_slots[i]

		for child in slot.get_children():
			child.queue_free()

		if i < SquadState.squad.size():
			var card_id: String = SquadState.squad[i]
			var card: CardData = CardDatabase.get_card(card_id)
			if card != null:
				var texture_rect := TextureRect.new()
				texture_rect.texture = card.texture
				texture_rect.custom_minimum_size = Vector2(100, 140)
				texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
				texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				slot.add_child(texture_rect)
