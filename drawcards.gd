extends VBoxContainer

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


const CARDS = [
	"james_garner_bronze",
	"jake_obrien_bronze",
	"iliman_ndiaye_silver",
	"jordan_pickford_gold"
]

func _ready() -> void:
	print("script loaded")
	print(slots)
	print(remove_buttons)
	reset_deck()

func reset_deck() -> void:
	available_cards = CARDS.duplicate()
	available_cards.shuffle()

func load_card(card_name: String, slot: TextureRect) -> void:
	var texture = load("res://Cards/" + card_name + ".png")
	slot.texture = texture

func _on_generate_team_pressed() -> void:
	print("draw pressed")
	var next_slot = get_next_empty_slot()
	if next_slot == -1:
		return
	if available_cards.is_empty():
		return
	var card = available_cards.pop_back()
	load_card(card, slots[next_slot])

func _on_reset_pressed() -> void:
	print("reset pressed")
	for slot in slots:
		slot.texture = null
	for btn in remove_buttons:
		btn.visible = false
	reset_deck()

func show_remove_button(slot_index: int) -> void:
	if slots[slot_index].texture != null:
		remove_buttons[slot_index].visible = true

func hide_remove_button(slot_index: int) -> void:
	remove_buttons[slot_index].visible = false

func remove_card(slot_index: int) -> void:
	print("removing card from slot ", slot_index)
	var removed_card = slots[slot_index].texture.resource_path
	removed_card = removed_card.replace("res://Cards/", "").replace(".png", "")
	available_cards.append(removed_card)
	available_cards.shuffle()
	slots[slot_index].texture = null
	remove_buttons[slot_index].visible = false
	get_tree().get_first_node_in_group("main").add_coins(10)
	
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
	print("next empty slot: ", next_slot)
	print("available cards: ", available_cards)
	if next_slot == -1:
		print("no empty slots")
		return
	if available_cards.is_empty():
		print("reshuffling")
		reset_deck()
	var card = available_cards.pop_back()
	print("drawing: ", card)
	load_card(card, slots[next_slot])
	check_squad_complete()


func check_squad_complete() -> void:
	for slot in slots:
		if slot.texture == null:
			return
	get_parent().add_score(50)
