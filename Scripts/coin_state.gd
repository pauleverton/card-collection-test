extends Node
## Autoload singleton. Register as "CoinState" in Project Settings > Autoload.

signal coins_changed(new_amount: int)

var coins: int = 1000

func can_afford(amount: int) -> bool:
	return coins >= amount

func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)

func deduct_coins(amount: int) -> void:
	if amount > coins:
		push_warning("CoinState: deducting %d but only %d available — clamping to 0" % [amount, coins])
	coins = max(0, coins - amount)
	coins_changed.emit(coins)
