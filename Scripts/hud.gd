extends PanelContainer

@onready var coins_label = $MarginContainer/VBoxContainer/CoinsLabel
@onready var league_label = $MarginContainer/VBoxContainer/LeagueLabel
@onready var points_label = $MarginContainer/VBoxContainer/PointsLabel

func _ready() -> void:
	CoinState.coins_changed.connect(_on_coins_changed)
	_on_coins_changed(CoinState.coins)
	league_label.text = "Current League: " + LeagueState.current_tournament_name()
	points_label.text = "Points: %d" % LeagueState.season_points

func _on_coins_changed(new_amount: int) -> void:
	coins_label.text = "Coins: %d" % new_amount
