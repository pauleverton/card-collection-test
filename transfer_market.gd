extends Control

@onready var market_list: GridContainer = $MarketList
@onready var squad_list: GridContainer = $SquadList

const MARKET_SIZE := 5
const PRICE_MULTIPLIER := 3

var current_pool: Array[String] = []

func _ready() -> void:
	generate_market()
	refresh_squad_display()

# --- MARKET (buy) ---

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

	var row_nodes := _build_row_nodes(card)

	var price := get_price(card)
	var price_label := Label.new()
	price_label.text = "Price: %d" % price

	var buy_button := Button.new()
	buy_button.text = "Buy"
	buy_button.custom_minimum_size = Vector2(90, 0)
	buy_button.pressed.connect(_on_buy_pressed.bind(card_id, row_nodes))

	market_list.add_child(row_nodes[0])
	market_list.add_child(row_nodes[1])
	market_list.add_child(price_label)
	market_list.add_child(buy_button)

	row_nodes.append(price_label)
	row_nodes.append(buy_button)

func get_price(card: CardData) -> int:
	return card.sell_value * PRICE_MULTIPLIER

func _on_buy_pressed(card_id: String, row_nodes: Array) -> void:
	var card: CardData = CardDatabase.get_card(card_id)
	var price := get_price(card)
	var main_node := get_tree().get_first_node_in_group("main")

	if main_node != null and main_node.coins < price:
		print("Not enough coins to buy ", card.display_name)
		return

	if not SquadState.add_to_squad(card_id):
		print("Squad is full")
		return

	if main_node != null:
		main_node.deduct_coins(price)

	current_pool.erase(card_id)
	for node in row_nodes:
		node.queue_free()
	refresh_squad_display()

# --- SQUAD (sell) ---

func refresh_squad_display() -> void:
	for child in squad_list.get_children():
		child.queue_free()

	for card_id in SquadState.squad:
		_add_squad_row(card_id)

func _add_squad_row(card_id: String) -> void:
	var card: CardData = CardDatabase.get_card(card_id)
	if card == null:
		return

	var row_nodes := _build_row_nodes(card)

	var sell_button := Button.new()
	sell_button.text = "Sell (%d)" % card.sell_value
	sell_button.custom_minimum_size = Vector2(90, 0)
	sell_button.pressed.connect(_on_sell_pressed.bind(card_id))

	squad_list.add_child(row_nodes[0])
	squad_list.add_child(row_nodes[1])
	squad_list.add_child(sell_button)

func _on_sell_pressed(card_id: String) -> void:
	var card: CardData = CardDatabase.get_card(card_id)
	SquadState.remove_from_squad(card_id)
	MatchSquadState.remove(card_id)

	var main_node := get_tree().get_first_node_in_group("main")
	if main_node != null:
		main_node.add_coins(card.sell_value)

	refresh_squad_display()
# --- shared ---

func _build_row_nodes(card: CardData) -> Array:
	var texture_rect := TextureRect.new()
	texture_rect.texture = card.texture
	texture_rect.custom_minimum_size = Vector2(80, 113)
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var name_label := Label.new()
	var name_parts := card.display_name.split(" ", false, 1)
	if name_parts.size() > 1:
		name_label.text = name_parts[0] + "\n" + name_parts[1]
	else:
		name_label.text = card.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	return [texture_rect, name_label]

func _on_go_to_locker_room_button_pressed() -> void:
	get_tree().change_scene_to_file("res://lockerroom.tscn")
	
