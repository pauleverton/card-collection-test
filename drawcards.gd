extends VBoxContainer
@onready var message_label = $MessageLabel
@onready var slots = [
	$Placements/Slot1/Control/Card1,
	$Placements/Slot2/Control/Card2,
	$Placements/Slot3/Control/Card3
]

@onready var remove_buttons = [
	$Placements/Slot1/Control/RemoveButton1,
	$Placements/Slot2/Control/RemoveButton2,
	$Placements/Slot3/Control/RemoveButton3
]

var available_cards = []
var current_slot_ids = ["", "", ""]  # tracks which card id sits in each slot

func _ready() -> void:
	print("script loaded")
	reset_deck()

func reset_deck() -> void:
	# CardDatabase is an autoload singleton, loaded once at game start.
	available_cards = CardDatabase.get_all_ids()
	available_cards.shuffle()

func load_card(card_id: String, slot: TextureRect) -> void:
	var card = CardDatabase.get_card(card_id)
	if card == null:
		push_warning("drawcards: no CardData found for id '%s'" % card_id)
		return
	slot.texture = card.texture
	var slot_index = slots.find(slot)
	if slot_index != -1:
		current_slot_ids[slot_index] = card_id

func _on_generate_team_pressed() -> void:
	var next_slot = get_next_empty_slot()
	if next_slot == -1:
		return
	if available_cards.is_empty():
		return

	var main = get_tree().get_first_node_in_group("main")
	if not main.spin_player(30):
		show_message("Not enough coins")
		return

	var card_id = available_cards.pop_back()
	load_card(card_id, slots[next_slot])

func _on_reset_pressed() -> void:
	for slot in slots:
		slot.texture = null
	for btn in remove_buttons:
		btn.visible = false
		btn.text = "Sell player"
	reset_deck()

func show_remove_button(slot_index: int) -> void:
	if slots[slot_index].texture != null:
		var card_id = current_slot_ids[slot_index]
		var sell_value = CardDatabase.get_sell_value(card_id)
		remove_buttons[slot_index].text = "Sell for %d" % sell_value
		remove_buttons[slot_index].visible = true

func hide_remove_button(slot_index: int) -> void:
	remove_buttons[slot_index].visible = false

func remove_card(slot_index: int) -> void:
	var card_id = current_slot_ids[slot_index]
	var sell_value = CardDatabase.get_sell_value(card_id)

	available_cards.append(card_id)
	available_cards.shuffle()
	slots[slot_index].texture = null
	current_slot_ids[slot_index] = ""
	remove_buttons[slot_index].visible = false
	remove_buttons[slot_index].text = "Sell player"

	get_tree().get_first_node_in_group("main").add_coins(sell_value)

func get_next_empty_slot() -> int:
	for i in range(slots.size()):
		if slots[i].texture == null:
			return i
	return -1  # no empty slots

func _on_slot_1_mouse_entered() -> void:
	show_remove_button(0)
func _on_slot_1_mouse_exited() -> void:
	hide_remove_button(0)
func _on_remove_button_1_pressed() -> void:
	remove_card(0)

func _on_slot_2_mouse_entered() -> void:
	show_remove_button(1)
func _on_slot_2_mouse_exited() -> void:
	hide_remove_button(1)
func _on_remove_button_2_pressed() -> void:
	remove_card(1)

func _on_slot_3_mouse_entered() -> void:
	show_remove_button(2)
func _on_slot_3_mouse_exited() -> void:
	hide_remove_button(2)
func _on_remove_button_3_pressed() -> void:
	remove_card(2)

func _on_remove_button_1_mouse_entered() -> void:
	show_remove_button(0)
func _on_remove_button_1_mouse_exited() -> void:
	hide_remove_button(0)

func _on_remove_button_2_mouse_entered() -> void:
	show_remove_button(1)
func _on_remove_button_2_mouse_exited() -> void:
	hide_remove_button(1)

func _on_remove_button_3_mouse_entered() -> void:
	show_remove_button(2)
func _on_remove_button_3_mouse_exited() -> void:
	hide_remove_button(2)

func get_displayed_cards() -> Array:
	var displayed = []
	for slot in slots:
		if slot.texture != null:
			displayed.append(slot.texture.resource_path)
	return displayed

func _on_draw_button_pressed() -> void:
	var next_slot = get_next_empty_slot()
	if next_slot == -1:
		return
	if available_cards.is_empty():
		reset_deck()
	var card_id = available_cards.pop_back()
	load_card(card_id, slots[next_slot])
	check_squad_complete()

func check_squad_complete() -> void:
	for slot in slots:
		if slot.texture == null:
			return
	get_parent().add_score(50)

func show_message(text: String) -> void:
	message_label.text = text
	message_label.visible = true
	await get_tree().create_timer(1.5).timeout
	message_label.visible = false
