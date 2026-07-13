extends VBoxContainer

@onready var card_texture = $CardBase/TextureRect

func _ready() -> void:
	card_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	card_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

func load_random_card() -> void:
	var ids = CardDatabase.get_all_ids()
	if ids.is_empty():
		push_warning("card_base: no cards found in CardDatabase")
		return
	var random_card = ids[randi() % ids.size()]
	load_card(random_card)

func load_card(card_id: String) -> void:
	var card = CardDatabase.get_card(card_id)
	if card == null:
		push_warning("card_base: no CardData found for id '%s'" % card_id)
		return
	card_texture.texture = card.texture

func _on_button_pressed() -> void:
	load_random_card()
