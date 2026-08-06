extends Control

@onready var market_list: VBoxContainer = $MarketList
@onready var squad_debug_label: Label = $SquadDebugLabel

const MARKET_SIZE := 5
const PRICE_MULTIPLIER := 3

var current_pool: Array[String] = []

func _ready() -> void:
	generate_market()

func generate_market() -> void:
	for child in market_list.get_children():
		child.queue_free()

	var pool: Array = CardDatabase.get_all_ids()
	pool.shuffle()

	current_pool.clear()
	for id in pool:
		if current_pool.size() >= MARKET_SIZE:
			break
		if not SquadState.has_card(id):
			current_pool.append(id)

	for card_id in current_pool:
		_add_market_row(card_id)

func _add_market_row(card_id: String) -> void:
	var card: CardData = CardDatabase.get_card(card_id)
	if card == null:
		return

	var row := HBoxContainer.new()

	var texture_rect := TextureRect.new()
	texture_rect.texture = card.texture
	texture_rect.custom_minimum_size = Vector2(80, 113)
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(texture_rect)

	var name_label := Label.new()
	name_label.text = card.display_name
	row.add_child(name_label)

	var price := get_price(card)
	var price_label := Label.new()
	price_label.text = "Price: %d" % price
	row.add_child(price_label)

	var buy_button := Button.new()
	buy_button.text = "Buy"
	buy_button.pressed.connect(_on_buy_pressed.bind(card_id, row))
	row.add_child(buy_button)

	market_list.add_child(row)

func get_price(card: CardData) -> int:
	return card.sell_value * PRICE_MULTIPLIER

func _on_buy_pressed(card_id: String, row: HBoxContainer) -> void:
	var card: CardData = CardDatabase.get_card(card_id)
	var price := get_price(card)
	var main_node := get_tree().get_first_node_in_group("main")

	if main_node == null:
		print("No main node found — coin check skipped (testing mode)")
	elif main_node.coins < price:
		print("Not enough coins to buy ", card.display_name)
		return

	if not SquadState.add_to_squad(card_id):
		print("Squad is full")
		return

	if main_node != null:
		main_node.deduct_coins(price)
	current_pool.erase(card_id)
	row.queue_free()
	update_squad_debug_label()

func update_squad_debug_label() -> void:
	var names: Array = []
	for id in SquadState.squad:
		var card: CardData = CardDatabase.get_card(id)
		if card != null:
			names.append(card.display_name)
	squad_debug_label.text = "Squad: " + ", ".join(names)
	


func _on_go_to_locker_room_button_pressed() -> void:
	get_tree().change_scene_to_file("res://lockerroom.tscn")
