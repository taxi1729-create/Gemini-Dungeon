extends Node
## Inventory（Autoload）：道具と食材

var items: Array = []
var foods: Dictionary = {"carrot": 0, "onion": 0, "potato": 0, "meat": 0}


func reset() -> void:
	items = ["herb", "fire_potion"]
	for key in foods.keys():
		foods[key] = 0
	foods["meat"] = 2
	foods["potato"] = 1


func add_food(food_id: String, amount: int = 1) -> void:
	foods[food_id] = foods.get(food_id, 0) + amount


func food_total() -> int:
	var total := 0
	for v in foods.values():
		total += v
	return total


func remove_item(item_id: String) -> void:
	items.erase(item_id)


## ランダムな食材を指定数消費する（休憩用）
func consume_random_food(amount: int) -> bool:
	if food_total() < amount:
		return false
	for i in amount:
		var available: Array = []
		for key in foods.keys():
			if foods[key] > 0:
				available.append(key)
		var picked = available[randi() % available.size()]
		foods[picked] -= 1
	return true
