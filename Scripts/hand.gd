extends HBoxContainer

signal card_played(card: ActionData)

const CARD_UI = preload("res://Scenes/action_card_ui.tscn")

func refresh() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()	
	for card in DeckState.hand:
		var ui = CARD_UI.instantiate()
		ui.setup(card)
		ui.card_clicked.connect(func(c): card_played.emit(c))
		add_child(ui)
