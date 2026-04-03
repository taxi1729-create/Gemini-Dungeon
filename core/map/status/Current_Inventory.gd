# core/map/present/inventory.gd
extends Node

var items: Array = []
var foods: Dictionary = {"carrot": 0, "onion": 0, "potato": 0, "meat": 0}

func reset():
	items.clear()
	for key in foods.keys():
		foods[key] = 0

# ランダムな食材を指定数消費する（休憩用）
func consume_random_food(amount: int) -> bool:
	var total = 0
	for count in foods.values(): total += count
	if total < amount: return false # 足りない
	
	for i in range(amount):
		var available = []
		for key in foods.keys():
			if foods[key] > 0: available.append(key)
		if available.size() > 0:
			var picked = available[randi() % available.size()]
			foods[picked] -= 1
	return true
