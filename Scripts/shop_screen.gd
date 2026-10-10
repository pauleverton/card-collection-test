extends Control

const CARD_UI = preload("res://Scenes/action_card_view.tscn")
const PRICE := {"basic": 30, "common": 50, "uncommon": 80, "rare": 120}
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

func _ready() -> void:
	for card in RunState.reward_options(3):
		var ui = CARD_UI.instantiate()
		ui.setup(card)
		ui.text += "\n\n%d coins" % price_of(card)
		ui.card_clicked.connect(_buy_card.bind(ui))
		for_sale.add_child(ui)
	pack_button.text = "Open a pack (%d coins)" % PACK_PRICE
	pack_button.pressed.connect(_buy_pack)
	leave_button.pressed.connect(_leave)
	_update_coins()
	upgrade_button.text = "Upgrade a card (%d coins)" % UPGRADE_PRICE
	upgrade_button.pressed.connect(_show_deck_for_upgrade)

func price_of(card: ActionCard) -> int:
	return PRICE.get(card.card_rarity, 50)

func _buy_card(card: ActionCard, ui: Button) -> void:
	var cost := price_of(card)
	if not CoinState.can_afford(cost):
		coins_label.text = "Not enough coins! (%d)" % CoinState.coins
		return
	CoinState.deduct_coins(cost)
	RunState.add_card(card)
	ui.queue_free()          ## sold: remove it from the shelf
	_update_coins()

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
	_update_coins()

func _update_coins() -> void:
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
		var ui = CARD_UI.instantiate()
		ui.setup(card)
		ui.disabled = card.is_upgraded          ## can't upgrade twice
		ui.card_clicked.connect(func(_c): _upgrade(i))
		deck_view.add_child(ui)

func _upgrade(index: int) -> void:
	CoinState.deduct_coins(UPGRADE_PRICE)
	RunState.upgrade_card(index)
	_clear_deck_view()
	upgrade_button.disabled = true             ## one upgrade per shop visit
	_update_coins()

func _clear_deck_view() -> void:
	for child in deck_view.get_children():
		child.queue_free()
