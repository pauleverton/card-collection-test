extends Control

const CARD_UI = preload("res://Scenes/action_card_view.tscn")
const PLAYER_UI= preload("res://Scenes/player_card_view.tscn")
const PRICE := {"common": 50, "uncommon": 80, "rare": 120,"special": 200}
const PLAYER_PRICE := {"common": 150,"uncommon":200,"rare": 300, "special": 500}
const PACK_PRICE := 100
const PACK_SIZE := 3

@onready var coins_label = $VBox/CoinsLabel
@onready var for_sale = $VBox/ForSale
@onready var pack_button = $VBox/PackButton
@onready var pack_reveal = $VBox/PackReveal
@onready var leave_button = $VBox/LeaveButton
const UPGRADE_PRICE := 60
@onready var upgrade_button = $VBox/UpgradeButton
@onready var deck_view = $VBox/ScrollContainer/DeckView
@onready var player_sale = $VBox/PlayerForSale
@onready var squad_view = $VBox/SquadView


func _ready() -> void:
	for card in RunState.reward_options(3):
		var ui = CARD_UI.instantiate()
		ui.setup(card)
		ui.text += "\n\n%d coins" % price_of(card)
		ui.card_clicked.connect(_buy_card.bind(ui))
		for_sale.add_child(ui)
	for player in RunState.staff_for_sale(3):
		var ui = PLAYER_UI.instantiate()
		ui.setup(player)
		ui.text+="\n\n%d coins" % price_of_player(player)
		ui.player_clicked.connect(_buy_player.bind(ui))
		for_sale.add_child(ui)
	pack_button.text = "Open a pack (%d coins)" % PACK_PRICE
	pack_button.pressed.connect(_buy_pack)
	leave_button.pressed.connect(_leave)
	_update_header_label()
	upgrade_button.text = "Upgrade a card (%d coins)" % UPGRADE_PRICE
	upgrade_button.pressed.connect(_show_deck_for_upgrade)
	_show_squad()

func price_of(card: ActionCard) -> int:
	return PRICE.get(card.card_rarity, 50)
	
func price_of_player(card:StaffCard)->int:
	return PLAYER_PRICE.get(card.rarity,150)

func _buy_card(card: ActionCard, ui: Button) -> void:
	var cost := price_of(card)
	if not CoinState.can_afford(cost):
		coins_label.text = "Not enough coins! (%d)" % CoinState.coins
		return
	CoinState.deduct_coins(cost)
	RunState.add_card(card)
	ui.queue_free()          ## sold: remove it from the shelf
	_update_header_label()

func _buy_player(player: StaffCard, ui: Button) -> void:
	var cost := price_of_player(player)
	if RunState.squad_full_for(player):
		coins_label.text = "Squad full: sell a player first"
		return
	if not CoinState.can_afford(cost):
		coins_label.text = "Not enough coins! (%d)" % CoinState.coins
		return
	CoinState.deduct_coins(cost)
	RunState.add_player(player)
	ui.queue_free()
	_update_header_label()
	_show_squad()

func _buy_pack() -> void:
	if not CoinState.can_afford(PACK_PRICE):
		coins_label.text = "Not enough coins! (%d)" % CoinState.coins
		return
	CoinState.deduct_coins(PACK_PRICE)
	pack_button.disabled = true
	var i := 0
	for card in RunState.reward_options(PACK_SIZE):
		RunState.add_card(card)
		var ui = CARD_UI.instantiate()
		ui.setup(card)
		ui.disabled = true
		ui.modulate.a = 0.0                      ## start invisible...
		pack_reveal.add_child(ui)
		create_tween().tween_property(ui, "modulate:a", 1.0, 0.4).set_delay(i * 0.5)
		i += 1                                   ## ...then fade in one at a time
	_update_header_label()

func _update_header_label() -> void:
	coins_label.text = "Coins: %d   |   Deck: %d cards" % [CoinState.coins, RunState.deck.size()]

func _leave() -> void:
	get_tree().change_scene_to_file("res://Scenes/match_screen.tscn")

func _show_deck_for_upgrade() -> void:
	if not CoinState.can_afford(UPGRADE_PRICE):
		coins_label.text = "Not enough coins! (%d)" % CoinState.coins
		return
	_clear_deck_view()
	for i in RunState.deck.size():
		var card: ActionCard = RunState.deck[i]
		if not card.can_upgrade():
			continue                      ## skip cards with no upgrade
		var ui = CARD_UI.instantiate()
		ui.setup(card)
		ui.text += "\n→ %s" % card.upgrades_to.display_name
		ui.card_clicked.connect(func(_c): _upgrade(i))
		deck_view.add_child(ui)
		
func _upgrade(index: int) -> void:
	var before: ActionCard = RunState.deck[index]
	CoinState.deduct_coins(UPGRADE_PRICE)
	RunState.upgrade_card(index)
	var after: ActionCard = RunState.deck[index]
	_clear_deck_view()
	upgrade_button.disabled = true             ## one upgrade per shop visit
	_update_header_label()
	coins_label.text = "Upgraded %s (value %d) → %s (value %d)!   Coins: %d" % [
			before.display_name, before.base_value, after.display_name, after.base_value, CoinState.coins]

func _clear_deck_view() -> void:
	for child in deck_view.get_children():
		child.queue_free()
		
func _show_squad() -> void:
	for child in squad_view.get_children():
		child.queue_free()
	for player in RunState.squad:                  ## 2. one view per player you own
		var ui = PLAYER_UI.instantiate()           ## 3. make a new player tile
		ui.setup(player)                           ## 4. fill in name + description
		ui.text += "\n\nSell for %d" % (price_of_player(player) / 2)
		ui.player_clicked.connect(_sell_player)    ## 5. click = sell
		squad_view.add_child(ui)

func _sell_player(player: StaffCard) -> void:
	CoinState.add_coins(price_of_player(player) / 2)
	RunState.remove_player(player)
	_show_squad()
	_update_header_label()

func _show_deck_for_removal() -> void:
	for child in deck_view.get_children():
		child.queue_free()
	for card in RunState.deck:
		var ui = CARD_UI.instantiate()
		ui.setup(card)
		ui.text += "\n\nRemove"
		ui.card_clicked.connect(_remove_card)
		deck_view.add_child(ui)

func _remove_card(card: ActionCard) -> void:
	RunState.remove_card(card)
	_show_deck_for_removal()      ## rebuild so it disappears
	_update_header_label()               ## deck count changes
