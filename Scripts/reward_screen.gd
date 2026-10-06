extends Control

const CARD_UI = preload("res://Scenes/action_card_ui.tscn")

@onready var title_label = $VBox/TitleLabel
@onready var choices = $VBox/Choices
@onready var skip_button = $VBox/SkipButton

func _ready() -> void:
	title_label.text = "Match %d done. Pick a card for your deck (%d cards)." % [
		RunState.matches_played, RunState.deck.size()]
	for card in RunState.reward_options():
		var ui = CARD_UI.instantiate()
		ui.setup(card)
		ui.card_clicked.connect(_on_card_chosen)
		choices.add_child(ui)
	skip_button.pressed.connect(_next_match)

func _on_card_chosen(card: ActionData) -> void:
	RunState.add_card(card)
	_next_match()

func _next_match() -> void:
	get_tree().change_scene_to_file("res://Scenes/shop.tscn")
