extends Node
## Inventory（Autoload）：道具・食材・ゴールド

var items: Array = []
var foods: Dictionary = {"meat": 0, "veg": 0, "mush": 0}
var gold := 0


func reset() -> void:
	items = ["herb", "fire_potion"]
	foods = {"meat": 1, "veg": 1, "mush": 1}
	gold = 50


func add_food(food_id: String, amount: int = 1) -> void:
	foods[food_id] = int(foods.get(food_id, 0)) + amount


func food_total() -> int:
	var total := 0
	for v in foods.values():
		total += v
	return total


func remove_item(item_id: String) -> void:
	items.erase(item_id)


func can_cook(recipe: Dictionary) -> bool:
	var need := {}
	for f in recipe.use:
		need[f] = int(need.get(f, 0)) + 1
	for f in need:
		if int(foods.get(f, 0)) < need[f]:
			return false
	return true


func consume(recipe: Dictionary) -> void:
	for f in recipe.use:
		foods[f] -= 1


func foods_text() -> String:
	var parts: Array = []
	for k in FoodList.DATA:
		parts.append("%s%d" % [FoodList.DATA[k].name, foods.get(k, 0)])
	return "　".join(parts)
