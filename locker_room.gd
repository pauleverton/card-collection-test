extends Node

@onready var go_to_match_button: Button = $Gotomatch
@onready var go_to_transfer_button: Button = $Gototransfermarket


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
	if not LeagueState.season_prediction_shown:
		get_tree().change_scene_to_file("res://SeasonPrediction/season_prediction.tscn")
		return

	refresh_squad_display()
	_update_gotomatch_button()
	_update_transfer_button()

func refresh_squad_display() -> void:
	for slot in player_slots:
		for child in slot.get_children():
			child.queue_free()

	var goalkeepers: Array = []
	var others: Array = []

	for card_id in SquadState.squad:
		var card: CardData = CardDatabase.get_card(card_id)
		if card != null and card.position == "GK":
			goalkeepers.append(card_id)
		else:
			others.append(card_id)

	if goalkeepers.size() > 0:
		_place_card(goalkeepers[0], player_slots[0])

	for i in range(others.size()):
		var slot_index := i + 1
		if slot_index < player_slots.size():
			_place_card(others[i], player_slots[slot_index])

func _place_card(card_id: String, slot: HBoxContainer) -> void:
	var card: CardData = CardDatabase.get_card(card_id)
	if card == null:
		return

	var texture_button := TextureButton.new()
	texture_button.texture_normal = card.texture
	# Allow the button to shrink below the raw image resolution
	texture_button.ignore_texture_size = true
	texture_button.custom_minimum_size = Vector2(118, 150)
	texture_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	texture_button.toggle_mode = true
	texture_button.button_pressed = MatchSquadState.is_selected(card_id)
	_update_selection_visual(texture_button, texture_button.button_pressed)
	texture_button.toggled.connect(_on_card_toggled.bind(card_id, texture_button))
	slot.add_child(texture_button)

func _on_card_toggled(_toggled_on: bool, card_id: String, button: TextureButton) -> void:
	var success := MatchSquadState.toggle_selection(card_id)
	if not success:
		button.button_pressed = MatchSquadState.is_selected(card_id)
	_update_selection_visual(button, MatchSquadState.is_selected(card_id))
	_update_gotomatch_button()
	
func _update_selection_visual(button: TextureButton, is_selected: bool) -> void:
	button.modulate = Color(0.6, 1.0, 0.6) if is_selected else Color(1, 1, 1)

func _on_gototransfermarket_pressed() -> void:
	if not LeagueState.is_before_first_match_of_season():
		return  # button should already be disabled — belt and braces
	get_tree().change_scene_to_file("res://TransferMarket.tscn")

func _update_gotomatch_button() -> void:
	go_to_match_button.disabled = MatchSquadState.selected.is_empty()

## Transfer market is only open before the first match of the current
## season — once you've played a match, it locks until the next season
## starts (promotion, or a fresh run after elimination), matching
## LeagueState.is_before_first_match_of_season().
func _update_transfer_button() -> void:
	go_to_transfer_button.disabled = not LeagueState.is_before_first_match_of_season()
	go_to_transfer_button.tooltip_text = "" if LeagueState.is_before_first_match_of_season() else "Transfer market re-opens next season"

func _on_gotomatch_pressed() -> void:
	get_tree().change_scene_to_file("res://Match/matchattempt.tscn")
