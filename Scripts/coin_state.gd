extends Node
## Autoload singleton. Register as "CoinState" in Project Settings > Autoload.

signal coins_changed(new_amount: int)

const STARTING_COINS := 1000
var coins: int = STARTING_COINS

func new_run() -> void:
	coins = STARTING_COINS
	coins_changed.emit(coins)
	
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
